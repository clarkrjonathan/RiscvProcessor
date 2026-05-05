.data
array_size: .word 12
array: .word 65, 12, 10, 89, 11, 70, 67, 5, 9, 45, 90, 7

temp: .space 2048

.text
.globl main


# ---------------- MAIN ----------------
main:
    addi sp, sp, -4
    nop
    nop
    nop
    nop
    sw ra, 0(sp)

    lasw a0, array

    lui t0, %hi(array_size)
    nop
    nop
    nop
    nop
    lw a1, %lo(array_size)(t0)

    lui t1, %hi(sort)
    nop
    nop
    nop
    nop
    addi t1, t1, %lo(sort)
    nop
    nop
    nop
    nop
    jalr ra, 0(t1)
    nop
    nop

    lw ra, 0(sp)
    addi sp, sp, 4

    addi a7, x0, 10
    ecall

    wfi


# ---------------- SORT ----------------
sort:
    nop
    addi sp, sp, -36
    nop
    nop
    nop
    nop
    sw ra, 32(sp)
    sw s0, 28(sp)
    sw s1, 24(sp)
    sw s2, 20(sp)
    sw s3, 16(sp)
    sw s4, 12(sp)
    sw s5, 8(sp)
    sw s6, 4(sp)
    sw s7, 0(sp)

    addi s0, a0, 0
    addi s1, a1, 0

    lasw s2, temp

    addi t0, x0, 2
    nop
    nop
    nop
    nop
    blt s1, t0, sort_done
    nop
    nop

    addi s3, x0, 1


outer_width_loop:
    nop
    nop
    nop
    nop
    bge s3, s1, sort_done
    nop
    nop

    addi s4, x0, 0


pair_loop:
    nop
    nop
    nop
    nop
    bge s4, s1, copy_back
    nop
    nop

    add s5, s4, s3
    nop
    nop
    nop
    nop
    blt s5, s1, mid_ok
    nop
    nop
    addi s5, s1, 0

mid_ok:
    slli t0, s3, 1
    nop
    nop
    nop
    nop
    add s6, s4, t0
    nop
    nop
    nop
    nop
    blt s6, s1, right_ok
    nop
    nop
    addi s6, s1, 0

right_ok:
    addi t1, s4, 0
    addi t2, s5, 0
    addi t3, s4, 0


merge_loop:
    nop
    nop
    bge t1, s5, copy_right_remain
    nop
    nop
    bge t2, s6, copy_left_remain
    nop
    nop

    slli t4, t1, 2
    nop
    nop
    nop
    nop
    add t5, s0, t4
    nop
    nop
    nop
    nop
    lw t6, 0(t5)

    slli t4, t2, 2
    nop
    nop
    nop
    nop
    add t5, s0, t4
    nop
    nop
    nop
    nop
    lw t0, 0(t5)

    nop
    nop
    nop
    nop
    ble t6, t0, take_left
    nop
    nop


take_right:
    slli t4, t3, 2
    nop
    nop
    nop
    nop
    add t5, s2, t4
    nop
    nop
    nop
    nop
    sw t0, 0(t5)

    addi t2, t2, 1
    addi t3, t3, 1

    lui t0, %hi(merge_loop)
    nop
    nop
    nop
    nop
    addi t0, t0, %lo(merge_loop)
    nop
    nop
    nop
    nop
    jalr x0, 0(t0)
    nop
    nop


take_left:
    slli t4, t3, 2
    nop
    nop
    nop
    nop
    add t5, s2, t4
    nop
    nop
    nop
    nop
    sw t6, 0(t5)

    addi t1, t1, 1
    addi t3, t3, 1

    lui t0, %hi(merge_loop)
    nop
    nop
    nop
    nop
    addi t0, t0, %lo(merge_loop)
    nop
    nop
    nop
    nop
    jalr x0, 0(t0)
    nop
    nop


copy_left_remain:
    bge t1, s5, next_pair
    nop
    nop


copy_left_loop:
    bge t1, s5, next_pair
    nop
    nop

    slli t4, t1, 2
    nop
    nop
    nop
    nop
    add t5, s0, t4
    nop
    nop
    nop
    nop
    lw t6, 0(t5)

    slli t4, t3, 2
    nop
    nop
    nop
    nop
    add t5, s2, t4
    nop
    nop
    nop
    nop
    sw t6, 0(t5)

    addi t1, t1, 1
    addi t3, t3, 1

    lui t0, %hi(copy_left_loop)
    nop
    nop
    nop
    nop
    addi t0, t0, %lo(copy_left_loop)
    nop
    nop
    nop
    nop
    jalr x0, 0(t0)
    nop
    nop


copy_right_remain:
    bge t2, s6, next_pair
    nop
    nop


copy_right_loop:
    bge t2, s6, next_pair
    nop
    nop

    slli t4, t2, 2
    nop
    nop
    nop
    nop
    add t5, s0, t4
    nop
    nop
    nop
    nop
    lw t6, 0(t5)

    slli t4, t3, 2
    nop
    nop
    nop
    nop
    add t5, s2, t4
    nop
    nop
    nop
    nop
    sw t6, 0(t5)

    addi t2, t2, 1
    addi t3, t3, 1

    lui t0, %hi(copy_right_loop)
    nop
    nop
    nop
    nop
    addi t0, t0, %lo(copy_right_loop)
    nop
    nop
    nop
    nop
    jalr x0, 0(t0)
    nop
    nop


next_pair:
    slli t0, s3, 1
    nop
    nop
    nop
    nop
    add s4, s4, t0

    lui t0, %hi(pair_loop)
    nop
    nop
    nop
    nop
    addi t0, t0, %lo(pair_loop)
    nop
    nop
    nop
    nop
    jalr x0, 0(t0)
    nop
    nop


copy_back:
    addi s7, x0, 0


copy_back_loop:
    nop
    nop
    nop
    nop
    bge s7, s1, next_width
    nop
    nop

    slli t0, s7, 2
    nop
    nop
    nop
    nop
    add t1, s2, t0
    nop
    nop
    nop
    nop
    lw t2, 0(t1)

    add t3, s0, t0
    nop
    nop
    nop
    nop
    sw t2, 0(t3)

    addi s7, s7, 1

    lui t0, %hi(copy_back_loop)
    nop
    nop
    nop
    nop
    addi t0, t0, %lo(copy_back_loop)
    nop
    nop
    nop
    nop
    jalr x0, 0(t0)
    nop
    nop


next_width:
    slli s3, s3, 1

    lui t0, %hi(outer_width_loop)
    nop
    nop
    nop
    nop
    addi t0, t0, %lo(outer_width_loop)
    nop
    nop
    nop
    nop
    jalr x0, 0(t0)
    nop
    nop


sort_done:
    lw s7, 0(sp)
    lw s6, 4(sp)
    lw s5, 8(sp)
    lw s4, 12(sp)
    lw s3, 16(sp)
    lw s2, 20(sp)
    lw s1, 24(sp)
    lw s0, 28(sp)
    lw ra, 32(sp)

    addi sp, sp, 36

    nop
    nop
    nop
    jalr x0, 0(ra)
    nop
    nop
