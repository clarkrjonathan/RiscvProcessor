"""Open-source synthesis flow (yosys + ghdl-yosys-plugin).

Replacement for the Altera Quartus flow (build.py + parse_timings.py), which
required a licensed Quartus install and the ISU license server.

IMPORTANT / HONEST CAVEAT:
    Quartus produced an *absolute* timing number (FMax in MHz, setup slack in ns)
    for a specific Cyclone IV E FPGA (EP4CE115F29C7). There is no open-source
    timing model for Altera parts, so that exact MHz number cannot be reproduced
    with free tooling.

    Instead, this flow uses yosys to synthesize the design to a generic gate
    netlist and reports:
        * total cell/gate count   -> a proxy for area
        * longest topological path (logic levels) -> a proxy for critical path
    These are *relative* metrics: excellent for comparing two versions of your
    processor (e.g. before/after a change, or to spot a combinational path a
    vulnerability depends on), but they are not Cyclone-IV nanoseconds.

Usage is driven by synthesis.py when Quartus is not installed.
"""

import os
import glob
import shutil
import subprocess
import datetime


TOP = 'RISCV_Processor'


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
    # Fallback: search
    for root, dirs, _ in os.walk('/usr/lib/ghdl'):
        if os.path.basename(root) == 'v08' and os.path.basename(os.path.dirname(root)) == 'std':
            return os.path.dirname(os.path.dirname(root))
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
    # synthesis the contents are irrelevant (area/timing are identical), and
    # ghdl --synth mishandles the file read, so we place empty hex files in the
    # elaboration working directory -> the RAM simply initialises to zero.
    for h in ('imem.hex', 'dmem.hex'):
        open(os.path.join(workdir, h), 'w').close()

    files_arg = ' '.join(f'"{f}"' for f in vhd)
    log_path = os.path.abspath('temp/synth_error.log')
    stat_path = os.path.abspath('temp/synth_stat.txt')
    ltp_path = os.path.abspath('temp/synth_ltp.txt')

    start = datetime.datetime.now()
    print(f'\nStarting open-source synthesis (yosys + ghdl) at {start}\n')

    # Step 1: analyze all VHDL into the work library (dependency order handled
    # by GHDL; RISCV_types is listed first).
    with open(log_path, 'w') as log:
        rc = subprocess.call(
            ['ghdl', '-a', '--std=08', '-fsynopsys', '-frelaxed',
             f'--workdir={workdir}'] + vhd,
            stdout=log, stderr=subprocess.STDOUT, cwd=workdir, env=run_env)
    if rc != 0:
        print('GHDL analysis failed. See temp/synth_error.log')
        return False

    # Step 2: elaborate the pre-analyzed top in yosys (top as a positional arg,
    # no files, no -e), then synthesize and report. Run from workdir so the
    # empty hex files are found.
    # synth -flatten so stat/ltp describe the whole processor as one module.
    # Note: the two 1K x 32 memories are synthesized as generic logic here, so
    # both proxies are inflated by the RAM decode (Quartus maps these to block
    # RAM instead). The numbers are still useful for comparing processor
    # variants, but are not directly comparable to a Quartus area/Fmax report.
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

    _write_report(log_path)
    print(f'\nSynthesis complete in {datetime.datetime.now() - start}')
    print('Report written to temp/timing.txt')
    return True


def _write_report(log_path):
    """Extract cell count and logic depth from yosys output into temp/timing.txt."""
    cells = _grep_last(log_path, 'Number of cells:')
    # ltp prints: "Longest topological path in ... (length=N):"
    depth = None
    try:
        with open(log_path) as f:
            for line in f:
                if 'Longest topological path' in line and 'length=' in line:
                    depth = line.split('length=')[1].split(')')[0].strip()
    except FileNotFoundError:
        pass

    with open('temp/timing.txt', 'w') as out:
        out.write('#\n# CprE 3810 toolflow -- open-source synthesis report\n#\n')
        out.write('# Tool: yosys + ghdl-yosys-plugin (no Quartus / no license)\n')
        out.write('# NOTE: these are relative proxies, not Cyclone-IV timing.\n#\n\n')
        out.write(f'Total gate/cell count (area proxy): {cells if cells else "n/a"}\n')
        out.write(f'Longest topological path (logic levels, critical-path proxy): '
                  f'{depth if depth else "n/a"}\n\n')
        out.write('Full area breakdown: temp/synth_stat.txt\n')
        out.write('Full longest-path detail: temp/synth_ltp.txt\n')


def _grep_last(path, needle):
    val = None
    try:
        with open(path) as f:
            for line in f:
                if needle in line:
                    val = line.split(needle)[1].strip()
    except FileNotFoundError:
        pass
    return val
