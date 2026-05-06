#check each 2 bit combo
lui x1, 0x01230
    nop
    nop
    nop
    nop
addi x1, x1, 0x123
lui x2, 0x12302
    nop
    nop
    nop
    nop
addi x2, x2, 0x301
    nop
    nop
    nop
    nop
add x3, x1, x2
add x4, x2, x1

#check that we are communitive
lui x2, 0x01230
    nop
    nop
    nop
    nop
addi x2, x2, 0x123
lui x1, 0x12302
    nop
    nop
    nop
    nop
addi x1, x1, 0x301
    nop
    nop
    nop
    nop
add x5, x1, x2
add x6, x2, x1

#check carry apacity of every bit
addi x1, x0, 0x1
addi x2, x0, 0x1
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x2
addi x2, x0, 0x2
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x4
addi x2, x0, 0x4
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x8
addi x2, x0, 0x8
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x10
addi x2, x0, 0x10
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x20
addi x2, x0, 0x20
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x40
addi x2, x0, 0x40
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x80
addi x2, x0, 0x80
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x100
addi x2, x0, 0x100
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x200
addi x2, x0, 0x200
    nop
    nop
    nop
    nop
add x1, x2, x3

addi x1, x0, 0x400
addi x2, x0, 0x400
    nop
    nop
    nop
    nop
add x1, x2, x3

lui x1, 0x1
    nop
    nop
    nop
    nop
addi x1, x1 -1
lui x2, 0x1
    nop
    nop
    nop
    nop
addi x2, x2 -1
    nop
    nop
    nop
    nop
add x1, x2, x3

lui x1, 0x10
lui x2, 0x10
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x20
lui x2, 0x20
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x40
lui x2, 0x40
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x80
lui x2, 0x80
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x100
lui x2, 0x100
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x200
lui x2, 0x200
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x400
lui x2, 0x400
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x800
lui x2, 0x800
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x1000
lui x2, 0x1000
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x2000
lui x2, 0x2000
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x4000
lui x2, 0x4000
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x8000
lui x2, 0x8000
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x10000
lui x2, 0x10000
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x20000
lui x2, 0x20000
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x40000
lui x2, 0x40000
    nop
    nop
    nop
    nop
add x3, x1, x2

lui x1, 0x80000
lui x2, 0x80000
    nop
    nop
    nop
    nop
add x3, x1, x2
wfi