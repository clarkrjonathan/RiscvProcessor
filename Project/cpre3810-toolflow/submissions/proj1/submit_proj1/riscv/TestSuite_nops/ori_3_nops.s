.data
result: .word 0      # to store the result

.text
.globl main
main:
    lasw t2, result
    li t0, 0x55       # t0 = 0x55
    nop
    nop
    nop
    nop
    ori t1, t0, 0x00  # t1 = t0 | 0x00 → 0x55

    nop
    nop
    nop
    nop
    sw t1, 0(t2)   # store result
    wfi                # end / wait for interrupt

