# blossom_algo.s
# A simple algorithmic loop that scales and accumulates values.
# Starts memory addressing at 0x10010000 and ends with wfi.
.text
.globl _start

_start:

lui x10, 0x10010 # Load base memory address 0x10010000

addi x11, x0, 3 # Initialize loop counter to 3
add x12, x0, x0 # Initialize accumulator 1 to 0
add x16, x0, x0 # Initialize accumulator 2 to 0
add x17, x0, x0 # Initialize dummy register 1
add x18, x0, x0 # Initialize dummy register 2

sw x0, 0(x10) # Zero-init array memory used by blossom
sw x0, 4(x10)
sw x0, 8(x10)



loop:

lw x13, 0(x10) # Load data from array
addi x11, x11, -1 # Decrement loop counter
nop
nop
slli x14, x13, 2 # Shift data left by 2 (multiply by 4)
nop
nop


addi x10, x10, 4 # Increment memory pointer by 4 bytes
add x12, x12, x14 # Add shifted data to accumulator 1

nop
nop

add x16, x16, x10 # Add updated pointer to accumulator 2
bne x11, x0, loop # Branch to loop if counter is not zero
nop
nop

add x18, x18, x17 # Final independent dummy operation
wfi # Wait for interrupt (Halt)