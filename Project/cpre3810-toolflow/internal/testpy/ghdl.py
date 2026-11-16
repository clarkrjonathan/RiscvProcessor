"""GHDL interface.

Open-source replacement for the ModelSim/Questasim interface (modelsim.py).
GHDL (https://ghdl.github.io) is a free VHDL-2008 simulator. This class mirrors
the public method surface of the Modelsim class so the rest of the test
framework does not need to care which simulator is underneath.

Key differences handled here vs. ModelSim:
  * ModelSim used a `.do` script with `mem load` to deposit imem.hex/dmem.hex
    into the IMem/DMem RAM signals. GHDL has no equivalent command, so memory
    is instead pre-loaded via the INIT_FILE generic on the `mem` entity (see
    proj/src/TopLevel/mem.vhd). The hex files are placed in the simulation
    working directory (cwd) so the RAM reads them at elaboration.
  * ModelSim `vlib`/`vcom`/`vsim` become GHDL `ghdl -i` (import) /
    `ghdl -m` (make, dependency-ordered analysis) / `ghdl -r` (run).

Date:
    2025 - open-source toolflow port
"""

import subprocess
import glob
import os
import pathlib
import re
import shutil
import time
from pathlib import Path

import logging
logger = logging.getLogger(__name__)

# used to see if output may have timed out but outputted correctly (meaning no halt signal)
expected_firstline = re.compile(r'In clock cycle:')

# Common GHDL flags:
#   --std=08     : VHDL-2008 (external names, stop(2), 2-D RAM init, etc.)
#   -fsynopsys   : enables ieee.std_logic_textio (hread/hwrite) used by tb.vhd and mem.vhd
#   -frelaxed    : tolerate minor non-strict constructs
GHDL_FLAGS = ['--std=08', '-fsynopsys', '-frelaxed']

# ModelSim ran `run 10000000` ns (= 10 ms) before quitting. Mirror that cap so a
# non-halting program eventually stops even if the wall-clock timeout is large.
SIM_STOP_TIME = '10ms'


class Ghdl:
    """Implements a class for communicating with GHDL.

    Provides the same interface the framework previously expected from the
    Modelsim class: prepare_lib / compile / sim / is_installed.
    """

    def __init__(self, ghdl_path, env):
        """Inits a new GHDL runner.

        Args:
            ghdl_path : Path to the ghdl binary or its containing bin dir. May be
                        None, in which case `ghdl` is resolved from PATH.
            env       : Environment dict for subprocesses.
        """
        self.env = env
        self.ghdl = self._resolve_ghdl(ghdl_path)
        if self.ghdl is None:
            raise FileNotFoundError('ghdl executable not found')

        # Shared analyzed-library directory (the GHDL "work" library).
        self.workdir = Path('internal/GhdlContainer/work')

        logger.debug(f'New GHDL runner, using {self.ghdl}')

    @staticmethod
    def _resolve_ghdl(ghdl_path):
        """Return an absolute path to the ghdl binary, or None."""
        if ghdl_path:
            p = Path(ghdl_path)
            if p.is_file() and os.access(p, os.X_OK):
                return str(p)
            cand = p / 'ghdl'
            if cand.is_file() and os.access(cand, os.X_OK):
                return str(cand)
        found = shutil.which('ghdl')
        return found

    def prepare_lib(self, dest):
        '''Create a fresh analyzed-library directory.'''
        try:
            shutil.rmtree(dest)
        except FileNotFoundError:
            pass
        except Exception:
            logger.warning(f'Directory {dest} could not be cleared')
            return False
        os.makedirs(dest, exist_ok=True)
        return True

    def compile(self, dest, compile_log):
        '''Analyze (import + make) all source files into the work library.

        Mirrors Modelsim.compile: gathers RISCV_types.vhd, tb.vhd and every
        proj/src/**/*.vhd, then builds the `tb` top in dependency order.

        Args:
            dest        : destination work-library directory
            compile_log : path to write analysis output to

        Returns:
            True on success, else False.
        '''
        self.workdir = Path(dest)
        self.prepare_lib(dest)

        to_compile = []

        if pathlib.Path('proj/src/RISCV_types.vhd').is_file():
            logger.info('Found RISCV_types file')
            to_compile.append('proj/src/RISCV_types.vhd')

        to_compile.append('internal/testpy/tb.vhd')

        for f in glob.iglob('proj/src/**/*.vhd', recursive=True):
            if f.endswith('RISCV_types.vhd'):
                continue  # already added first
            logger.info(f'Found {f}')
            to_compile.append(f)

        # Use absolute paths so the library stays valid regardless of the cwd we
        # later run each simulation from.
        abs_files = [str(Path(f).resolve()) for f in to_compile]

        try:
            with open(compile_log, 'w') as log:
                # Import: register the source files with the library.
                rc = subprocess.call(
                    [self.ghdl, '-i', *GHDL_FLAGS, f'--workdir={dest}'] + abs_files,
                    stdout=log, stderr=subprocess.STDOUT, timeout=120, env=self.env)
                if rc != 0:
                    return False
                # Make: analyze (and, for compiled backends, elaborate) the tb
                # top entity in correct dependency order.
                rc = subprocess.call(
                    [self.ghdl, '-m', *GHDL_FLAGS, f'--workdir={dest}', 'tb'],
                    stdout=log, stderr=subprocess.STDOUT, timeout=300, env=self.env)
        except subprocess.TimeoutExpired:
            return False

        return rc == 0

    def sim(self, directory, modelsim_trace, vsim_log, timeout=30):
        '''Run the `tb` simulation in `directory`.

        imem.hex/dmem.hex must already be present in `directory`; mem.vhd loads
        them via its INIT_FILE generic (relative to cwd). The trace is written by
        tb.vhd's textio process to `modelsim_trace`.

        Returns None on success, otherwise a message string (matching the old
        Modelsim.sim contract).
        '''
        ret = None
        directory = Path(directory)

        run_cmd = [
            'timeout', str(timeout),
            self.ghdl, '-r', *GHDL_FLAGS, f'--workdir={self.workdir.resolve()}',
            'tb',
            f'-gOUTPUT_TRACE={modelsim_trace}',
            f'--stop-time={SIM_STOP_TIME}',
            '--ieee-asserts=disable',
        ]

        with open(directory / vsim_log, 'w') as sim_log:
            try:
                exit_code = subprocess.call(
                    run_cmd,
                    stdout=sim_log, stderr=sim_log,
                    cwd=directory,
                    timeout=timeout + 5,
                    env=self.env)
            except subprocess.TimeoutExpired:
                exit_code = 124

        trace = directory / modelsim_trace
        trace.touch()

        if exit_code == 124:
            if self.timeout_is_nohalt(trace):
                ret = ('** Warning: Simulation timed out, but produced some valid output, '
                       'most likely the halt signal is incorrect or the application contains '
                       'an infinite loop **')
            else:
                ret = ('Simulation timed out (if you think this was a mistake you can increase '
                       'the time to more than 30 seconds explicitly via --sim-timeout)\n')
        elif exit_code != 0:
            # GHDL returns non-zero if an assertion failure stops the run. If the
            # program nonetheless produced a complete trace (halt reached) treat
            # it as success; otherwise report.
            if not self.timeout_is_nohalt(trace):
                ret = f'could not simulate successfully, got exit code {exit_code}'

        return ret

    def timeout_is_nohalt(self, trace):
        '''True if the trace starts with the expected header (valid output even
        though the process did not exit cleanly).'''
        trace = Path(trace)
        if not trace.is_file():
            return False
        with open(trace, 'r') as f:
            firstline = f.readline()
        return expected_firstline.match(firstline)

    def busy_move(self, src, dest, timeout=5, missingok=False):
        '''Retry shutil.move until the resource is released (kept for interface
        parity with the old Modelsim class).'''
        s = time.time()
        while True:
            try:
                shutil.move(src, dest)
                return
            except FileNotFoundError as e:
                if not missingok:
                    raise e
            except PermissionError as e:
                if time.time() - s > timeout:
                    raise e

    @staticmethod
    def is_installed(config, env):
        '''True if a usable ghdl binary exists (config path or PATH).'''
        ghdl_path = getattr(config, 'modelsim', None)  # reuse the config slot
        return Ghdl._resolve_ghdl(ghdl_path) is not None
