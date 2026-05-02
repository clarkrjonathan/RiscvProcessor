#Test 3, check 0x10101010... xor 0x01010101.. = 0xFFFFFFFF
# This test checks that xoring every bit givves 0xFFFFFFFF as an output.

lui  a1, 0xAAAAB
    nop
    nop
    nop
    nop
addi a1, a1, -1366

lui  a2, 0x55555
    nop
    nop
    nop
    nop
addi a2, a2, 1365

    nop
    nop
    nop
    nop
xor  t2, a1, a2

wfi