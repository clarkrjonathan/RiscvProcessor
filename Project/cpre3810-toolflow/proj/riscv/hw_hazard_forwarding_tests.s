# =============================================================================
# hw_hazard_forwarding_tests.s
# Hardware pipeline data hazard and forwarding test suite.
# Each section is a self-contained test.
# Expected register values are annotated.
# All tests run sequentially; a wrong result leaves a non-zero value in x31.
# =============================================================================

.text
.globl main
main:

j start

FAIL:
    addi  x31, x31, 0x100       # x31 != 0 indicates failure; offset helps identify which
    wfi

# =============================================================================
# TEST 1: EX Forward -- RS1
# Instruction in ID/EX writes RD; the very next instruction reads that RD as RS1.
# No stall needed: hazard unit forwards EX ALUOut directly.
# add x1, x0, x0 loads x1=0 as baseline, then addi x1,x0,42 writes x1,
# then add x2,x1,x0 reads x1 immediately -- should get 42 not 0.
# =============================================================================
start:
    addi  x1,  x0, 42           # x1  = 42   (in EX next cycle)
    add   x2,  x1, x0           # x2  = 42   (forward from EX ALUOut)
    addi  x31, x0, 42
    bne   x2,  x31, FAIL        # FAIL if x2 != 42

# =============================================================================
# TEST 2: EX Forward -- RS2
# =============================================================================
    addi  x1,  x0, 55           # x1  = 55
    add   x3,  x0, x1           # x3  = 55   (forward x1 from EX into RS2)
    addi  x31, x0, 55
    bne   x3,  x31, FAIL

# =============================================================================
# TEST 3: EX Forward -- both RS1 and RS2 from same source
# =============================================================================
    addi  x1,  x0, 10           # x1  = 10
    add   x4,  x1, x1           # x4  = 20   (x1 forwarded into both RS1 and RS2)
    addi  x31, x0, 20
    bne   x4,  x31, FAIL

# =============================================================================
# TEST 4: EX/MEM Forward -- RS1 (one instruction gap)
# =============================================================================
    addi  x1,  x0, 7            # x1  = 7   (will be in EX/MEM two cycles later)
    addi  x5,  x0, 0            # filler (x1 now in EX/MEM)
    add   x6,  x1, x0           # x6  = 7   (forward from EX/MEM ALUOut)
    addi  x31, x0, 7
    bne   x6,  x31, FAIL

# =============================================================================
# TEST 5: EX/MEM Forward -- RS2
# =============================================================================
    addi  x1,  x0, 13           # x1  = 13
    addi  x7,  x0, 0            # filler
    add   x8,  x0, x1           # x8  = 13  (forward x1 from EX/MEM into RS2)
    addi  x31, x0, 13
    bne   x8,  x31, FAIL

# =============================================================================
# TEST 6: Load-use stall (1 cycle stall + MEM forward)
# lw writes RD; next instruction RAW on that RD -- must stall 1 cycle then
# forward ByteOut.
# =============================================================================
    lui   x20, 0x10010          # x20 = data segment base
    addi  x1,  x0,  99
    sw    x1,  0(x20)           # mem[base] = 99
    lw    x9,  0(x20)           # x9  = 99  (load)
    add   x10, x9,  x0          # x10 = 99  (RAW on x9: stall + forward ByteOut)
    addi  x31, x0,  99
    bne   x10, x31, FAIL

# =============================================================================
# TEST 7: Load-use stall -- RS2
# =============================================================================
    addi  x1,  x0,  77
    sw    x1,  4(x20)
    lw    x11, 4(x20)           # x11 = 77
    add   x12, x0,  x11         # x12 = 77  (stall + forward into RS2)
    addi  x31, x0,  77
    bne   x12, x31, FAIL

# =============================================================================
# TEST 8: EX/MEM load forward (one gap -- no stall needed)
# Load is in EX/MEM when the consumer is in ID; forward ByteOut.
# =============================================================================
    addi  x1,  x0,  33
    sw    x1,  8(x20)
    lw    x13, 8(x20)           # x13 = 33
    addi  x14, x0,  0           # filler (load now in EX/MEM)
    add   x15, x13, x0          # x15 = 33  (forward from MEM ByteOut)
    addi  x31, x0,  33
    bne   x15, x31, FAIL

# =============================================================================
# TEST 9: Chain of RAW -- three consecutive dependent instructions
# Each result feeds the next. Tests EX forward chaining.
# =============================================================================
    addi  x1,  x0,  1           # x1  = 1
    addi  x1,  x1,  1           # x1  = 2   (EX forward x1)
    addi  x1,  x1,  1           # x1  = 3   (EX forward x1)
    addi  x31, x0,  3
    bne   x1,  x31, FAIL

# =============================================================================
# TEST 10: SIMULTANEOUS -- RS1 from EX, RS2 from EX/MEM (different sources)
# =============================================================================
    addi  x1,  x0,  4           # x1  = 4   (will be in EX next cycle)
    addi  x2,  x0,  6           # x2  = 6   (filler; x1 now in EX/MEM)
    add   x3,  x1,  x2          # x3  = 10  RS1 forward from EX/MEM (x1),
                                 #           RS2 forward from EX (x2)
    addi  x31, x0,  10
    bne   x3,  x31, FAIL

# =============================================================================
# TEST 11: SIMULTANEOUS -- load stall + EX/MEM forward on different registers
# x9 loaded (stall), while x1 also has a pending EX/MEM forward on RS2
# =============================================================================
    addi  x1,  x0,  5
    addi  x2,  x0,  50
    sw    x2,  12(x20)
    lw    x9,  12(x20)          # stall: x9 load
    add   x10, x9,  x1          # x10 = 55  x9 from MEM forward (stall resolved),
                                 #           x1 from EX/MEM forward
    addi  x31, x0,  55
    bne   x10, x31, FAIL

# =============================================================================
# TEST 12: RAW through AUIPC (forwarding of non-ALU EX result)
# =============================================================================
    auipc x1,  1                # x1  = PC + 0x1000
    add   x2,  x1, x0           # x2  = x1  (forward AUIPC result from EX)
    bne   x1,  x2, FAIL

# =============================================================================
# TEST 13: x0 exclusion -- writing to x0 should NOT trigger forwarding or stall
# =============================================================================
    addi  x0,  x0,  99          # writes x0 (no-op: x0 stays 0)
    add   x1,  x0,  x0          # x1 = 0  (should NOT forward 99 -- x0 excluded)
    bne   x1,  x0,  FAIL

# =============================================================================
# ALL PASS
# =============================================================================
    addi  x31, x0, 0            # x31 = 0 = all tests passed
    wfi

