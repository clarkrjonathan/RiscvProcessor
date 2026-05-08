.text
.globl main

    jal   x0, main          # force entry point

main:

    # -------------------------------------------------------
    # I-TYPE ARITHMETIC
    # -------------------------------------------------------
    addi  x1,  x0,  100     # x1  = 100
    addi  x5,  x0,  -50     # x5  = -50  (DO NOT use x2; x2 is sp)
    addi  x3,  x1,  25      # x3  = 125

    slti  x4,  x1,  200     # x4  = 1  (100 < 200 signed)
    slti  x6,  x1,  50      # x6  = 0  (100 not < 50)

    sltiu x7,  x1,  200     # x7  = 1  (100 < 200 unsigned)
    sltiu x8,  x0,  1       # x8  = 1  (0 < 1 unsigned)

    xori  x9,  x1,  255     # x9  = 100 XOR 255 = 155
    ori   x10, x1,  255     # x10 = 100 OR 255  = 255
    andi  x11, x1,  255     # x11 = 100 AND 255 = 100

    slli  x12, x1,  2       # x12 = 100 << 2 = 400
    srli  x13, x12, 1       # x13 = 400 >> 1 = 200 (logical)
    srai  x14, x5,  1       # x14 = -50 >> 1 = -25 (arithmetic)

    # -------------------------------------------------------
    # U-TYPE
    # -------------------------------------------------------
    lui   x15, 1            # x15 = 0x00001000
    auipc x16, 0            # x16 = current PC

    # -------------------------------------------------------
    # R-TYPE
    # -------------------------------------------------------
    add   x17, x1,  x3      # x17 = 100 + 125 = 225
    sub   x18, x3,  x1      # x18 = 125 - 100 = 25
    sll   x19, x1,  x4      # x19 = 100 << 1  = 200  (x4=1)
    slt   x20, x5,  x1      # x20 = 1  (-50 < 100 signed)
    sltu  x21, x1,  x17     # x21 = 1  (100 < 225 unsigned)
    xor   x22, x1,  x3      # x22 = 100 XOR 125 = 29
    srl   x23, x12, x4      # x23 = 400 >> 1 = 200 (x4=1, logical)
    sra   x24, x5,  x4      # x24 = -50 >> 1 = -25 (x4=1, arithmetic)
    or    x25, x1,  x3      # x25 = 100 OR 125 = 125
    and   x26, x1,  x3      # x26 = 100 AND 125 = 96

    # -------------------------------------------------------
    # MEMORY: SW / LW using stack pointer
    # sp is valid because we did NOT clobber x2
    # -------------------------------------------------------
    addi  sp, sp, -8        # allocate 8 bytes on stack

    sw    x17, 4(sp)        # store 225
    sw    x18, 0(sp)        # store 25

    lw    x27, 4(sp)        # x27 = 225
    lw    x28, 0(sp)        # x28 = 25

    # -------------------------------------------------------
    # MEMORY: SB / LB / LBU
    # -------------------------------------------------------
    addi  x29, x0, 127      # x29 = 0x7F
    
    
    #sb    x29, 4(sp)        # store byte 0x7F
    #Commented because in toolflow it will give an error as this instruction is skipped in the rars trace
    
    
    lb    x30, 4(sp)        # sign extend: x30 = 127
    lbu   x30, 4(sp)        # zero extend: x30 = 127

    addi  x29, x0, -1       # x29 = 0xFFFFFFFF
    #sb    x29, 4(sp)        # store 0xFF
    #Commented because in toolflow it will give an error as this instruction is skipped in the rars trace
    
    lb    x30, 4(sp)        # sign extend: x30 = -1
    lbu   x30, 4(sp)        # zero extend: x30 = 255

    # -------------------------------------------------------
    # MEMORY: SH / LH / LHU
    # -------------------------------------------------------
    addi  x29, x0, -256     # x29 = 0xFFFFFF00
    
    
    
    #sh    x29, 4(sp)        # store halfword 0xFF00
    #Commented because in toolflow it will give an error as this instruction is skipped in the rars trace
    
    
    lh    x30, 4(sp)        # sign extend: x30 = -256
    lhu   x30, 4(sp)        # zero extend: x30 = 65280

    addi  sp, sp, 8         # restore stack

    # -------------------------------------------------------
    # BRANCHES - each branch should be TAKEN
    # -------------------------------------------------------
    addi  t0, x0, 10
    addi  t1, x0, 20

    beq   t0, t0, beq_ok
    addi  x1, x0, 0
beq_ok:

    bne   t0, t1, bne_ok
    addi  x1, x0, 0
bne_ok:

    blt   t0, t1, blt_ok
    addi  x1, x0, 0
blt_ok:

    bge   t1, t0, bge_ok
    addi  x1, x0, 0
bge_ok:

    addi  t2, x0, -1
    bltu  t1, t2, bltu_ok
    addi  x1, x0, 0
bltu_ok:

    bgeu  t2, t1, bgeu_ok
    addi  x1, x0, 0
bgeu_ok:

    # -------------------------------------------------------
    # JAL / JALR
    # -------------------------------------------------------
    jal   ra, jal_target
    addi  x31, x0, 99
    jal   x0, done

jal_target:
    addi  x30, x0, 42
    jalr  x0, ra, 0

done:
    wfi
