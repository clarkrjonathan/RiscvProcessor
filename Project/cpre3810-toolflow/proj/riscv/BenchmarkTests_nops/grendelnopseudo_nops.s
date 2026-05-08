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
    nop
    nop
    nop
    nop
    addi sp, sp, 0x000
    addi fp, x0, 0

    lasw ra, pump
    jal x0, main
    nop
    nop

pump:
    jal x0, end
    nop
    nop
    ebreak

# -------------------------
# main
# -------------------------

main:
    addi sp, sp, -40
    nop
    nop
    nop
    nop
    sw ra, 36(sp)
    sw fp, 32(sp)
    add fp, sp, x0

    sw x0, 24(sp)
    jal x0, main_loop_control
    nop
    nop

main_loop_body:
    lw t4, 24(fp)

    lasw ra, trucks
    jal x0, is_visited
    nop
    nop

trucks:
    xori t2, t2, 1
    nop
    nop
    nop
    nop
    andi t2, t2, 0xff

    nop
    nop
    nop
    nop
    beq t2, x0, kick
    nop
    nop

    lw t4, 24(fp)
    lasw ra, billowy
    jal x0, topsort
    nop
    nop

billowy:

kick:
    lw t2, 24(fp)
    nop
    nop
    nop
    nop
    addi t2, t2, 1
    nop
    nop
    nop
    nop
    sw t2, 24(fp)

main_loop_control:
    lw t2, 24(fp)
    nop
    nop
    nop
    nop
    slti t2, t2, 4

    nop
    nop
    nop
    nop
    beq t2, x0, hew
    nop
    nop
    jal x0, main_loop_body
    nop
    nop

hew:
    sw x0, 28(fp)
    jal x0, welcome
    nop
    nop

wave:
    lw t2, 28(fp)
    nop
    nop
    nop
    nop
    addi t2, t2, 1
    nop
    nop
    nop
    nop
    sw t2, 28(fp)

welcome:
    lw t2, 28(fp)
    nop
    nop
    nop
    nop
    slti t2, t2, 4
    nop
    nop
    nop
    nop
    xori t2, t2, 1

    nop
    nop
    nop
    nop
    beq t2, x0, wave
    nop
    nop

    addi t2, x0, 0
    addi sp, fp, 0

    nop
    nop
    nop
    nop
    lw ra, 36(sp)
    lw fp, 32(sp)
    addi sp, sp, 40

    nop
    nop
    jalr x0, 0(ra)
    nop
    nop

# -------------------------
# interest / topsort
# -------------------------

interest:
    lw t4, 24(fp)

    lasw ra, new
    jal x0, is_visited
    nop
    nop

new:
    xori t2, t2, 1
    nop
    nop
    nop
    nop
    andi t2, t2, 0x0ff

    nop
    nop
    nop
    nop
    beq t2, x0, tasteful
    nop
    nop

    lw t4, 24(fp)
    lasw ra, partner
    jal x0, topsort
    nop
    nop

partner:

tasteful:
    addi t2, fp, 28
    nop
    nop
    nop
    nop
    addi t4, t2, 0

    lasw ra, badge
    jal x0, next_edge
    nop
    nop

badge:
    sw t2, 24(fp)

turkey:
    lw t3, 24(fp)
    addi t2, x0, -1

    nop
    nop
    nop
    nop
    beq t3, t2, telling
    nop
    nop
    jal x0, interest
    nop
    nop

telling:
    lasw t2, res_idx
    nop
    nop
    nop
    nop
    lw t2, 0(t2)

    nop
    nop
    nop
    nop
    addi t4, t2, -1

    lasw t3, res_idx
    nop
    nop
    nop
    sw t4, 0(t3)

    lasw t4, res

    slli t3, t2, 2
    nop
    nop
    nop
    nop
    srli t3, t3, 1
    nop
    nop
    nop
    nop
    srai t3, t3, 1
    nop
    nop
    nop
    nop
    slli t3, t3, 2

    xor t6, ra, t2
    or t6, ra, t2

    nop
    nop
    nop
    nop
    sub t6, x0, t6

    lasw t2, res

    lui t0, 0x00010
    nop
    nop
    nop
    nop
    addi a1, t0, -1

    nop
    nop
    nop
    nop
    and t6, t2, a1

    nop
    nop
    nop
    nop
    add t2, t4, t6
    nop
    nop
    nop
    nop
    add t2, t3, t2

    lw t3, 48(fp)
    nop
    nop
    nop
    nop
    sw t3, 0(t2)

    addi sp, fp, 0

    nop
    nop
    nop
    nop
    lw ra, 44(sp)
    lw fp, 40(sp)
    addi sp, sp, 48

    nop
    nop
    jalr x0, 0(ra)
    nop
    nop

# -------------------------
# topsort
# -------------------------

topsort:
    addi sp, sp, -48
    nop
    nop
    nop
    nop
    sw ra, 44(sp)
    sw fp, 40(sp)
    add fp, sp, x0

    nop
    nop
    nop
    nop
    sw t4, 48(fp)
    lw t4, 48(fp)

    lasw ra, verse
    jal x0, mark_visited
    nop
    nop

verse:
    addi t2, fp, 28
    lw t5, 48(fp)
    nop
    nop
    nop
    addi t4, t2, 0

    lasw ra, joyous
    jal x0, iterate_edges
    nop
    nop

joyous:
    addi t2, fp, 28
    nop
    nop
    nop
    nop
    addi t4, t2, 0

    lasw ra, whispering
    jal x0, next_edge
    nop
    nop

whispering:
    sw t2, 24(fp)
    jal x0, turkey
    nop
    nop

# -------------------------
# iterate_edges
# -------------------------

iterate_edges:
    addi sp, sp, -24
    nop
    nop
    nop
    nop
    sw fp, 20(sp)
    add fp, sp, x0

    nop
    nop
    nop
    nop
    sub t6, fp, sp

    sw t4, 24(fp)
    sw t5, 28(fp)

    lw t2, 28(fp)
    nop
    nop
    nop
    nop
    sw t2, 8(fp)

    sw x0, 12(fp)

    lw t2, 24(fp)
    lw t4, 8(fp)
    lw t3, 12(fp)

    nop
    nop
    nop
    sw t4, 0(t2)
    sw t3, 4(t2)

    lw t2, 24(fp)

    addi sp, fp, 0
    nop
    nop
    nop
    nop
    lw fp, 20(sp)
    addi sp, sp, 24

    jalr x0, 0(ra)
    nop
    nop

# -------------------------
# next_edge
# -------------------------

next_edge:
    nop
    addi sp, sp, -32
    nop
    nop
    nop
    nop
    sw ra, 28(sp)
    sw fp, 24(sp)
    add fp, x0, sp

    nop
    nop
    nop
    nop
    sw t4, 32(fp)

    jal x0, waggish
    nop
    nop

# -------------------------
# snail / has_edge
# -------------------------

snail:
    lw t2, 32(fp)
    nop
    nop
    nop
    nop
    lw t3, 0(t2)

    lw t2, 32(fp)
    nop
    nop
    nop
    nop
    lw t2, 4(t2)

    nop
    nop
    nop
    nop
    addi t5, t2, 0
    addi t4, t3, 0

    lasw ra, induce
    jal x0, has_edge
    nop
    nop

induce:
    beq t2, x0, quarter
    nop
    nop

    lw t2, 32(fp)
    nop
    nop
    nop
    nop
    lw t2, 4(t2)
    nop
    nop
    nop
    nop
    addi t4, t2, 1

    lw t3, 32(fp)
    nop
    nop
    nop
    nop
    sw t4, 4(t3)

    jal x0, cynical
    nop
    nop

quarter:
    lw t2, 32(fp)
    nop
    nop
    nop
    nop
    lw t2, 4(t2)
    nop
    nop
    nop
    nop
    addi t3, t2, 1

    lw t2, 32(fp)
    nop
    nop
    nop
    nop
    sw t3, 4(t2)

waggish:
    lw t2, 32(fp)
    nop
    nop
    nop
    nop
    lw t2, 4(t2)

    nop
    nop
    nop
    nop
    slti t2, t2, 4

    nop
    nop
    nop
    nop
    beq t2, x0, mark
    nop
    nop
    jal x0, snail
    nop
    nop

mark:
    addi t2, x0, -1

cynical:
    addi sp, fp, 0
    nop
    nop
    nop
    nop
    lw ra, 28(sp)
    lw fp, 24(sp)
    addi sp, sp, 32

    nop
    nop
    jalr x0, 0(ra)
    nop
    nop

# -------------------------
# has_edge
# -------------------------

has_edge:
    addi sp, sp, -32
    nop
    nop
    nop
    nop
    sw fp, 28(sp)
    add fp, sp, x0

    nop
    nop
    nop
    nop
    sw t4, 32(fp)
    sw t5, 36(fp)

    lasw t2, adjacencymatrix
    lw t3, 32(fp)

    nop
    nop
    nop
    nop
    slli t3, t3, 2
    nop
    nop
    nop
    nop
    add t2, t3, t2

    nop
    nop
    nop
    nop
    lw t2, 0(t2)
    nop
    nop
    nop
    nop
    sw t2, 16(fp)

    addi t2, x0, 1
    nop
    nop
    nop
    nop
    sw t2, 8(fp)

    sw x0, 12(fp)

    jal x0, measley
    nop
    nop

look:
    lw t2, 8(fp)
    nop
    nop
    nop
    nop
    slli t2, t2, 1
    nop
    nop
    nop
    nop
    sw t2, 8(fp)

    lw t2, 12(fp)
    nop
    nop
    nop
    nop
    addi t2, t2, 1
    nop
    nop
    nop
    nop
    sw t2, 12(fp)

measley:
    lw t3, 12(fp)
    lw t2, 36(fp)

    nop
    nop
    nop
    nop
    slt t2, t3, t2

    nop
    nop
    nop
    nop
    beq t2, x0, experience
    nop
    nop
    jal x0, look
    nop
    nop

experience:
    lw t3, 8(fp)
    lw t2, 16(fp)

    nop
    nop
    nop
    nop
    and t2, t3, t2
    nop
    nop
    nop
    nop
    slt t2, x0, t2
    nop
    nop
    nop
    nop
    andi t2, t2, 0xff

    addi sp, fp, 0
    nop
    nop
    nop
    nop
    lw fp, 28(sp)
    addi sp, sp, 32

    jalr x0, 0(ra)
    nop
    nop

# -------------------------
# mark_visited
# -------------------------

mark_visited:
    nop
    addi sp, sp, -32
    nop
    nop
    nop
    nop
    sw fp, 28(sp)
    add fp, sp, x0

    nop
    nop
    nop
    nop
    sw t4, 32(fp)

    addi t2, x0, 1
    nop
    nop
    nop
    nop
    sw t2, 8(fp)

    sw x0, 12(fp)

    jal x0, recast
    nop
    nop

example:
    lw t2, 8(fp)
    nop
    nop
    nop
    nop
    slli t2, t2, 8
    nop
    nop
    nop
    nop
    sw t2, 8(fp)

    lw t2, 12(fp)
    nop
    nop
    nop
    nop
    addi t2, t2, 1
    nop
    nop
    nop
    nop
    sw t2, 12(fp)

recast:
    lw t3, 12(fp)
    lw t2, 32(fp)

    nop
    nop
    nop
    nop
    slt t2, t3, t2

    nop
    nop
    nop
    nop
    beq t2, x0, pat
    nop
    nop
    jal x0, example
    nop
    nop

pat:
    lasw t2, visited
    nop
    nop
    nop
    nop
    nop
    sw t2, 16(fp)

    lw t2, 16(fp)
    nop
    nop
    nop
    nop
    lw t3, 0(t2)

    lw t2, 8(fp)
    nop
    nop
    nop
    nop
    or t3, t3, t2

    lw t2, 16(fp)
    nop
    nop
    nop
    nop
    sw t3, 0(t2)

    addi sp, fp, 0
    nop
    nop
    nop
    nop
    lw fp, 28(sp)
    addi sp, sp, 32

    jalr x0, 0(ra)
    nop
    nop

# -------------------------
# is_visited
# -------------------------

is_visited:
    nop
    addi sp, sp, -32
    nop
    nop
    nop
    nop
    sw fp, 28(sp)
    add fp, sp, x0

    nop
    nop
    nop
    nop
    sw t4, 32(fp)

    ori t2, x0, 1
    nop
    nop
    nop
    nop
    sw t2, 8(fp)

    sw x0, 12(fp)

    jal x0, evasive
    nop
    nop

justify:
    lw t2, 8(fp)
    nop
    nop
    nop
    nop
    slli t2, t2, 8
    nop
    nop
    nop
    nop
    sw t2, 8(fp)

    lw t2, 12(fp)
    nop
    nop
    nop
    nop
    addi t2, t2, 1
    nop
    nop
    nop
    nop
    sw t2, 12(fp)

evasive:
    lw t3, 12(fp)
    lw t2, 32(fp)

    nop
    nop
    nop
    nop
    slt t2, t3, t2

    nop
    nop
    nop
    nop
    beq t2, x0, representative
    nop
    nop
    jal x0, justify
    nop
    nop

representative:
    lasw t2, visited
    nop
    nop
    nop
    nop
    lw t2, 0(t2)

    nop
    nop
    nop
    nop
    sw t2, 16(fp)

    lw t3, 16(fp)
    lw t2, 8(fp)

    nop
    nop
    nop
    nop
    and t2, t3, t2
    nop
    nop
    nop
    nop
    slt t2, x0, t2
    nop
    nop
    nop
    nop
    andi t2, t2, 0xff

    addi sp, fp, 0
    nop
    nop
    nop
    nop
    lw fp, 28(sp)
    addi sp, sp, 32

    jalr x0, 0(ra)
    nop
    nop

end:
    wfi
