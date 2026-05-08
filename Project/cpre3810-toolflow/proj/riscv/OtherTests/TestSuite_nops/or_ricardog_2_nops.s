.data

.text
.global main

main:

#Initalizing
lui t1, 0xfffff
addi t2, t2, 0x7ff
    nop
    nop
    nop
    nop
addi t2, t2, 0x7f0
    nop
    nop
    nop
    nop
addi t2, t2, 0x10


# Testing 

# Start test

#Testing all bits can be bitwise OR. 
    nop
    nop
    nop
    nop
or t3, t1, t2	

end:

wfi