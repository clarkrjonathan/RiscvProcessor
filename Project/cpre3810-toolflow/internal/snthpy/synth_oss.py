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

# ABC script: structure, map to the liberty, then static-timing report.
ABC_SCRIPT = 'strash\ndch\nmap\ntopo\nstime\n'


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


def _write_timing_report(log_path, lib):
    """Parse ABC stime + stat and write temp/timing.txt with real ns timing."""
    text = _read(log_path)

    # ABC stime line: "... Area = 7550.41 (...)  Delay = 2973.97 ps (...)"
    delay_ps = None
    for m in re.finditer(r'Delay\s*=\s*([0-9.]+)\s*ps', text):
        delay_ps = float(m.group(1))          # take the last (final mapped) value
    area_um2 = None
    for m in re.finditer(r"Chip area for module.*?:\s*([0-9.]+)", text):
        area_um2 = float(m.group(1))
    gates = _grep_last(log_path, 'Number of cells:')

    with open('temp/timing.txt', 'w') as out:
        out.write('#\n# CprE 3810 toolflow -- open-source synthesis + timing\n#\n')
        out.write(f'# Library : {os.path.basename(lib)} (Nangate45, 45nm typical)\n')
        out.write('# Tool    : yosys + ghdl-yosys-plugin + ABC static timing\n')
        out.write('# Scope   : register-to-register LOGIC critical path.\n')
        out.write('#           1K x 32 memories are treated as macro boundaries\n')
        out.write('#           (blackboxed), as Quartus maps them to block RAM.\n')
        out.write('#           ABC estimate: real cell delays, no wire RC / clock\n')
        out.write('#           skew, 45nm process -- not a Cyclone-IV sign-off.\n#\n\n')
        if delay_ps:
            fmax_mhz = 1.0e6 / delay_ps       # 1/(delay_ps*1e-12) in MHz
            out.write(f'Logic critical-path delay : {delay_ps/1000.0:.3f} ns  '
                      f'({delay_ps:.1f} ps)\n')
            out.write(f'Implied FMax              : {fmax_mhz:.1f} MHz\n')
        else:
            out.write('Logic critical-path delay : n/a (see temp/synth_abc.txt)\n')
        out.write(f'Standard-cell area        : '
                  f'{area_um2:.1f} um^2\n' if area_um2 else
                  'Standard-cell area        : n/a\n')
        out.write(f'Mapped logic cell count   : {gates if gates else "n/a"}\n\n')
        out.write('Full ABC timing output : temp/synth_abc.txt\n')
        out.write('Full area breakdown    : temp/synth_stat.txt\n')

    if delay_ps:
        fmax_mhz = 1.0e6 / delay_ps
        print(f'  Logic critical path: {delay_ps/1000.0:.3f} ns  (FMax ~ {fmax_mhz:.0f} MHz)')


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
