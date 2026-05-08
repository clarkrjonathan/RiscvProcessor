.data
    mem: .word 0, 0

.text
main:
    # Test ADDI
    addi x1, x0, 5        # x1 = 5
    addi x2, x0, 10       # x2 = 10

    # Test ADD
    add x3, x1, x2        # x3 = 15
    add x4, x1, x1        # x4 = 10

    # Load data segment address with lui instead of la
    lui x5, 0x10010        # x5 = 0x10010000

    # Test SW
    sw x3, 0(x5)          # mem[0x10010000] = 15
    sw x4, 4(x5)          # mem[0x10010004] = 10

    # Test LW
    lw x6, 0(x5)          # x6 should = 15
    lw x7, 4(x5)          # x7 should = 10

    # Confirm round trip
    add x8, x6, x7        # x8 = 25

    wfi
