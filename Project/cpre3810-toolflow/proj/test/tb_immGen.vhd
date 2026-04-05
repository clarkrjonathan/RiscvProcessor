-- ============================================================
-- tb_immGen.vhd
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_immGen is
end tb_immGen;

architecture behavior of tb_immGen is

    component immGen is
        port(
            i_Inst : in  std_logic_vector(31 downto 0);
            o_Imm  : out std_logic_vector(31 downto 0)
        );
    end component;

    signal s_Inst : std_logic_vector(31 downto 0);
    signal s_Imm  : std_logic_vector(31 downto 0);

    procedure check(
        name     : in string;
        got      : in std_logic_vector(31 downto 0);
        expected : in std_logic_vector(31 downto 0)
    ) is
    begin
        if got = expected then
            report "immGen " & name & " PASS" severity note;
        else
            report "immGen " & name & " FAIL: got 0x" & to_hstring(got)
                   & " expected 0x" & to_hstring(expected) severity error;
        end if;
    end procedure;

begin

    UUT: immGen
        port map(
            i_Inst => s_Inst,
            o_Imm  => s_Imm
        );

    process
    begin
        -- I-type: addi x1, x0, 5 = imm=5
        s_Inst <= x"00500093"; wait for 10 ns;
        check("ADDI +5   ", s_Imm, x"00000005");

        -- I-type negative: addi x1, x0, -4 = imm=-4
        s_Inst <= x"FFC00093"; wait for 10 ns;
        check("ADDI -4   ", s_Imm, x"FFFFFFFC");

        -- I-type max positive: imm=2047
        s_Inst <= x"7FF00093"; wait for 10 ns;
        check("ADDI +2047", s_Imm, x"000007FF");

        -- I-type max negative: imm=-2048
        s_Inst <= x"80000093"; wait for 10 ns;
        check("ADDI -2048", s_Imm, x"FFFFF800");

        -- LW: lw x1, 4(x0) = imm=4
        s_Inst <= x"00402083"; wait for 10 ns;
        check("LW   +4   ", s_Imm, x"00000004");

        -- LW negative offset: lw x1, -4(x0) = imm=-4
        s_Inst <= x"FFC02083"; wait for 10 ns;
        check("LW   -4   ", s_Imm, x"FFFFFFFC");

        -- S-type: sw x1, 0(x0) = imm=0
        s_Inst <= x"00102023"; wait for 10 ns;
        check("SW   0    ", s_Imm, x"00000000");

        -- S-type: sw x1, 4(x0) = imm=4
        s_Inst <= x"00102223"; wait for 10 ns;
        check("SW   4    ", s_Imm, x"00000004");

        -- S-type negative: sw x1, -4(x0) = imm=-4
        s_Inst <= x"FE102E23"; wait for 10 ns;
        check("SW   -4   ", s_Imm, x"FFFFFFFC");

        -- LUI: lui x1, 1 = imm=0x00001000
        s_Inst <= x"000010B7"; wait for 10 ns;
        check("LUI  1    ", s_Imm, x"00001000");

        -- LUI large: lui x1, 0xFFFFF = imm=0xFFFFF000
        s_Inst <= x"FFFFF0B7"; wait for 10 ns;
        check("LUI  max  ", s_Imm, x"FFFFF000");

        -- AUIPC: same immediate encoding as LUI
        s_Inst <= x"00001097"; wait for 10 ns;
        check("AUIPC 1   ", s_Imm, x"00001000");

        -- JAL: jal x0, 8 = imm=8
        s_Inst <= x"0080006F"; wait for 10 ns;
        check("JAL  8    ", s_Imm, x"00000008");

        -- JAL: jal x1, 20 = imm=20
        s_Inst <= x"014000EF"; wait for 10 ns;
        check("JAL  20   ", s_Imm, x"00000014");

        -- B-type: beq x0, x0, 8 = imm=8
        s_Inst <= x"00000463"; wait for 10 ns;
        check("BEQ  8    ", s_Imm, x"00000008");

        -- B-type negative: branch back -4
        s_Inst <= x"FE000EE3"; wait for 10 ns;
        check("BEQ  -4   ", s_Imm, x"FFFFFFFC");

        report "tb_immGen complete" severity note;
        wait;
    end process;

end behavior;


-- ============================================================
-- tb_logicUnit.vhd
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_logicUnit is
end tb_logicUnit;

architecture behavior of tb_logicUnit is

    component logicUnit is
        generic(N : integer := 32);
        port(
            i_A   : in  std_logic_vector(31 downto 0);
            i_B   : in  std_logic_vector(31 downto 0);
            i_CTL : in  std_logic_vector(1 downto 0);
            o_O   : out std_logic_vector(31 downto 0)
        );
    end component;

    signal s_A   : std_logic_vector(31 downto 0);
    signal s_B   : std_logic_vector(31 downto 0);
    signal s_CTL : std_logic_vector(1 downto 0);
    signal s_O   : std_logic_vector(31 downto 0);

    procedure check(
        name     : in string;
        got      : in std_logic_vector(31 downto 0);
        expected : in std_logic_vector(31 downto 0)
    ) is
    begin
        if got = expected then
            report "logicUnit " & name & " PASS" severity note;
        else
            report "logicUnit " & name & " FAIL: got 0x" & to_hstring(got)
                   & " expected 0x" & to_hstring(expected) severity error;
        end if;
    end procedure;

begin

    UUT: logicUnit
        generic map(N => 32)
        port map(
            i_A   => s_A,
            i_B   => s_B,
            i_CTL => s_CTL,
            o_O   => s_O
        );

    process
    begin
        s_A <= x"FF00FF00";
        s_B <= x"0F0F0F0F";

        -- XOR (00)
        s_CTL <= "00"; wait for 10 ns;
        check("XOR mixed   ", s_O, x"F00FF00F");
        s_A <= x"FFFFFFFF"; s_B <= x"FFFFFFFF";
        s_CTL <= "00"; wait for 10 ns;
        check("XOR same    ", s_O, x"00000000");
        s_A <= x"00000000"; s_B <= x"FFFFFFFF";
        s_CTL <= "00"; wait for 10 ns;
        check("XOR zero    ", s_O, x"FFFFFFFF");

        -- AND (01)
        s_A <= x"FF00FF00"; s_B <= x"0F0F0F0F";
        s_CTL <= "01"; wait for 10 ns;
        check("AND mixed   ", s_O, x"0F000F00");
        s_A <= x"FFFFFFFF"; s_B <= x"00000000";
        s_CTL <= "01"; wait for 10 ns;
        check("AND zero    ", s_O, x"00000000");
        s_A <= x"FFFFFFFF"; s_B <= x"FFFFFFFF";
        s_CTL <= "01"; wait for 10 ns;
        check("AND ones    ", s_O, x"FFFFFFFF");

        -- OR (10)
        s_A <= x"FF00FF00"; s_B <= x"0F0F0F0F";
        s_CTL <= "10"; wait for 10 ns;
        check("OR  mixed   ", s_O, x"FF0FFF0F");
        s_A <= x"00000000"; s_B <= x"00000000";
        s_CTL <= "10"; wait for 10 ns;
        check("OR  zeros   ", s_O, x"00000000");
        s_A <= x"FFFFFFFF"; s_B <= x"00000000";
        s_CTL <= "10"; wait for 10 ns;
        check("OR  with 0  ", s_O, x"FFFFFFFF");
        s_A <= x"A0A0A0A0"; s_B <= x"0A0A0A0A";
        s_CTL <= "10"; wait for 10 ns;
        check("OR  no overlap", s_O, x"AAAAAAAA");

        report "tb_logicUnit complete" severity note;
        wait;
    end process;

end behavior;
