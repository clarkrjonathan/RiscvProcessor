"""Open-source synthesis + timing flow (yosys + ghdl-yosys-plugin + ABC).

Replacement for the Altera Quartus flow (build.py + parse_timings.py), which
required a licensed Quartus install and the ISU license server.

WHAT THIS REPORTS
    Quartus gave an absolute FMax (MHz) and setup slack (ns) for a specific
    Cyclone IV E FPGA. There is no open timing model for Altera parts, so that
    exact number cannot be reproduced for free. Instead this flow synthesizes the
    processor to an open **standard-cell library** (Nangate45, 45 nm typical) and
    runs ABC static timing to report a REAL critical-path delay in nanoseconds,
    an implied FMax, and cell area in um^2.

    Scope / honesty:
      * The two 1K x 32 memories are treated as macro boundaries (blackboxed),
        exactly as Quartus maps them to block RAM. The reported path is therefore
        the register-to-register *logic* critical path (control, ALU, shifter,
        byte unit, muxes, register file) -- not the RAM access time.
      * It is an ABC estimate: real cell delays, but no wire RC and no clock-tree
        skew, in a 45 nm process (not Cyclone IV). The number is reproducible and
        ideal for comparing processor variants; it is not a Cyclone-IV sign-off.

    If no standard-cell library is installed, the flow falls back to structural
    proxies (gate count + logic depth) and tells you how to fetch a library.

Usage is driven by synthesis.py when Quartus is not installed.
"""

import os
import re
import glob
import shutil
import subprocess
import datetime


TOP = 'RISCV_Processor'

# Where a bundled standard-cell liberty is looked for (first *.lib wins). Override
# with the STDCELL_LIB environment variable to point at your own library.
STDCELL_DIR = os.path.join(os.path.dirname(__file__), 'stdcells')

# ABC script: structure, map to the liberty, then static-timing report with the
# critical path dumped node-by-node (stime -p).
ABC_SCRIPT = 'strash\ndch\nmap\ntopo\nstime -p\n'

# Clock constraint used to compute slack, matching the course SDC
# (create_clock -period 20.000 => 50 MHz target).
CLK_CONSTRAINT_NS = 20.0


def _ghdl_prefix():
    """Locate the GHDL library prefix (dir containing std/v08).

    The Debian/Ubuntu `yosys-plugin-ghdl` is built expecting the GHDL libraries
    under a prefix that may not match the installed backend (mcode vs gcc), so we
    find the real one and export it via GHDL_PREFIX for yosys.
    """
    for base in ('/usr/lib/ghdl/mcode/vhdl', '/usr/lib/ghdl/llvm/vhdl',
                 '/usr/lib/ghdl/gcc/vhdl', '/usr/lib/ghdl'):
        if os.path.isdir(os.path.join(base, 'std', 'v08')):
            return base
    for root, _dirs, _files in os.walk('/usr/lib/ghdl'):
        if os.path.basename(root) == 'v08' and \
                os.path.basename(os.path.dirname(root)) == 'std':
            return os.path.dirname(os.path.dirname(root))
    return None


def _stdcell_lib():
    """Return a path to a standard-cell liberty file, or None."""
    env = os.environ.get('STDCELL_LIB')
    if env and os.path.isfile(env):
        return os.path.abspath(env)
    if os.path.isdir(STDCELL_DIR):
        libs = sorted(glob.glob(os.path.join(STDCELL_DIR, '*.lib')))
        if libs:
            return os.path.abspath(libs[0])
    return None


def find_vhd_files(src_dir='proj/src'):
    files = [f for f in glob.glob(src_dir + '/**/*.vhd', recursive=True)
             if not f.endswith('tb.vhd')]
    # RISCV_types package must be analyzed first.
    files.sort(key=lambda f: (0 if f.endswith('RISCV_types.vhd') else 1, f))
    return [os.path.abspath(f) for f in files]


def run(env):
    os.makedirs('temp', exist_ok=True)
    workdir = os.path.abspath('temp/ghdl_synth_work')
    shutil.rmtree(workdir, ignore_errors=True)
    os.makedirs(workdir)

    vhd = find_vhd_files()
    if not vhd:
        print('No VHDL files found in proj/src')
        return False

    run_env = dict(env)
    prefix = _ghdl_prefix()
    if prefix and 'GHDL_PREFIX' not in run_env:
        run_env['GHDL_PREFIX'] = prefix

    # mem.vhd pre-loads its RAM from imem.hex/dmem.hex via INIT_FILE. During
    # synthesis the contents are irrelevant, and ghdl --synth mishandles the file
    # read, so we place empty hex files in the working dir -> RAM inits to zero.
    for h in ('imem.hex', 'dmem.hex'):
        open(os.path.join(workdir, h), 'w').close()

    log_path  = os.path.abspath('temp/synth_error.log')
    stat_path = os.path.abspath('temp/synth_stat.txt')
    ltp_path  = os.path.abspath('temp/synth_ltp.txt')
    abc_path  = os.path.abspath('temp/synth_abc.txt')

    lib = _stdcell_lib()
    start = datetime.datetime.now()
    mode = 'standard-cell timing (Nangate45)' if lib else 'structural proxies'
    print(f'\nStarting open-source synthesis [{mode}] at {start}\n')

    # Step 1: analyze all VHDL into the work library (GHDL resolves dep order;
    # RISCV_types is listed first).
    with open(log_path, 'w') as log:
        rc = subprocess.call(
            ['ghdl', '-a', '--std=08', '-fsynopsys', '-frelaxed',
             f'--workdir={workdir}'] + vhd,
            stdout=log, stderr=subprocess.STDOUT, cwd=workdir, env=run_env)
    if rc != 0:
        print('GHDL analysis failed. See temp/synth_error.log')
        return False

    # Step 2: elaborate the pre-analyzed top in yosys and synthesize.
    #   - blackbox the 1K x 32 memories so they are macro boundaries (like block
    #     RAM) instead of being expanded into ~150k gates. This keeps the run
    #     fast and the critical path focused on the processor logic.
    if lib:
        with open(os.path.join(workdir, 'abc.script'), 'w') as f:
            f.write(ABC_SCRIPT)
        yosys_script = (
            f'ghdl --std=08 -fsynopsys -frelaxed --workdir={workdir} {TOP}; '
            f'hierarchy -top {TOP}; '
            f'blackbox mem_*; '
            f'synth -top {TOP} -flatten; '
            f'dfflibmap -liberty {lib}; '
            f'tee -o {abc_path} abc -liberty {lib} -script {workdir}/abc.script; '
            f'tee -o {stat_path} stat -liberty {lib}'
        )
    else:
        yosys_script = (
            f'ghdl --std=08 -fsynopsys -frelaxed --workdir={workdir} {TOP}; '
            f'synth -top {TOP} -flatten; '
            f'tee -o {stat_path} stat; '
            f'tee -o {ltp_path} ltp'
        )

    with open(log_path, 'a') as log:
        rc = subprocess.call(
            ['yosys', '-m', 'ghdl', '-p', yosys_script],
            stdout=log, stderr=subprocess.STDOUT, cwd=workdir, env=run_env)
    if rc != 0:
        print('yosys synthesis failed. See temp/synth_error.log')
        return False

    if lib:
        _write_timing_report(log_path, lib)
    else:
        _write_proxy_report(log_path)
    print(f'\nSynthesis complete in {datetime.datetime.now() - start}')
    print('Report written to temp/timing.txt')
    return True


# A node on the ABC critical path:
#   "ABC: Path  5 --    5872 : 4    1 NAND4_X1  A =  1.33  Df = 701.2 -..."
_PATH_RE = re.compile(
    r'Path\s+\d+\s+--\s+(?P<idx>\d+)\s*:\s+\d+\s+\d+\s+(?P<cell>\S+)\s+'
    r'A\s*=\s*[0-9.]+\s+Df\s*=\s*(?P<df>[0-9.]+)')
_ENDS_RE = re.compile(
    r'Start-point\s*=\s*\S+\s*\((?P<start>.+?)\)\.\s+'
    r'End-point\s*=\s*\S+\s*\((?P<end>.+?)\)\.')


def _clean_name(s):
    return s.replace('\\', '').replace(' ', '').strip()


def _write_timing_report(log_path, lib):
    """Parse the ABC stime -p critical path and emit a Quartus-style report."""
    abc_txt = _read(os.path.abspath('temp/synth_abc.txt')) or _read(log_path)

    # Collect the ordered path nodes (cumulative delay Df in ps, cell type).
    nodes = [(float(m.group('df')), m.group('cell'), m.group('idx'))
             for m in _PATH_RE.finditer(abc_txt)]
    em = _ENDS_RE.search(abc_txt)
    start_name = _clean_name(em.group('start')) if em else '(start)'
    end_name   = _clean_name(em.group('end'))   if em else '(end)'

    area_um2 = None
    for m in re.finditer(r"Chip area for module.*?:\s*([0-9.]+)", _read(log_path)):
        area_um2 = float(m.group(1))
    gates = _grep_last(log_path, 'Number of cells:')

    arrival_ns = nodes[-1][0] / 1000.0 if nodes else None

    with open('temp/timing.txt', 'w') as out:
        out.write('#\n# CprE 3810 toolflow -- open-source timing dump\n#\n')
        out.write(f'# Library: {os.path.basename(lib)} (Nangate45, 45nm typ)   '
                  'Tool: yosys + ghdl + ABC\n')
        out.write('# Scope  : register/RAM-boundary to register/RAM-boundary LOGIC path.\n')
        out.write('#          The 1K x 32 memories are macro boundaries (blackboxed),\n')
        out.write('#          as Quartus maps them to block RAM, so this is shorter\n')
        out.write('#          than the original Quartus path that traversed block RAM.\n')
        out.write('#          ABC estimate: real cell delays, no wire RC / clock skew.\n#\n\n')

        if arrival_ns is not None:
            fmax = 1000.0 / arrival_ns
            slack = CLK_CONSTRAINT_NS - arrival_ns
            out.write(f'FMax: {fmax:.2f}mhz Clk Constraint: {CLK_CONSTRAINT_NS:.2f}ns '
                      f'Slack: {slack:.2f}ns\n\n')
            out.write('The path is given below\n\n')
            out.write(' ' + '=' * 67 + '\n')
            out.write(f' From Node    : {start_name}\n')
            out.write(f' To Node      : {end_name}\n')
            out.write(' Launch Clock : iCLK\n')
            out.write(' Latch Clock  : iCLK\n')
            out.write(' Data Arrival Path:\n')
            out.write(' Total (ns)  Incr (ns)   Type   Element\n')
            out.write(' ==========  =========  =====   ' + '=' * 34 + '\n')
            prev = 0.0
            for i, (df_ps, cell, idx) in enumerate(nodes):
                total = df_ps / 1000.0
                incr = total - prev
                prev = total
                if i == 0:
                    typ, elem = 'pi  ', start_name
                else:
                    typ, elem = 'CELL', f'{cell} (#{idx})'
                    if i == len(nodes) - 1:
                        elem += f'  -> {end_name}'
                out.write(f' {total:10.3f} {incr:10.3f}   {typ}   {elem}\n')
            out.write(' Data Required Path:\n')
            out.write(' Total (ns)  Incr (ns)   Type   Element\n')
            out.write(' ==========  =========  =====   ' + '=' * 34 + '\n')
            out.write(f' {CLK_CONSTRAINT_NS:10.3f} {CLK_CONSTRAINT_NS:10.3f}          '
                      'latch edge (clock constraint)\n')
            out.write(f' Data Arrival Time  : {arrival_ns:10.3f}\n')
            out.write(f' Data Required Time : {CLK_CONSTRAINT_NS:10.3f}\n')
            verdict = 'MET' if slack >= 0 else 'VIOLATED'
            out.write(f' Slack              : {slack:10.3f} ({verdict})\n')
            out.write(' ' + '=' * 67 + '\n\n')
        else:
            out.write('(no path parsed -- see temp/synth_abc.txt)\n\n')

        out.write(f'Standard-cell area      : '
                  f'{area_um2:.1f} um^2\n' if area_um2 else
                  'Standard-cell area      : n/a\n')
        out.write(f'Mapped logic cell count : {gates if gates else "n/a"}\n')
        out.write('Full ABC timing output  : temp/synth_abc.txt\n')

    if arrival_ns is not None:
        print(f'  Logic critical path: {arrival_ns:.3f} ns  '
              f'(FMax ~ {1000.0/arrival_ns:.0f} MHz, slack '
              f'{CLK_CONSTRAINT_NS - arrival_ns:+.2f} ns vs {CLK_CONSTRAINT_NS:.0f} ns)')


def _write_proxy_report(log_path):
    """Fallback report when no standard-cell library is installed."""
    cells = _grep_last(log_path, 'Number of cells:')
    depth = None
    for line in _read(log_path).splitlines():
        if 'Longest topological path' in line and 'length=' in line:
            depth = line.split('length=')[1].split(')')[0].strip()

    with open('temp/timing.txt', 'w') as out:
        out.write('#\n# CprE 3810 toolflow -- open-source synthesis (structural proxies)\n#\n')
        out.write('# No standard-cell library found, so only relative proxies are\n')
        out.write('# available. For REAL nanosecond timing, install a liberty file:\n')
        out.write('#   bash internal/snthpy/fetch_stdcells.sh\n')
        out.write('# then re-run synth.\n#\n\n')
        out.write(f'Total gate/cell count (area proxy): {cells if cells else "n/a"}\n')
        out.write('Longest topological path (logic levels, critical-path proxy): '
                  f'{depth if depth else "n/a"}\n\n')
        out.write('Full area breakdown: temp/synth_stat.txt\n')
        out.write('Full longest-path detail: temp/synth_ltp.txt\n')
    print('  (no standard-cell library found -- reported structural proxies only;')
    print('   run internal/snthpy/fetch_stdcells.sh for real ns timing)')


def _read(path):
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return ''


def _grep_last(path, needle):
    val = None
    for line in _read(path).splitlines():
        if needle in line:
            val = line.split(needle)[1].strip()
    return val
