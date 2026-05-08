.data
.text
.globl main
main:
# This tests a generic case for jalr, where there is a zero offset added to the jalr
# It both tests the return address going into a register that will be updated and used again.
# It also test the address going to x0, which should be hardware enforced to zero and not save the address.
# Each of the addi after the jalr should be ignored, showing that the test worked.

auipc x1, 0 #use current PC
    nop
    nop
    nop
    nop
addi  x1, x1, 16 # Set PC to next auipc instruction
    nop
    nop
    nop
    nop
jalr  x2, 0(x1) #jump and save PC+4 to x2, zero offset
    nop
    nop
addi  x10, x0, 1 # Skipped

auipc x3, 0 # Set PC to current (won't change but acts as a nop for next operations)
    nop
    nop
    nop
    nop
addi  x3, x3, 16 # Set PC to the end label
    nop
    nop
    nop
    nop
jalr  x0, 0(x3) # Perform jalr to next address, but do not save PC+4, instead set to x0
    nop
    nop
addi  x11, x0, 1 #Skipped

end:

wfi