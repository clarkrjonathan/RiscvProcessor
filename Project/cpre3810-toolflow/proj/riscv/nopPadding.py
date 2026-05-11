import re
import sys
import os

# ----------------------------
# ISA MODEL
# ----------------------------
ALU_OPS = {
    "add","addi","sub",
    "and","andi","or","ori","xor","xori",
    "sll","slli","srl","srli","sra","srai",
    "slt","slti",
    "lui",
    "auipc",
    "li", "lhu", "lb", "lasw"
}

BRANCH_OPS = {"beq","bne","blt","bge","ble", "bltu", "bgeu"}
JUMP_OPS = {"j","jal","jr","jalr"}

REGISTER_PATTERN = re.compile(r"^(x[0-9]+|[atfs][0-9]+|ra|sp|gp|tp|fp)$")


def is_register(t):
    return REGISTER_PATTERN.match(t) is not None


# ----------------------------
# REGISTER EXTRACTION
# ----------------------------
def get_regs(instr):
    instr = instr.split("#")[0]
    parts = re.split(r"[,\s()]+", instr.strip())
    parts = [p for p in parts if p]

    if not parts:
        return None, set()

    op = parts[0]
    regs = [t for t in parts[1:] if is_register(t)]

    dest = None
    srcs = set()

    # ------------------------
    # LOAD / STORE
    # ------------------------
    if op in {"lw", "lb", "lhu"}:
        if len(regs) >= 1:
            dest = regs[0]
        if len(regs) >= 2:
            srcs.add(regs[1])

    elif op == "sw":
        if len(regs) >= 1:
            srcs.add(regs[0])
        if len(regs) >= 2:
            srcs.add(regs[1])

    # ------------------------
    # BRANCH
    # ------------------------
    elif op in BRANCH_OPS:
        srcs.update(regs[:2])

    # ------------------------
    # JUMPS
    # ------------------------
    elif op == "jr":
        if regs:
            srcs.add(regs[0])

    elif op == "jalr":
        if len(regs) >= 2:
            dest = regs[0]
            srcs.add(regs[1])
        elif len(regs) == 1:
            srcs.add(regs[0])

    elif op == "jal":
        dest = "ra"

    # ------------------------
    # LI
    # ------------------------
    elif op == "li":
        if len(regs) >= 1:
            dest = regs[0]

    # ------------------------
    # DEFAULT ALU
    # ------------------------
    else:
        if len(regs) >= 1:
            dest = regs[0]
        if len(regs) >= 2:
            srcs.add(regs[1])
        if len(regs) >= 3:
            srcs.add(regs[2])

    return dest, srcs


# ----------------------------
# PREPROCESSOR (la → lasw)
# ----------------------------
def preprocess(line):
    stripped = line.split("#")[0].strip()
    parts = stripped.split()

    if parts and parts[0] == "la":
        return line.replace("la", "lasw", 1)

    return line


# ----------------------------
# PIPELINE SIMULATOR
# ----------------------------
def process_file(inp, outp):
    pending = []

    def step():
        nonlocal pending
        pending = [(r, c - 1) for (r, c) in pending if c - 1 > 0]

    def stall(srcs):
        s = 0
        for r, c in pending:
            if r in srcs:
                s = max(s, c)
        return s

    with open(inp) as f:
        lines = [preprocess(l) for l in f.readlines()]

    out = []

    for line in lines:
        s = line.strip()

        if (
            not s or
            s.endswith(":") or
            s.startswith(".") or
            s.startswith("#")
        ):
            out.append(line)
            continue

        op = s.split()[0]
        dest, srcs = get_regs(s)

        # ------------------------
        # RAW HAZARD STALL (3 cycles)
        # ------------------------
        for _ in range(stall(srcs)):
            out.append("    nop\n")
            step()

        out.append(line)
        step()

        # track producer
        if dest:
            if op in ALU_OPS or op in {"lw", "lb", "lhu"}:
                pending = [(r, c) for (r, c) in pending if r != dest]
                pending.append((dest, 3))

        # ------------------------
        # CONTROL HAZARD (2 cycles)
        # ------------------------
        if op in BRANCH_OPS or op in JUMP_OPS:
            for _ in range(2):
                out.append("    nop\n")
                step()

    with open(outp, "w") as f:
        f.writelines(out)


# ----------------------------
# DIRECTORY DRIVER
# ----------------------------
if len(sys.argv) != 2:
    print("Usage: python script.py <input_directory>")
    sys.exit(1)

inp_dir = sys.argv[1]

if not os.path.isdir(inp_dir):
    print("Error: input must be a directory")
    sys.exit(1)

out_dir = inp_dir.rstrip("/") + "_nops"
os.makedirs(out_dir, exist_ok=True)

for file in os.listdir(inp_dir):
    if file.endswith(".s"):
        inp = os.path.join(inp_dir, file)
        out = os.path.join(out_dir, file.replace(".s", "_nops.s"))

        process_file(inp, out)
        print(f"Processed {file}")

print("\nDone:", out_dir)
