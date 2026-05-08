# Author: Abdelrahman Ali
# NetID: akali@iastate.edu
# Test: 1
# Instruction under test: ADDI
#
# This test checks basic addition with positive immediates.
# It verifies that ADDI correctly adds a small positive value.

addi x1, x0, 5       # x1 = 0 + 5  -> expect 5
    nop
    nop
    nop
    nop
addi x2, x1, 3       # x2 = 5 + 3  -> expect 8
    nop
    nop
    nop
    nop
addi x3, x2, 7       # x3 = 8 + 7  -> expect 15

wfi