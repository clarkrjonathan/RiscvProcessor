import re
import sys
import os

# ----------------------------
# Config
# ----------------------------
ALU_OPS = {
    "add","addi","sub",
    "and","andi","or","ori","xor","xori",
    "sll","slli","srl","srli","sra","srai",
    "slt","slti",
    "lui"
}

BRANCH_OPS = {"beq","bne","blt","bge","ble"}
JUMP_OPS = {"j","jal","jr"}

REGISTER_PATTERN = re.compile(r"^(x[0-9]+|[atfs][0-9]+|ra|sp|gp|tp|fp)$")

# ----------------------------
# Helpers
# ----------------------------
def is_register(token):
    return REGISTER_PATTERN.match(token) is not None

def is_alu(op):
    return op in ALU_OPS

def is_branch(op):
    return op in BRANCH_OPS

def is_jump(op):
    return op in JUMP_OPS

def get_regs(instr):
    instr = instr.split("#")[0]
    parts = re.split(r"[,\s()]+", instr.strip())
    parts = [p for p in parts if p]

    if not parts:
        return None, set()

    op = parts[0]
    tokens = parts[1:]

    regs = [t for t in tokens if is_register(t)]

    dest = None
    srcs = set()

    if op == "lw":
        if len(regs) >= 1:
            dest = regs[0]
        if len(regs) >= 2:
            srcs.add(regs[1])

    elif op == "sw":
        if len(regs) >= 1:
            srcs.add(regs[0])
        if len(regs) >= 2:
            srcs.add(regs[1])

    elif op in BRANCH_OPS:
        srcs.update(regs[:2])

    elif op in JUMP_OPS:
        if op == "jr" and regs:
            srcs.add(regs[0])
        elif op == "jal":
            dest = "ra"

    else:
        if len(regs) >= 1:
            dest = regs[0]
        if len(regs) >= 2:
            srcs.add(regs[1])
        if len(regs) >= 3:
            srcs.add(regs[2])

    return dest, srcs


# ----------------------------
# Core processing function
# ----------------------------
def process_file(input_path, output_path):
    pending = []

    def step_pipeline():
        nonlocal pending
        new_pending = []
        for reg, cycles in pending:
            if cycles - 1 > 0:
                new_pending.append((reg, cycles - 1))
        pending = new_pending

    def get_stall_cycles(srcs):
        stall = 0
        for reg, cycles in pending:
            if reg in srcs:
                stall = max(stall, cycles)
        return stall

    with open(input_path, "r") as f:
        lines = f.readlines()

    output = []

    for line in lines:
        stripped = line.strip()

        if (
            stripped == "" or
            stripped.endswith(":") or
            stripped.startswith(".") or
            stripped.startswith("#")
        ):
            output.append(line)
            continue

        parts = stripped.split()
        op = parts[0]

        dest, srcs = get_regs(stripped)

        # DATA HAZARD
        stall_cycles = get_stall_cycles(srcs)
        for _ in range(stall_cycles):
            output.append("    nop\n")
            step_pipeline()

        # EMIT INSTRUCTION
        output.append(line)
        step_pipeline()

        # TRACK WRITES
        if dest:
            if is_alu(op) or op == "lw":
                pending = [(r, c) for (r, c) in pending if r != dest]
                pending.append((dest, 4))

        # CONTROL HAZARD
        if is_branch(op) or is_jump(op):
            for _ in range(2):
                output.append("    nop\n")
                step_pipeline()

    with open(output_path, "w") as f:
        f.writelines(output)


# ----------------------------
# Main
# ----------------------------
if len(sys.argv) != 2:
    print("Usage: python script.py <input_directory>")
    sys.exit(1)

input_dir = sys.argv[1]

if not os.path.isdir(input_dir):
    print("Error: input must be a directory")
    sys.exit(1)

output_dir = input_dir.rstrip("/") + "_nops"

os.makedirs(output_dir, exist_ok=True)

for filename in os.listdir(input_dir):
    if filename.endswith(".s"):
        input_path = os.path.join(input_dir, filename)

        base, ext = os.path.splitext(filename)
        output_filename = base + "_nops.s"
        output_path = os.path.join(output_dir, output_filename)

        process_file(input_path, output_path)
        print(f"Processed: {filename} -> {output_filename}")

print(f"\nAll files written to: {output_dir}")