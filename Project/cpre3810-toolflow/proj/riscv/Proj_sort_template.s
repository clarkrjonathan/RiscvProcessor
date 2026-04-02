.data
array_size: .word 12
array: .word 65, 12, 10, 89, 11, 70, 67, 5, 9, 45, 90, 7

# temp buffer for up to 512 ints
temp: .space 2048

.text
.globl main

main:
    # save ra
    addi sp, sp, -4
    sw ra, 0(sp)

    la a0, array
    lw a1, array_size
    jal ra, sort

    # restore ra
    lw ra, 0(sp)
    addi sp, sp, 4

    # end
    li a7, 10
    ecall
    
    wfi


# ---------------------------------------------------------
# sort(int* array, int size)
# a0 = array base
# a1 = size
# ---------------------------------------------------------
sort:
    # stack frame
    addi sp, sp, -36
    sw ra, 32(sp)
    sw s0, 28(sp)
    sw s1, 24(sp)
    sw s2, 20(sp)
    sw s3, 16(sp)
    sw s4, 12(sp)
    sw s5, 8(sp)
    sw s6, 4(sp)
    sw s7, 0(sp)

    mv s0, a0          # s0 = array base
    mv s1, a1          # s1 = size
    la s2, temp        # s2 = temp base

    # if size <= 1 return
    li t0, 2
    blt s1, t0, sort_done

    li s3, 1           # width = 1

outer_width_loop:
    # while width < size
    bge s3, s1, sort_done

    li s4, 0           # left = 0

pair_loop:
    # if left >= size, copy temp back to array
    bge s4, s1, copy_back

    # mid = left + width
    add s5, s4, s3
    blt s5, s1, mid_ok
    mv s5, s1
mid_ok:

    # right = left + 2*width
    slli t0, s3, 1
    add s6, s4, t0
    blt s6, s1, right_ok
    mv s6, s1
right_ok:

    # i = left
    mv t1, s4
    # j = mid
    mv t2, s5
    # k = left
    mv t3, s4

merge_loop:
    # if i >= mid, copy right remainder
    bge t1, s5, copy_right_remain
    # if j >= right, copy left remainder
    bge t2, s6, copy_left_remain

    # load array[i] into t6
    slli t4, t1, 2
    add t5, s0, t4
    lw t6, 0(t5)

    # load array[j] into t0
    slli t4, t2, 2
    add t5, s0, t4
    lw t0, 0(t5)

    # if array[i] <= array[j], take left
    ble t6, t0, take_left

take_right:
    # temp[k] = array[j]
    slli t4, t3, 2
    add t5, s2, t4
    sw t0, 0(t5)

    addi t2, t2, 1     # j++
    addi t3, t3, 1     # k++
    j merge_loop

take_left:
    # temp[k] = array[i]
    slli t4, t3, 2
    add t5, s2, t4
    sw t6, 0(t5)

    addi t1, t1, 1     # i++
    addi t3, t3, 1     # k++
    j merge_loop


copy_left_remain:
    bge t1, s5, next_pair

copy_left_loop:
    bge t1, s5, next_pair

    slli t4, t1, 2
    add t5, s0, t4
    lw t6, 0(t5)

    slli t4, t3, 2
    add t5, s2, t4
    sw t6, 0(t5)

    addi t1, t1, 1
    addi t3, t3, 1
    j copy_left_loop


copy_right_remain:
    bge t2, s6, next_pair

copy_right_loop:
    bge t2, s6, next_pair

    slli t4, t2, 2
    add t5, s0, t4
    lw t6, 0(t5)

    slli t4, t3, 2
    add t5, s2, t4
    sw t6, 0(t5)

    addi t2, t2, 1
    addi t3, t3, 1
    j copy_right_loop


next_pair:
    # left += 2*width
    slli t0, s3, 1
    add s4, s4, t0
    j pair_loop


copy_back:
    li s7, 0

copy_back_loop:
    bge s7, s1, next_width

    slli t0, s7, 2

    add t1, s2, t0
    lw t2, 0(t1)

    add t3, s0, t0
    sw t2, 0(t3)

    addi s7, s7, 1
    j copy_back_loop


next_width:
    slli s3, s3, 1     # width *= 2
    j outer_width_loop


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
    jr ra

