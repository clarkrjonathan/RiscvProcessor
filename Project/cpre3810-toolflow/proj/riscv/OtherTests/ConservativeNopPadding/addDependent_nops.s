#Check that our software scheduling is working

.text
addi x1,x0, 10
    nop
    nop
    nop
    nop
add x2, x1, x1
add x3, x1, x0
    nop
    nop
    nop
add x4, x2, x1
wfi
