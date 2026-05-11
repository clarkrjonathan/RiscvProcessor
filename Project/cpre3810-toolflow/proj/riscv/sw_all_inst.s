# sw_all_instructions.s
# No NOPs included - add 3 NOPs after every register write before reading,
# and 2 NOPs after every branch/jump.
# Each test branches over a wfi on pass; falling into wfi = failure.
# x30 = scratch. x31 = 0 at end means all passed.

.text
.globl main
main:
    addi  x31, x0, 0

# LUI
    lui   x1,  1                # x1 = 0x00001000
    lui   x30, 1                # x30 = 0x00001000
    beq   x1,  x30, lui_pass
    wfi
lui_pass:

# AUIPC
    auipc x2,  0                # x2 = PC (nonzero)
    bne   x2,  x0,  auipc_pass
    wfi
auipc_pass:

# ADDI
    addi  x1,  x0,  42
    addi  x30, x0,  42
    beq   x1,  x30, addi_pass
    wfi
addi_pass:

# ADD
    addi  x1,  x0,  20
    addi  x2,  x0,  7
    add   x3,  x1,  x2          # x3 = 27
    addi  x30, x0,  27
    beq   x3,  x30, add_pass
    wfi
add_pass:

# SUB
    sub   x4,  x1,  x2          # x4 = 13
    addi  x30, x0,  13
    beq   x4,  x30, sub_pass
    wfi
sub_pass:

# ANDI
    andi  x5,  x1,  15          # x5 = 4
    addi  x30, x0,  4
    beq   x5,  x30, andi_pass
    wfi
andi_pass:

# AND
    and   x6,  x1,  x2          # x6 = 4
    beq   x6,  x30, and_pass
    wfi
and_pass:

# ORI
    ori   x5,  x1,  15          # x5 = 31
    addi  x30, x0,  31
    beq   x5,  x30, ori_pass
    wfi
ori_pass:

# OR
    or    x6,  x1,  x2          # x6 = 23
    addi  x30, x0,  23
    beq   x6,  x30, or_pass
    wfi
or_pass:

# XORI
    xori  x5,  x1,  15          # x5 = 27
    addi  x30, x0,  27
    beq   x5,  x30, xori_pass
    wfi
xori_pass:

# XOR
    xor   x6,  x1,  x2          # x6 = 19
    addi  x30, x0,  19
    beq   x6,  x30, xor_pass
    wfi
xor_pass:

# SLT
    slt   x5,  x2,  x1          # x5 = 1  (7 < 20)
    addi  x30, x0,  1
    beq   x5,  x30, slt_pass
    wfi
slt_pass:
    slt   x5,  x1,  x2          # x5 = 0  (20 not < 7)
    beq   x5,  x0,  slt0_pass
    wfi
slt0_pass:

# SLTI
    slti  x5,  x1,  100         # x5 = 1
    addi  x30, x0,  1
    beq   x5,  x30, slti_pass
    wfi
slti_pass:

# SLTU
    sltu  x5,  x2,  x1          # x5 = 1  (7 <u 20)
    addi  x30, x0,  1
    beq   x5,  x30, sltu_pass
    wfi
sltu_pass:

# SLTIU
    sltiu x5,  x1,  100         # x5 = 1
    beq   x5,  x30, sltiu_pass
    wfi
sltiu_pass:

# SLL
    addi  x1,  x0,  1
    addi  x2,  x0,  4
    sll   x5,  x1,  x2          # x5 = 16
    addi  x30, x0,  16
    beq   x5,  x30, sll_pass
    wfi
sll_pass:

# SLLI
    slli  x5,  x1,  3           # x5 = 8
    addi  x30, x0,  8
    beq   x5,  x30, slli_pass
    wfi
slli_pass:

# SRL
    addi  x1,  x0,  64
    addi  x2,  x0,  2
    srl   x5,  x1,  x2          # x5 = 16
    addi  x30, x0,  16
    beq   x5,  x30, srl_pass
    wfi
srl_pass:

# SRLI
    srli  x5,  x1,  3           # x5 = 8
    addi  x30, x0,  8
    beq   x5,  x30, srli_pass
    wfi
srli_pass:

# SRA
    addi  x1,  x0,  -64
    addi  x2,  x0,  2
    sra   x5,  x1,  x2          # x5 = -16
    addi  x30, x0,  -16
    beq   x5,  x30, sra_pass
    wfi
sra_pass:

# SRAI
    srai  x5,  x1,  3           # x5 = -8
    addi  x30, x0,  -8
    beq   x5,  x30, srai_pass
    wfi
srai_pass:

# SW / LW
    lui   x20, 0x10010          # x20 = 0x10010000
    addi  x1,  x0,  123
    sw    x1,  0(x20)
    lw    x6,  0(x20)
    addi  x30, x0,  123
    beq   x6,  x30, lw_pass
    wfi
lw_pass:

# SH / LH
    addi  x1,  x0,  511
    sh    x1,  4(x20)
    lh    x6,  4(x20)
    addi  x30, x0,  511
    beq   x6,  x30, lh_pass
    wfi
lh_pass:

# LHU
    lhu   x6,  4(x20)
    beq   x6,  x30, lhu_pass
    wfi
lhu_pass:

# SB / LB
    addi  x1,  x0,  127
    sb    x1,  8(x20)
    lb    x6,  8(x20)
    addi  x30, x0,  127
    beq   x6,  x30, lb_pass
    wfi
lb_pass:

# LBU
    lbu   x6,  8(x20)
    beq   x6,  x30, lbu_pass
    wfi
lbu_pass:

# LB sign extend
    addi  x1,  x0,  -1
    sb    x1,  12(x20)
    lb    x6,  12(x20)          # x6 = -1
    addi  x30, x0,  -1
    beq   x6,  x30, lb_neg_pass
    wfi
lb_neg_pass:

# LBU zero extend
    lbu   x6,  12(x20)          # x6 = 255
    addi  x30, x0,  255
    beq   x6,  x30, lbu_neg_pass
    wfi
lbu_neg_pass:

# BEQ taken
    addi  x1,  x0,  5
    addi  x2,  x0,  5
    beq   x1,  x2,  beq_taken
    wfi
beq_taken:

# BEQ not-taken
    addi  x1,  x0,  5
    addi  x2,  x0,  6
    bne   x1,  x2,  beq_nt_pass
    wfi
beq_nt_pass:

# BNE taken
    addi  x1,  x0,  3
    addi  x2,  x0,  7
    bne   x1,  x2,  bne_taken
    wfi
bne_taken:

# BLT taken
    addi  x1,  x0,  -1
    addi  x2,  x0,  1
    blt   x1,  x2,  blt_taken
    wfi
blt_taken:

# BGE taken
    bge   x2,  x1,  bge_taken   # 1 >= -1
    wfi
bge_taken:

# BGE not-taken: -1 >= 1 should not take
    bge   x1,  x2,  bge_nt_fail
    addi  x5,  x0,  2
    addi  x30, x0,  2
    beq   x5,  x30, bge_nt_pass
    wfi
bge_nt_fail:
    wfi
bge_nt_pass:

# BLTU taken
    addi  x1,  x0,  1
    addi  x2,  x0,  -1          # 0xFFFFFFFF unsigned
    bltu  x1,  x2,  bltu_taken
    wfi
bltu_taken:

# BGEU taken
    bgeu  x2,  x1,  bgeu_taken
    wfi
bgeu_taken:

# JAL
    jal   x10, jal_target
jal_ret:
    addi  x30, x0,  7
    beq   x5,  x30, jal_pass
    wfi
jal_pass:

# JALR
    lasw  x1,  jalr_target
    jalr  x11, 0(x1)
jalr_ret:
    addi  x30, x0,  9
    beq   x5,  x30, jalr_pass
    wfi
jalr_pass:

# ALL PASS
    addi  x31, x0, 0
    wfi
    jal x0, finished

# JAL target
jal_target:
    addi  x5, x0, 7
    jal   x0, jal_ret

# JALR target
jalr_target:
    addi  x5, x0, 9
    jal   x0, jalr_ret

finished:
    wfi