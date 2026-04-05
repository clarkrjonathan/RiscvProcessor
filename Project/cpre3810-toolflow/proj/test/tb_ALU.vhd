-- ============================================================
-- tb_ALU.vhd
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

entity tb_ALU is
end tb_ALU;

architecture behavior of tb_ALU is

    component ALU is
        port(
            i_A      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            i_B      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            i_ALUCTL : in  std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
            o_Zero   : out std_logic;
            o_Output : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    signal s_A      : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_B      : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_ALUCTL : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
    signal s_Zero   : std_logic;
    signal s_Output : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- o_Zero=1 when output IS zero, o_Zero=0 when output is nonzero

    procedure check(
        op       : in string;
        got_out  : in std_logic_vector(DATA_WIDTH-1 downto 0);
        got_zero : in std_logic;
        exp_out  : in std_logic_vector(DATA_WIDTH-1 downto 0);
        exp_zero : in std_logic
    ) is
    begin
        if got_out = exp_out and got_zero = exp_zero then
            report "ALU " & op & " PASS" severity note;
        else
            if got_out /= exp_out then
                report "ALU " & op & " FAIL output: got 0x" & to_hstring(got_out)
                       & " expected 0x" & to_hstring(exp_out) severity error;
            end if;
            if got_zero /= exp_zero then
                report "ALU " & op & " FAIL zero flag: got " & std_logic'image(got_zero)
                       & " expected " & std_logic'image(exp_zero) severity error;
            end if;
        end if;
    end procedure;

begin

    UUT: ALU
        port map(
            i_A      => s_A,
            i_B      => s_B,
            i_ALUCTL => s_ALUCTL,
            o_Zero   => s_Zero,
            o_Output => s_Output
        );

    process
    begin
        -- =====================
        -- ADD: ALUSel=01, Sub=0
        -- concrete ALUCTL = 000001000
        -- =====================
        s_ALUCTL <= "000001000";

        s_A <= x"00000005"; s_B <= x"00000003"; wait for 10 ns;
        check("ADD 5+3",          s_Output, s_Zero, x"00000008", '0');

        s_A <= x"FFFFFFFF"; s_B <= x"00000001"; wait for 10 ns;
        check("ADD wraparound",   s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000000"; s_B <= x"00000000"; wait for 10 ns;
        check("ADD 0+0",          s_Output, s_Zero, x"00000000", '1');

        -- =====================
        -- SUB: ALUSel=01, Sub=1
        -- concrete ALUCTL = 000001010
        -- =====================
        s_ALUCTL <= "000001010";

        s_A <= x"00000008"; s_B <= x"00000003"; wait for 10 ns;
        check("SUB 8-3",          s_Output, s_Zero, x"00000005", '0');

        s_A <= x"00000005"; s_B <= x"00000005"; wait for 10 ns;
        check("SUB equal",        s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000000"; s_B <= x"00000001"; wait for 10 ns;
        check("SUB underflow",    s_Output, s_Zero, x"FFFFFFFF", '0');

        -- =====================
        -- SLL: ShiftType=00, ALUSel=00
        -- concrete ALUCTL = 000000000
        -- =====================
        s_ALUCTL <= "000000000";

        s_A <= x"00000001"; s_B <= x"00000001"; wait for 10 ns;
        check("SLL 1<<1",         s_Output, s_Zero, x"00000002", '0');

        s_A <= x"00000001"; s_B <= x"0000001F"; wait for 10 ns;
        check("SLL 1<<31",        s_Output, s_Zero, x"80000000", '0');

        s_A <= x"000000FF"; s_B <= x"00000008"; wait for 10 ns;
        check("SLL FF<<8",        s_Output, s_Zero, x"0000FF00", '0');

        s_A <= x"00000000"; s_B <= x"0000001F"; wait for 10 ns;
        check("SLL 0<<31",        s_Output, s_Zero, x"00000000", '1');

        -- =====================
        -- SRL: ShiftType=01, ALUSel=00
        -- concrete ALUCTL = 010000000
        -- =====================
        s_ALUCTL <= "010000000";

        s_A <= x"80000000"; s_B <= x"00000001"; wait for 10 ns;
        check("SRL 80000000>>1",  s_Output, s_Zero, x"40000000", '0');

        s_A <= x"FF000000"; s_B <= x"00000008"; wait for 10 ns;
        check("SRL FF000000>>8",  s_Output, s_Zero, x"00FF0000", '0');

        s_A <= x"80000000"; s_B <= x"0000001F"; wait for 10 ns;
        check("SRL >>31",         s_Output, s_Zero, x"00000001", '0');

        s_A <= x"00000001"; s_B <= x"00000001"; wait for 10 ns;
        check("SRL 1>>1 zero",    s_Output, s_Zero, x"00000000", '1');

        -- =====================
        -- SRA: ShiftType=10, ALUSel=00
        -- concrete ALUCTL = 100000000
        -- =====================
        s_ALUCTL <= "100000000";

        s_A <= x"80000000"; s_B <= x"00000001"; wait for 10 ns;
        check("SRA neg>>1",       s_Output, s_Zero, x"C0000000", '0');

        s_A <= x"80000000"; s_B <= x"0000001F"; wait for 10 ns;
        check("SRA neg>>31",      s_Output, s_Zero, x"FFFFFFFF", '0');

        s_A <= x"7FFFFFFF"; s_B <= x"00000001"; wait for 10 ns;
        check("SRA pos>>1",       s_Output, s_Zero, x"3FFFFFFF", '0');

        s_A <= x"00000001"; s_B <= x"00000001"; wait for 10 ns;
        check("SRA 1>>1 zero",    s_Output, s_Zero, x"00000000", '1');

        -- =====================
        -- SLT: ALUSel=11, USLT=0, Sub=1
        -- concrete ALUCTL = 000011010
        -- =====================
        s_ALUCTL <= "000011010";

        s_A <= x"00000001"; s_B <= x"00000002"; wait for 10 ns;
        check("SLT 1<2",          s_Output, s_Zero, x"00000001", '0');

        s_A <= x"00000002"; s_B <= x"00000001"; wait for 10 ns;
        check("SLT 2<1 false",    s_Output, s_Zero, x"00000000", '1');

        s_A <= x"FFFFFFFF"; s_B <= x"00000001"; wait for 10 ns;
        check("SLT -1<1",         s_Output, s_Zero, x"00000001", '0');

        s_A <= x"00000001"; s_B <= x"FFFFFFFF"; wait for 10 ns;
        check("SLT 1<-1 false",   s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000005"; s_B <= x"00000005"; wait for 10 ns;
        check("SLT equal false",  s_Output, s_Zero, x"00000000", '1');

        -- =====================
        -- SLTU: ALUSel=11, USLT=1, Sub=1
        -- concrete ALUCTL = 000011110
        -- =====================
        s_ALUCTL <= "000011110";

        s_A <= x"00000001"; s_B <= x"00000002"; wait for 10 ns;
        check("SLTU 1<2",         s_Output, s_Zero, x"00000001", '0');

        s_A <= x"FFFFFFFF"; s_B <= x"00000001"; wait for 10 ns;
        check("SLTU big<1 false", s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000001"; s_B <= x"FFFFFFFF"; wait for 10 ns;
        check("SLTU 1<big",       s_Output, s_Zero, x"00000001", '0');

        s_A <= x"00000005"; s_B <= x"00000005"; wait for 10 ns;
        check("SLTU equal false", s_Output, s_Zero, x"00000000", '1');

        -- =====================
        -- XOR: LogicOp=00, ALUSel=10
        -- concrete ALUCTL = 000010000
        -- =====================
        s_ALUCTL <= "000010000";

        s_A <= x"FF00FF00"; s_B <= x"0F0F0F0F"; wait for 10 ns;
        check("XOR mixed",        s_Output, s_Zero, x"F00FF00F", '0');

        s_A <= x"FFFFFFFF"; s_B <= x"FFFFFFFF"; wait for 10 ns;
        check("XOR same zero",    s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000000"; s_B <= x"FFFFFFFF"; wait for 10 ns;
        check("XOR with zero",    s_Output, s_Zero, x"FFFFFFFF", '0');

        -- =====================
        -- OR: LogicOp=10, ALUSel=10
        -- concrete ALUCTL = 001010000
        -- =====================
        s_ALUCTL <= "001010000";

        s_A <= x"FF00FF00"; s_B <= x"0F0F0F0F"; wait for 10 ns;
        check("OR mixed",         s_Output, s_Zero, x"FF0FFF0F", '0');

        s_A <= x"00000000"; s_B <= x"00000000"; wait for 10 ns;
        check("OR zeros",         s_Output, s_Zero, x"00000000", '1');

        s_A <= x"FFFFFFFF"; s_B <= x"00000000"; wait for 10 ns;
        check("OR with zero",     s_Output, s_Zero, x"FFFFFFFF", '0');

        -- =====================
        -- AND: LogicOp=01, ALUSel=10
        -- concrete ALUCTL = 000110000
        -- =====================
        s_ALUCTL <= "000110000";

        s_A <= x"FF00FF00"; s_B <= x"0F0F0F0F"; wait for 10 ns;
        check("AND mixed",        s_Output, s_Zero, x"0F000F00", '0');

        s_A <= x"FFFFFFFF"; s_B <= x"00000000"; wait for 10 ns;
        check("AND with zero",    s_Output, s_Zero, x"00000000", '1');

        s_A <= x"FFFFFFFF"; s_B <= x"FFFFFFFF"; wait for 10 ns;
        check("AND ones",         s_Output, s_Zero, x"FFFFFFFF", '0');

        -- =====================
        -- BEQ: ALUSel=01, Sub=1, InvZ=0
        -- subtracts A-B, zero=1 means equal
        -- concrete ALUCTL = 000001010
        -- =====================
        s_ALUCTL <= "000001010";

        s_A <= x"00000005"; s_B <= x"00000005"; wait for 10 ns;
        check("BEQ equal",        s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000005"; s_B <= x"00000006"; wait for 10 ns;
        check("BEQ not equal",    s_Output, s_Zero, x"FFFFFFFF", '0');

        -- =====================
        -- BNE: ALUSel=01, Sub=1, InvZ=1
        -- same output as BEQ, InvZ handled externally
        -- concrete ALUCTL = 000001011
        -- =====================
        s_ALUCTL <= "000001011";

        s_A <= x"00000005"; s_B <= x"00000005"; wait for 10 ns;
        check("BNE equal",        s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000005"; s_B <= x"00000006"; wait for 10 ns;
        check("BNE not equal",    s_Output, s_Zero, x"FFFFFFFF", '0');

        -- =====================
        -- BLT: ALUSel=11, USLT=0, Sub=1, InvZ=0
        -- SLT=1 when A<B signed, zero=0 means branch taken
        -- concrete ALUCTL = 000011010
        -- =====================
        s_ALUCTL <= "000011010";

        s_A <= x"00000001"; s_B <= x"00000002"; wait for 10 ns;
        check("BLT 1<2 taken",    s_Output, s_Zero, x"00000001", '0');

        s_A <= x"00000002"; s_B <= x"00000001"; wait for 10 ns;
        check("BLT 2<1 not taken",s_Output, s_Zero, x"00000000", '1');

        s_A <= x"FFFFFFFF"; s_B <= x"00000001"; wait for 10 ns;
        check("BLT -1<1 taken",   s_Output, s_Zero, x"00000001", '0');

        -- =====================
        -- BGE: ALUSel=11, USLT=0, Sub=1, InvZ=1
        -- SLT=0 when A>=B, InvZ handled externally
        -- concrete ALUCTL = 000011011
        -- =====================
        s_ALUCTL <= "000011011";

        s_A <= x"00000002"; s_B <= x"00000001"; wait for 10 ns;
        check("BGE 2>=1",         s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000001"; s_B <= x"00000001"; wait for 10 ns;
        check("BGE equal",        s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000001"; s_B <= x"00000002"; wait for 10 ns;
        check("BGE 1<2",          s_Output, s_Zero, x"00000001", '0');

        -- =====================
        -- BLTU: ALUSel=11, USLT=1, Sub=1, InvZ=0
        -- concrete ALUCTL = 000011110
        -- =====================
        s_ALUCTL <= "000011110";

        s_A <= x"00000001"; s_B <= x"FFFFFFFF"; wait for 10 ns;
        check("BLTU 1<big taken", s_Output, s_Zero, x"00000001", '0');

        s_A <= x"FFFFFFFF"; s_B <= x"00000001"; wait for 10 ns;
        check("BLTU big>=1",      s_Output, s_Zero, x"00000000", '1');

        -- =====================
        -- BGEU: ALUSel=11, USLT=1, Sub=1, InvZ=1
        -- concrete ALUCTL = 000011111
        -- =====================
        s_ALUCTL <= "000011111";

        s_A <= x"FFFFFFFF"; s_B <= x"00000001"; wait for 10 ns;
        check("BGEU big>=1",      s_Output, s_Zero, x"00000000", '1');

        s_A <= x"00000001"; s_B <= x"FFFFFFFF"; wait for 10 ns;
        check("BGEU 1<big",       s_Output, s_Zero, x"00000001", '0');

        report "ALU testbench complete" severity note;
        wait;

    end process;

end behavior;
