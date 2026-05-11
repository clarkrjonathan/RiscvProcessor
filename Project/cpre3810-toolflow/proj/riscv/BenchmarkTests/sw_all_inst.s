# sw_all_instructions.s
# Tests ONLY the supported instructions:
# add, addi, and, andi, lui, lw, xor, xori, or, ori,
# slt, slti, sltiu, sll, srl, sra, sw, sub,
# beq, bne, blt, bge, bltu, bgeu,
# jal, jalr,
# lb, lh, lbu, lhu,
# slli, srli, srai,
# auipc, wfi

.data
test_mem:
    .word 123
    .half 511
    .byte 127
    .byte 255

scratch:
    .word 0

.text
.globl main

main:
    addi  x31, x0, 0

# LUI
    lui   x1, 1
    lui   x30, 1
    beq   x1, x30, lui_pass
    wfi
lui_pass:

# AUIPC
    auipc x2, 0
    bne   x2, x0, auipc_pass
    wfi
auipc_pass:

# ADDI
    addi  x1, x0, 42
    addi  x30, x0, 42
    beq   x1, x30, addi_pass
    wfi
addi_pass:

# ADD
    addi  x1, x0, 20
    addi  x2, x0, 7
    add   x3, x1, x2
    addi  x30, x0, 27
    beq   x3, x30, add_pass
    wfi
add_pass:

# SUB
    sub   x4, x1, x2
    addi  x30, x0, 13
    beq   x4, x30, sub_pass
    wfi
sub_pass:

# ANDI
    andi  x5, x1, 15
    addi  x30, x0, 4
    beq   x5, x30, andi_pass
    wfi
andi_pass:

# AND
    and   x6, x1, x2
    beq   x6, x30, and_pass
    wfi
and_pass:

# ORI
    ori   x5, x1, 15
    addi  x30, x0, 31
    beq   x5, x30, ori_pass
    wfi
ori_pass:

# OR
    or    x6, x1, x2
    addi  x30, x0, 23
    beq   x6, x30, or_pass
    wfi
or_pass:

# XORI
    xori  x5, x1, 15
    addi  x30, x0, 27
    beq   x5, x30, xori_pass
    wfi
xori_pass:

# XOR
    xor   x6, x1, x2
    addi  x30, x0, 19
    beq   x6, x30, xor_pass
    wfi
xor_pass:

# SLT
    slt   x5, x2, x1
    addi  x30, x0, 1
    beq   x5, x30, slt_pass
    wfi
slt_pass:

# SLTI
    slti  x5, x1, 100
    addi  x30, x0, 1
    beq   x5, x30, slti_pass
    wfi
slti_pass:

# SLTIU
    sltiu x5, x1, 100
    beq   x5, x30, sltiu_pass
    wfi
sltiu_pass:

# SLL
    addi  x1, x0, 1
    addi  x2, x0, 4
    sll   x5, x1, x2
    addi  x30, x0, 16
    beq   x5, x30, sll_pass
    wfi
sll_pass:

# SLLI
    slli  x5, x1, 3
    addi  x30, x0, 8
    beq   x5, x30, slli_pass
    wfi
slli_pass:

# SRL
    addi  x1, x0, 64
    addi  x2, x0, 2
    srl   x5, x1, x2
    addi  x30, x0, 16
    beq   x5, x30, srl_pass
    wfi
srl_pass:

# SRLI
    srli  x5, x1, 3
    addi  x30, x0, 8
    beq   x5, x30, srli_pass
    wfi
srli_pass:

# SRA
    addi  x1, x0, -64
    addi  x2, x0, 2
    sra   x5, x1, x2
    addi  x30, x0, -16
    beq   x5, x30, sra_pass
    wfi
sra_pass:

# SRAI
    srai  x5, x1, 3
    addi  x30, x0, -8
    beq   x5, x30, srai_pass
    wfi
srai_pass:

# SW / LW
    la    x20, scratch
    addi  x1, x0, 123
    sw    x1, 0(x20)
    lw    x6, 0(x20)
    addi  x30, x0, 123
    beq   x6, x30, lw_pass
    wfi
lw_pass:

# LH
    la    x20, test_mem
    lh    x6, 4(x20)
    addi  x30, x0, 511
    beq   x6, x30, lh_pass
    wfi
lh_pass:

# LHU
    lhu   x6, 4(x20)
    beq   x6, x30, lhu_pass
    wfi
lhu_pass:

# LB
    lb    x6, 6(x20)
    addi  x30, x0, 127
    beq   x6, x30, lb_pass
    wfi
lb_pass:

# LBU
    lbu   x6, 7(x20)
    addi  x30, x0, 255
    beq   x6, x30, lbu_pass
    wfi
lbu_pass:

# BEQ
    addi  x1, x0, 5
    addi  x2, x0, 5
    beq   x1, x2, beq_pass
    wfi
beq_pass:

# BNE
    addi  x1, x0, 5
    addi  x2, x0, 6
    bne   x1, x2, bne_pass
    wfi
bne_pass:

# BLT
    addi  x1, x0, -1
    addi  x2, x0, 1
    blt   x1, x2, blt_pass
    wfi
blt_pass:

# BGE
    bge   x2, x1, bge_pass
    wfi
bge_pass:

# BLTU
    addi  x1, x0, 1
    addi  x2, x0, -1
    bltu  x1, x2, bltu_pass
    wfi
bltu_pass:

# BGEU
    bgeu  x2, x1, bgeu_pass
    wfi
bgeu_pass:

# JAL
    jal   x10, jal_target

jal_ret:
    addi  x30, x0, 7
    beq   x5, x30, jal_pass
    wfi
jal_pass:

# JALR
    la    x1, jalr_target
    jalr  x11, x1, 0

jalr_ret:
    addi  x30, x0, 9
    beq   x5, x30, jalr_pass
    wfi
jalr_pass:

# ALL PASS
    addi  x31, x0, 0
    wfi
    jal   x0, finished

jal_target:
    addi  x5, x0, 7
    jal   x0, jal_ret

jalr_target:
    addi  x5, x0, 9
    jal   x0, jalr_ret

finished:
    wfi
