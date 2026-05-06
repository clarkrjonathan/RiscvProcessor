.text
.globl main

    jal x0, main            # force entry point

# ----------------------------------------------------------
# fib(n): returns fib(n) in a0
# ----------------------------------------------------------
fib:
    # base case: if n <= 1, return n unchanged
    addi t0, x0, 2
    blt  a0, t0, fib_base

    # save frame
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s0, 4(sp)
    sw   s1, 0(sp)

    addi s0, a0, 0          # s0 = n

    # fib(n-1)
    addi a0, s0, -1
    jal  ra, fib
    addi s1, a0, 0          # s1 = fib(n-1)

    # fib(n-2)
    addi a0, s0, -2
    jal  ra, fib
                            # a0 = fib(n-2)

    add  a0, s1, a0         # a0 = fib(n-1) + fib(n-2)

    lw   ra, 8(sp)
    lw   s0, 4(sp)
    lw   s1, 0(sp)
    addi sp, sp, 12
    jalr x0, ra, 0

fib_base:
    jalr x0, ra, 0

# ----------------------------------------------------------
# main
# ----------------------------------------------------------
main:
    addi sp, sp, -4
    sw   ra, 0(sp)

    addi a0, x0, 6          # n = 6
    jal  ra, fib            # call fib(6), result in a0

    lw   ra, 0(sp)
    addi sp, sp, 4
    wfi
