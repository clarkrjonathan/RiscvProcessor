.text
.globl main

main:

    # Test 2: andi with -1 then register AND combining
    # Detects decoding errors of immediate bit patterns and ensures andi composes correctly with register logical/arithmetic operations.
    addi x1,x0,-1         # x1 = -1 (all ones)
    nop
    nop
    nop
    nop
    andi x2,x1,0x555      # x2 = 0x555 (pattern)

    lui x3,0x00FF0        # x3 = 0x00FF0000
    nop
    nop
    nop
    nop
    addi x3,x3,0x0FF      # x3 = 0x00FF00FF

    nop
    nop
    nop
    nop
    andi x4,x3,0xFF       # x4 = 0xFF
    nop
    nop
    nop
    nop
    and x5,x2,x4          # x5 = x2 & x4 -> 0x55
    nop
    nop
    nop
    nop
    add x6,x5,x4          # x6 = x5 + x4

    addi x0,x0,0          # no-op end

wfi