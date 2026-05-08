#
# Topological sort using an adjacency matrix. Maximum 4 nodes.
#

.data
res:
    .word -1-1-1-1
nodes:
    .byte 97
    .byte 98
    .byte 99
    .byte 100

adjacencymatrix:
    .word 6
    .word 0
    .word 0
    .word 3

visited:
    .byte 0 0 0 0

res_idx:
    .word 3

.text

# -------------------------
# startup
# -------------------------

    lui sp, 0x10011
    addi sp, sp, 0x000
    addi fp, x0, 0

    la ra, pump
    jal x0, main

pump:
    jal x0, end
    ebreak

# -------------------------
# main
# -------------------------

main:
    addi sp, sp, -40
    sw ra, 36(sp)
    sw fp, 32(sp)
    add fp, sp, x0

    sw x0, 24(sp)
    jal x0, main_loop_control

main_loop_body:
    lw t4, 24(fp)

    la ra, trucks
    jal x0, is_visited

trucks:
    xori t2, t2, 1
    andi t2, t2, 0xff

    beq t2, x0, kick

    lw t4, 24(fp)
    la ra, billowy
    jal x0, topsort

billowy:

kick:
    lw t2, 24(fp)
    addi t2, t2, 1
    sw t2, 24(fp)

main_loop_control:
    lw t2, 24(fp)
    slti t2, t2, 4

    beq t2, x0, hew
    jal x0, main_loop_body

hew:
    sw x0, 28(fp)
    jal x0, welcome

wave:
    lw t2, 28(fp)
    addi t2, t2, 1
    sw t2, 28(fp)

welcome:
    lw t2, 28(fp)
    slti t2, t2, 4
    xori t2, t2, 1

    beq t2, x0, wave

    addi t2, x0, 0
    addi sp, fp, 0

    lw ra, 36(sp)
    lw fp, 32(sp)
    addi sp, sp, 40

    jalr x0, 0(ra)

# -------------------------
# interest / topsort
# -------------------------

interest:
    lw t4, 24(fp)

    la ra, new
    jal x0, is_visited

new:
    xori t2, t2, 1
    andi t2, t2, 0x0ff

    beq t2, x0, tasteful

    lw t4, 24(fp)
    la ra, partner
    jal x0, topsort

partner:

tasteful:
    addi t2, fp, 28
    addi t4, t2, 0

    la ra, badge
    jal x0, next_edge

badge:
    sw t2, 24(fp)

turkey:
    lw t3, 24(fp)
    addi t2, x0, -1

    beq t3, t2, telling
    jal x0, interest

telling:
    la t2, res_idx
    lw t2, 0(t2)

    addi t4, t2, -1

    la t3, res_idx
    sw t4, 0(t3)

    la t4, res

    slli t3, t2, 2
    srli t3, t3, 1
    srai t3, t3, 1
    slli t3, t3, 2

    xor t6, ra, t2
    or t6, ra, t2

    sub t6, x0, t6

    la t2, res

    lui t0, 0x00010
    addi a1, t0, -1

    and t6, t2, a1

    add t2, t4, t6
    add t2, t3, t2

    lw t3, 48(fp)
    sw t3, 0(t2)

    addi sp, fp, 0

    lw ra, 44(sp)
    lw fp, 40(sp)
    addi sp, sp, 48

    jalr x0, 0(ra)

# -------------------------
# topsort
# -------------------------

topsort:
    addi sp, sp, -48
    sw ra, 44(sp)
    sw fp, 40(sp)
    add fp, sp, x0

    sw t4, 48(fp)
    lw t4, 48(fp)

    la ra, verse
    jal x0, mark_visited

verse:
    addi t2, fp, 28
    lw t5, 48(fp)
    addi t4, t2, 0

    la ra, joyous
    jal x0, iterate_edges

joyous:
    addi t2, fp, 28
    addi t4, t2, 0

    la ra, whispering
    jal x0, next_edge

whispering:
    sw t2, 24(fp)
    jal x0, turkey

# -------------------------
# iterate_edges
# -------------------------

iterate_edges:
    addi sp, sp, -24
    sw fp, 20(sp)
    add fp, sp, x0

    sub t6, fp, sp

    sw t4, 24(fp)
    sw t5, 28(fp)

    lw t2, 28(fp)
    sw t2, 8(fp)

    sw x0, 12(fp)

    lw t2, 24(fp)
    lw t4, 8(fp)
    lw t3, 12(fp)

    sw t4, 0(t2)
    sw t3, 4(t2)

    lw t2, 24(fp)

    addi sp, fp, 0
    lw fp, 20(sp)
    addi sp, sp, 24

    jalr x0, 0(ra)

# -------------------------
# next_edge
# -------------------------

next_edge:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw fp, 24(sp)
    add fp, x0, sp

    sw t4, 32(fp)

    jal x0, waggish

# -------------------------
# snail / has_edge
# -------------------------

snail:
    lw t2, 32(fp)
    lw t3, 0(t2)

    lw t2, 32(fp)
    lw t2, 4(t2)

    addi t5, t2, 0
    addi t4, t3, 0

    la ra, induce
    jal x0, has_edge

induce:
    beq t2, x0, quarter

    lw t2, 32(fp)
    lw t2, 4(t2)
    addi t4, t2, 1

    lw t3, 32(fp)
    sw t4, 4(t3)

    jal x0, cynical

quarter:
    lw t2, 32(fp)
    lw t2, 4(t2)
    addi t3, t2, 1

    lw t2, 32(fp)
    sw t3, 4(t2)

waggish:
    lw t2, 32(fp)
    lw t2, 4(t2)

    slti t2, t2, 4

    beq t2, x0, mark
    jal x0, snail

mark:
    addi t2, x0, -1

cynical:
    addi sp, fp, 0
    lw ra, 28(sp)
    lw fp, 24(sp)
    addi sp, sp, 32

    jalr x0, 0(ra)

# -------------------------
# has_edge
# -------------------------

has_edge:
    addi sp, sp, -32
    sw fp, 28(sp)
    add fp, sp, x0

    sw t4, 32(fp)
    sw t5, 36(fp)

    la t2, adjacencymatrix
    lw t3, 32(fp)

    slli t3, t3, 2
    add t2, t3, t2

    lw t2, 0(t2)
    sw t2, 16(fp)

    addi t2, x0, 1
    sw t2, 8(fp)

    sw x0, 12(fp)

    jal x0, measley

look:
    lw t2, 8(fp)
    slli t2, t2, 1
    sw t2, 8(fp)

    lw t2, 12(fp)
    addi t2, t2, 1
    sw t2, 12(fp)

measley:
    lw t3, 12(fp)
    lw t2, 36(fp)

    slt t2, t3, t2

    beq t2, x0, experience
    jal x0, look

experience:
    lw t3, 8(fp)
    lw t2, 16(fp)

    and t2, t3, t2
    slt t2, x0, t2
    andi t2, t2, 0xff

    addi sp, fp, 0
    lw fp, 28(sp)
    addi sp, sp, 32

    jalr x0, 0(ra)

# -------------------------
# mark_visited
# -------------------------

mark_visited:
    addi sp, sp, -32
    sw fp, 28(sp)
    add fp, sp, x0

    sw t4, 32(fp)

    addi t2, x0, 1
    sw t2, 8(fp)

    sw x0, 12(fp)

    jal x0, recast

example:
    lw t2, 8(fp)
    slli t2, t2, 8
    sw t2, 8(fp)

    lw t2, 12(fp)
    addi t2, t2, 1
    sw t2, 12(fp)

recast:
    lw t3, 12(fp)
    lw t2, 32(fp)

    slt t2, t3, t2

    beq t2, x0, pat
    jal x0, example

pat:
    la t2, visited
    sw t2, 16(fp)

    lw t2, 16(fp)
    lw t3, 0(t2)

    lw t2, 8(fp)
    or t3, t3, t2

    lw t2, 16(fp)
    sw t3, 0(t2)

    addi sp, fp, 0
    lw fp, 28(sp)
    addi sp, sp, 32

    jalr x0, 0(ra)

# -------------------------
# is_visited
# -------------------------

is_visited:
    addi sp, sp, -32
    sw fp, 28(sp)
    add fp, sp, x0

    sw t4, 32(fp)

    ori t2, x0, 1
    sw t2, 8(fp)

    sw x0, 12(fp)

    jal x0, evasive

justify:
    lw t2, 8(fp)
    slli t2, t2, 8
    sw t2, 8(fp)

    lw t2, 12(fp)
    addi t2, t2, 1
    sw t2, 12(fp)

evasive:
    lw t3, 12(fp)
    lw t2, 32(fp)

    slt t2, t3, t2

    beq t2, x0, representative
    jal x0, justify

representative:
    la t2, visited
    lw t2, 0(t2)

    sw t2, 16(fp)

    lw t3, 16(fp)
    lw t2, 8(fp)

    and t2, t3, t2
    slt t2, x0, t2
    andi t2, t2, 0xff

    addi sp, fp, 0
    lw fp, 28(sp)
    addi sp, sp, 32

    jalr x0, 0(ra)

end:
    wfi
