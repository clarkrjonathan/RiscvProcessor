# Test 2: Verifying branch is NOT taken when registers are unequal.
# Justification: Tests the 'false' condition. Prevents 'always-branch' 
# hardware bugs. Uses a small immediate to ensure bit-wise comparison work


addi x1, x0, 5
    nop
    nop
    nop
    nop
beq x1, x0, fail # if 5 == 0 (false), branch to fail 
    nop
    nop
addi, x2, x0, 1 # WANT TO BE HERE!
beq x0, x0, end 
    nop
    nop

fail: 
addi x2, x0, 2 # DONT WANT TO BE HERE! 

end: 
addi x3, x0, 1


wfi