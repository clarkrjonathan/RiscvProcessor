.text
    .globl main
main:

    # test 1 

    lui  x1, 0xF0000        # x1 = 0xF0000000

    addi x5, x0, 32         
    nop
    nop
    nop
    nop
    sra  x10, x1, x5        #0xF0000000

    addi x5, x0, 33         
    nop
    nop
    nop
    nop
    sra  x11, x1, x5        # expect 0xF8000000

    addi x5, x0, -31        
    nop
    nop
    nop
    nop
    sra  x12, x1, x5        # expect 0xF8000000

    addi x5, x0, 255        
    nop
    nop
    nop
    nop
    sra  x13, x1, x5        # expect 0xFFFFFFFF

    addi x5, x0, -1        
    nop
    nop
    nop
    nop
    sra  x14, x1, x5        # expect 0xFFFFFFFF


    # test 2

    lui  x2, 0x40000        # x2 = 0x40000000

    addi x5, x0, 32         
    nop
    nop
    nop
    nop
    sra  x15, x2, x5        # expect 0x40000000

    addi x5, x0, 255       
    nop
    nop
    nop
    nop
    sra  x16, x2, x5        # expect 0x00000000


    addi x0, x0, 0
wfi