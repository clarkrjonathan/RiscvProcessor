.text

addi t0, zero, 5 #load 5 into t0

#calculate 5 * 31 for basic opperation
addi t1, zero, 1 #loading 1 to multiply 5 by 2
    nop
    nop
    nop
    nop
sll t2, t0, t1 # 5*2 in t2
    nop
    nop
    nop
    nop
add a0, t0, t2 # 5*2 + 5*1 = 5*3

addi t1, t1, 1 # incrementing value to shift t0 by
    nop
    nop
    nop
    nop
sll t2, t0, t1 # t2 = 5*4
    nop
    nop
    nop
    nop
add a0, a0, t2 # 5*4 + 5*3 = 5*7

addi t1, t1, 1 # increment t1 again
    nop
    nop
    nop
    nop
sll t2, t0, t1 # t2 = 5*8
    nop
    nop
    nop
    nop
add a0, a0, t2 # 5*8 + 5*7 = 5*15

addi t1, t1, 1 # t1++
    nop
    nop
    nop
    nop
sll t2, t0, t1 # t2 = 5*16
    nop
    nop
    nop
    nop
add a0, a0, t2 # 5*16 + 5*15 = 5*31


wfi