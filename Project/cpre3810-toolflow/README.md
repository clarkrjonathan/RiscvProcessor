# CprE 3810 Toolflow — Local (Open-Source) Setup

This is the CprE 3810 RISC-V processor toolflow, running entirely on open-source
tools so it works on any Linux machine **without the school's license server**.

| Stage | Original (licensed) | Now (open source) |
|-------|---------------------|-------------------|
| Assemble + reference sim | RARS (bundled `.jar`) | RARS — unchanged |
| HDL simulation | ModelSim / Questa | **GHDL** |
| Synthesis + timing | Quartus Prime | **yosys + ghdl-yosys-plugin** |
| License server | FlexLM / SALT | none needed |

Everything you did before works the same way — the commands below are unchanged
from the original toolflow.

---

## 1. One-time setup

Install the three tools (needs `sudo`, run it in a normal terminal):

```bash
sudo apt-get install -y ghdl yosys yosys-plugin-ghdl
```

RARS needs a Java runtime (`java -version`); any JRE 11+ is fine.

That's it — no license file, no `LM_LICENSE_FILE`, no VPN.

---

## 2. Running the test suite

From the `cpre3810-toolflow/` directory:

```bash
./3810_tf.sh test proj/riscv/TestSuite/add_tonybas_0.s      # one program
./3810_tf.sh test proj/riscv/TestSuite/*.s                   # a whole folder
./3810_tf.sh test -j 8 proj/riscv/TestSuite/*.s proj/riscv/TestSuite/*.asm   # full suite, 8 parallel jobs
```

Each program is assembled and run on RARS (the golden reference) and on your
VHDL processor under GHDL; the two traces are compared. A passing program shows
`pass` in all three columns.

Useful flags (same as before):

| Flag | Meaning |
|------|---------|
| `-j N` | run N programs in parallel (`-j 0` = one per CPU) |
| `-s` | summary table only |
| `--nocompile` | skip recompiling the VHDL (faster when only the ASM changed) |
| `--sim-timeout N` | seconds before a hung simulation is killed (default 30) |
| `-h` | full help |

Results land in `output/<program>/`:
- `ms.trace` — your processor's trace (from GHDL)
- `rars.trace` — the expected trace (from RARS)
- `compare.txt` — the diff / verdict

> Note: if your shell can't find `python3` the script already falls back to
> `/bin/python3`. If you ever need a specific interpreter:
> `PYTHON=/usr/bin/python3 ./3810_tf.sh test ...`

## 3. Other commands (unchanged)

```bash
./3810_tf.sh new          # scaffold a fresh proj/ from the boilerplate
./3810_tf.sh synth        # synthesize + report structural metrics (see below)
./3810_tf.sh submit       # package a Canvas submission (proj1)
./3810_tf.sh submit hw    # / submit sw  -> proj2 variants
```

## 4. A note on `synth`

`synth` runs license-free via yosys + GHDL and writes `temp/timing.txt`. Because
there is **no open timing model for the Altera Cyclone IV** part, it reports
*structural proxies* — total gate/cell count (area) and longest topological path
(logic depth) — **not** a real FMax in MHz. These are good for comparing two
versions of your processor, but are not the Quartus number. The original Quartus
timing report is preserved for reference in `temp/timing.txt` in git history.

## 5. What changed under the hood (for reference)

All edits are tagged `[TOOLFLOW/GHDL]` in the source:
- `internal/testpy/ghdl.py` — GHDL driver (replaces `modelsim.py`).
- `internal/snthpy/synth_oss.py` — yosys synthesis (replaces the Quartus flow).
- `proj/src/TopLevel/mem.vhd` + `RISCV_Processor.vhd` — RAMs gained an `INIT_FILE`
  generic that loads `imem.hex`/`dmem.hex` at elaboration (the equivalent of
  ModelSim's `mem load`; your processor logic is otherwise untouched).
- `internal/testpy/tb.vhd` — two GHDL-compatibility tweaks to the provided
  testbench (literal external-name widths; `wait on CLK` instead of a sensitized
  process). Behavior is identical.

Your processor's datapath and control logic were **not** modified.
