.data

.text
.global main

main:

#Initalizing
addi t1, t1, 5



# Testing 

# Start test

    nop
    nop
    nop
    nop
or t2, t1, t1	#Verify using OR instruction on the same register does not change its value. 

end:

wfi