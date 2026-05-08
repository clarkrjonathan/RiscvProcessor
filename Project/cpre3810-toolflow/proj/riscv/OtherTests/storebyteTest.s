.data
mem: .word 0xAAAAAAAA

.text
.globl main

main:
    # t0 = address of mem
    lui t0, %hi(mem)
    addi t0, t0, %lo(mem)

    # t1 = 0x11
    addi t1, x0, 0x11
    sb t1, 0(t0)

    # t1 = 0x22
    addi t1, x0, 0x22
    sb t1, 1(t0)

    # t1 = 0x33
    addi t1, x0, 0x33
    sb t1, 2(t0)

    # t1 = 0x44
    addi t1, x0, 0x44
    sb t1, 3(t0)

    # load final 32-bit word into t2
    lw t2, 0(t0)

    wfi
