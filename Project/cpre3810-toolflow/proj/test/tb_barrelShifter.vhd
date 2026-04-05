-- ============================================================
-- tb_barrelShifter.vhd  (condensed from earlier full version)
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_barrelShifter is
end tb_barrelShifter;

architecture behavior of tb_barrelShifter is

    component barrelShifter is
        port(
            i_Data      : in  std_logic_vector(31 downto 0);
            i_ShiftAmt  : in  std_logic_vector(4 downto 0);
            i_ShiftType : in  std_logic_vector(1 downto 0);
            o_Result    : out std_logic_vector(31 downto 0)
        );
    end component;

    signal s_Data      : std_logic_vector(31 downto 0);
    signal s_ShiftAmt  : std_logic_vector(4 downto 0);
    signal s_ShiftType : std_logic_vector(1 downto 0);
    signal s_Result    : std_logic_vector(31 downto 0);

    procedure check(
        name     : in string;
        got      : in std_logic_vector(31 downto 0);
        expected : in std_logic_vector(31 downto 0)
    ) is
    begin
        if got = expected then
            report "barrelShifter " & name & " PASS" severity note;
        else
            report "barrelShifter " & name & " FAIL: got 0x" & to_hstring(got)
                   & " expected 0x" & to_hstring(expected) severity error;
        end if;
    end procedure;

begin

    UUT: barrelShifter
        port map(
            i_Data      => s_Data,
            i_ShiftAmt  => s_ShiftAmt,
            i_ShiftType => s_ShiftType,
            o_Result    => s_Result
        );

    process
    begin
        -- SLL (00)
        s_ShiftType <= "00";
        s_Data <= x"000000FF"; s_ShiftAmt <= "00000"; wait for 10 ns;
        check("SLL 0 ", s_Result, x"000000FF");
        s_Data <= x"000000FF"; s_ShiftAmt <= "00001"; wait for 10 ns;
        check("SLL 1 ", s_Result, x"000001FE");
        s_Data <= x"000000FF"; s_ShiftAmt <= "01000"; wait for 10 ns;
        check("SLL 8 ", s_Result, x"0000FF00");
        s_Data <= x"000000FF"; s_ShiftAmt <= "10000"; wait for 10 ns;
        check("SLL 16", s_Result, x"00FF0000");
        s_Data <= x"000000FF"; s_ShiftAmt <= "11000"; wait for 10 ns;
        check("SLL 24", s_Result, x"FF000000");
        s_Data <= x"00000001"; s_ShiftAmt <= "11111"; wait for 10 ns;
        check("SLL 31", s_Result, x"80000000");
        s_Data <= x"80000001"; s_ShiftAmt <= "00001"; wait for 10 ns;
        check("SLL MSB lost", s_Result, x"00000002");

        -- SRL (01)
        s_ShiftType <= "01";
        s_Data <= x"FF000000"; s_ShiftAmt <= "00000"; wait for 10 ns;
        check("SRL 0 ", s_Result, x"FF000000");
        s_Data <= x"FF000000"; s_ShiftAmt <= "00001"; wait for 10 ns;
        check("SRL 1 ", s_Result, x"7F800000");
        s_Data <= x"FF000000"; s_ShiftAmt <= "01000"; wait for 10 ns;
        check("SRL 8 ", s_Result, x"00FF0000");
        s_Data <= x"FF000000"; s_ShiftAmt <= "10000"; wait for 10 ns;
        check("SRL 16", s_Result, x"0000FF00");
        s_Data <= x"80000000"; s_ShiftAmt <= "11111"; wait for 10 ns;
        check("SRL 31", s_Result, x"00000001");
        s_Data <= x"80000000"; s_ShiftAmt <= "00001"; wait for 10 ns;
        check("SRL zero fill", s_Result, x"40000000");

        -- SRA (10)
        s_ShiftType <= "10";
        s_Data <= x"7FFFFFFF"; s_ShiftAmt <= "00001"; wait for 10 ns;
        check("SRA pos 1 ", s_Result, x"3FFFFFFF");
        s_Data <= x"80000000"; s_ShiftAmt <= "00001"; wait for 10 ns;
        check("SRA neg 1 ", s_Result, x"C0000000");
        s_Data <= x"FF000000"; s_ShiftAmt <= "01000"; wait for 10 ns;
        check("SRA neg 8 ", s_Result, x"FFFF0000");
        s_Data <= x"80000000"; s_ShiftAmt <= "11111"; wait for 10 ns;
        check("SRA neg 31", s_Result, x"FFFFFFFF");
        s_Data <= x"7FFFFFFF"; s_ShiftAmt <= "11111"; wait for 10 ns;
        check("SRA pos 31", s_Result, x"00000000");

        -- edge cases
        s_ShiftType <= "00";
        s_Data <= x"00000000"; s_ShiftAmt <= "11111"; wait for 10 ns;
        check("SLL all zeros", s_Result, x"00000000");
        s_ShiftType <= "01";
        wait for 10 ns;
        check("SRL all zeros", s_Result, x"00000000");
        s_ShiftType <= "10";
        wait for 10 ns;
        check("SRA all zeros", s_Result, x"00000000");
        s_Data <= x"FFFFFFFF";
        s_ShiftType <= "00"; wait for 10 ns;
        check("SLL all ones 31", s_Result, x"80000000");
        s_ShiftType <= "01"; wait for 10 ns;
        check("SRL all ones 31", s_Result, x"00000001");
        s_ShiftType <= "10"; wait for 10 ns;
        check("SRA all ones 31", s_Result, x"FFFFFFFF");

        report "tb_barrelShifter complete" severity note;
        wait;
    end process;

end behavior;
