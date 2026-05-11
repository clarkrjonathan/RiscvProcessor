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
    nop
    nop
    nop
    beq   x1, x30, lui_pass
    nop
    nop
    wfi
lui_pass:

# AUIPC
    auipc x2, 0
    nop
    nop
    nop
    bne   x2, x0, auipc_pass
    nop
    nop
    wfi
auipc_pass:

# ADDI
    addi  x1, x0, 42
    addi  x30, x0, 42
    nop
    nop
    nop
    beq   x1, x30, addi_pass
    nop
    nop
    wfi
addi_pass:

# ADD
    addi  x1, x0, 20
    addi  x2, x0, 7
    nop
    nop
    nop
    add   x3, x1, x2
    addi  x30, x0, 27
    nop
    nop
    nop
    beq   x3, x30, add_pass
    nop
    nop
    wfi
add_pass:

# SUB
    sub   x4, x1, x2
    addi  x30, x0, 13
    nop
    nop
    nop
    beq   x4, x30, sub_pass
    nop
    nop
    wfi
sub_pass:

# ANDI
    andi  x5, x1, 15
    addi  x30, x0, 4
    nop
    nop
    nop
    beq   x5, x30, andi_pass
    nop
    nop
    wfi
andi_pass:

# AND
    and   x6, x1, x2
    nop
    nop
    nop
    beq   x6, x30, and_pass
    nop
    nop
    wfi
and_pass:

# ORI
    ori   x5, x1, 15
    addi  x30, x0, 31
    nop
    nop
    nop
    beq   x5, x30, ori_pass
    nop
    nop
    wfi
ori_pass:

# OR
    or    x6, x1, x2
    addi  x30, x0, 23
    nop
    nop
    nop
    beq   x6, x30, or_pass
    nop
    nop
    wfi
or_pass:

# XORI
    xori  x5, x1, 15
    addi  x30, x0, 27
    nop
    nop
    nop
    beq   x5, x30, xori_pass
    nop
    nop
    wfi
xori_pass:

# XOR
    xor   x6, x1, x2
    addi  x30, x0, 19
    nop
    nop
    nop
    beq   x6, x30, xor_pass
    nop
    nop
    wfi
xor_pass:

# SLT
    slt   x5, x2, x1
    addi  x30, x0, 1
    nop
    nop
    nop
    beq   x5, x30, slt_pass
    nop
    nop
    wfi
slt_pass:

# SLTI
    slti  x5, x1, 100
    addi  x30, x0, 1
    nop
    nop
    nop
    beq   x5, x30, slti_pass
    nop
    nop
    wfi
slti_pass:

# SLTIU
    sltiu x5, x1, 100
    beq   x5, x30, sltiu_pass
    nop
    nop
    wfi
sltiu_pass:

# SLL
    addi  x1, x0, 1
    addi  x2, x0, 4
    nop
    nop
    nop
    sll   x5, x1, x2
    addi  x30, x0, 16
    nop
    nop
    nop
    beq   x5, x30, sll_pass
    nop
    nop
    wfi
sll_pass:

# SLLI
    slli  x5, x1, 3
    addi  x30, x0, 8
    nop
    nop
    nop
    beq   x5, x30, slli_pass
    nop
    nop
    wfi
slli_pass:

# SRL
    addi  x1, x0, 64
    addi  x2, x0, 2
    nop
    nop
    nop
    srl   x5, x1, x2
    addi  x30, x0, 16
    nop
    nop
    nop
    beq   x5, x30, srl_pass
    nop
    nop
    wfi
srl_pass:

# SRLI
    srli  x5, x1, 3
    addi  x30, x0, 8
    nop
    nop
    nop
    beq   x5, x30, srli_pass
    nop
    nop
    wfi
srli_pass:

# SRA
    addi  x1, x0, -64
    addi  x2, x0, 2
    nop
    nop
    nop
    sra   x5, x1, x2
    addi  x30, x0, -16
    nop
    nop
    nop
    beq   x5, x30, sra_pass
    nop
    nop
    wfi
sra_pass:

# SRAI
    srai  x5, x1, 3
    addi  x30, x0, -8
    nop
    nop
    nop
    beq   x5, x30, srai_pass
    nop
    nop
    wfi
srai_pass:

# SW / LW
    lasw    x20, scratch
    addi  x1, x0, 123
    nop
    nop
    nop
    sw    x1, 0(x20)
    lw    x6, 0(x20)
    addi  x30, x0, 123
    nop
    nop
    nop
    beq   x6, x30, lw_pass
    nop
    nop
    wfi
lw_pass:

# LH
    lasw    x20, test_mem
    nop
    nop
    nop
    lh    x6, 4(x20)
    addi  x30, x0, 511
    nop
    nop
    nop
    beq   x6, x30, lh_pass
    nop
    nop
    wfi
lh_pass:

# LHU
    lhu   x6, 4(x20)
    nop
    nop
    nop
    beq   x6, x30, lhu_pass
    nop
    nop
    wfi
lhu_pass:

# LB
    lb    x6, 6(x20)
    addi  x30, x0, 127
    nop
    nop
    nop
    beq   x6, x30, lb_pass
    nop
    nop
    wfi
lb_pass:

# LBU
    lbu   x6, 7(x20)
    addi  x30, x0, 255
    nop
    nop
    nop
    beq   x6, x30, lbu_pass
    nop
    nop
    wfi
lbu_pass:

# BEQ
    addi  x1, x0, 5
    addi  x2, x0, 5
    nop
    nop
    nop
    beq   x1, x2, beq_pass
    nop
    nop
    wfi
beq_pass:

# BNE
    addi  x1, x0, 5
    addi  x2, x0, 6
    nop
    nop
    nop
    bne   x1, x2, bne_pass
    nop
    nop
    wfi
bne_pass:

# BLT
    addi  x1, x0, -1
    addi  x2, x0, 1
    nop
    nop
    nop
    blt   x1, x2, blt_pass
    nop
    nop
    wfi
blt_pass:

# BGE
    bge   x2, x1, bge_pass
    nop
    nop
    wfi
bge_pass:

# BLTU
    addi  x1, x0, 1
    addi  x2, x0, -1
    nop
    nop
    nop
    bltu  x1, x2, bltu_pass
    nop
    nop
    wfi
bltu_pass:

# BGEU
    bgeu  x2, x1, bgeu_pass
    nop
    nop
    wfi
bgeu_pass:

# JAL
    jal   x10, jal_target
    nop
    nop

jal_ret:
    addi  x30, x0, 7
    nop
    nop
    nop
    beq   x5, x30, jal_pass
    nop
    nop
    wfi
jal_pass:

# JALR
    lasw    x1, jalr_target
    nop
    nop
    nop
    jalr  x11, x1, 0
    nop
    nop

jalr_ret:
    addi  x30, x0, 9
    nop
    nop
    nop
    beq   x5, x30, jalr_pass
    nop
    nop
    wfi
jalr_pass:

# ALL PASS
    addi  x31, x0, 0
    wfi
    jal   x0, finished
    nop
    nop

jal_target:
    addi  x5, x0, 7
    jal   x0, jal_ret
    nop
    nop

jalr_target:
    addi  x5, x0, 9
    jal   x0, jalr_ret
    nop
    nop

finished:
    wfi
