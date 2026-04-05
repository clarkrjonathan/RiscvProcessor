-- tb_byteMd.vhd
-- Updated to include i_ByteAddr port matching the current byteMd implementation.
-- i_ByteAddr = bits [1:0] of the memory address, selects which byte/halfword
-- within the returned word is the target for sub-word operations.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_byteMd is
end tb_byteMd;

architecture behavior of tb_byteMd is

    component byteMd is
        port(
            i_ByteOp   : in  std_logic_vector(3 downto 0);
            i_ByteAddr : in  std_logic_vector(1 downto 0);
            i_mem      : in  std_logic_vector(31 downto 0);
            i_RS2      : in  std_logic_vector(31 downto 0);
            o_ByteOut  : out std_logic_vector(31 downto 0)
        );
    end component;

    signal s_ByteOp   : std_logic_vector(3 downto 0);
    signal s_ByteAddr : std_logic_vector(1 downto 0);
    signal s_mem      : std_logic_vector(31 downto 0);
    signal s_RS2      : std_logic_vector(31 downto 0);
    signal s_ByteOut  : std_logic_vector(31 downto 0);

    procedure check(
        name     : in string;
        got      : in std_logic_vector(31 downto 0);
        expected : in std_logic_vector(31 downto 0)
    ) is
    begin
        if got = expected then
            report "byteMd " & name & " PASS" severity note;
        else
            report "byteMd " & name & " FAIL: got 0x" & to_hstring(got)
                   & " expected 0x" & to_hstring(expected) severity error;
        end if;
    end procedure;

begin

    UUT: byteMd
        port map(
            i_ByteOp   => s_ByteOp,
            i_ByteAddr => s_ByteAddr,
            i_mem      => s_mem,
            i_RS2      => s_RS2,
            o_ByteOut  => s_ByteOut
        );

    process
    begin

        -- =====================================================================
        -- STORE OPERATIONS (ByteOp bit3=0)
        -- sb (0000): replace target byte with RS2[7:0], keep rest from mem
        -- sw (0100): replace entire word with RS2
        -- =====================================================================

        -- SW: full word store, ByteAddr irrelevant
        s_mem      <= x"AABBCCDD";
        s_RS2      <= x"11223344";
        s_ByteOp   <= "0100"; s_ByteAddr <= "00"; wait for 10 ns;
        check("sw       ", s_ByteOut, x"11223344");

        -- SB at byte offset 0: replace bits [7:0]
        s_mem      <= x"AABBCCDD";
        s_RS2      <= x"11223344";
        s_ByteOp   <= "0000"; s_ByteAddr <= "00"; wait for 10 ns;
        check("sb off=0 ", s_ByteOut, x"AABBCC44");

        -- SB at byte offset 1: replace bits [15:8]
        s_ByteOp   <= "0000"; s_ByteAddr <= "01"; wait for 10 ns;
        check("sb off=1 ", s_ByteOut, x"AABB44DD");

        -- SB at byte offset 2: replace bits [23:16]
        s_ByteOp   <= "0000"; s_ByteAddr <= "10"; wait for 10 ns;
        check("sb off=2 ", s_ByteOut, x"AA44CCDD");

        -- SB at byte offset 3: replace bits [31:24]
        s_ByteOp   <= "0000"; s_ByteAddr <= "11"; wait for 10 ns;
        check("sb off=3 ", s_ByteOut, x"44BBCCDD");

        -- =====================================================================
        -- LOAD OPERATIONS (ByteOp bit3=1)
        -- lb  (1000): sign extend selected byte to 32 bits
        -- lbu (1001): zero extend selected byte to 32 bits
        -- lh  (1010): sign extend selected halfword to 32 bits
        -- lhu (1011): zero extend selected halfword to 32 bits
        -- lw  (1100): pass full word
        -- =====================================================================

        s_mem <= x"AABBCCDD";

        -- LW: full word, ByteAddr irrelevant
        s_ByteOp <= "1100"; s_ByteAddr <= "00"; wait for 10 ns;
        check("lw       ", s_ByteOut, x"AABBCCDD");

        -- LBU byte 0 (0xDD): zero extend -> 0x000000DD
        s_ByteOp <= "1001"; s_ByteAddr <= "00"; wait for 10 ns;
        check("lbu off=0", s_ByteOut, x"000000DD");

        -- LBU byte 1 (0xCC): zero extend -> 0x000000CC
        s_ByteOp <= "1001"; s_ByteAddr <= "01"; wait for 10 ns;
        check("lbu off=1", s_ByteOut, x"000000CC");

        -- LBU byte 2 (0xBB): zero extend -> 0x000000BB
        s_ByteOp <= "1001"; s_ByteAddr <= "10"; wait for 10 ns;
        check("lbu off=2", s_ByteOut, x"000000BB");

        -- LBU byte 3 (0xAA): zero extend -> 0x000000AA
        s_ByteOp <= "1001"; s_ByteAddr <= "11"; wait for 10 ns;
        check("lbu off=3", s_ByteOut, x"000000AA");

        -- LB byte 0 (0xDD = 1101_1101): sign bit=1 -> sign extend -> 0xFFFFFFDD
        s_ByteOp <= "1000"; s_ByteAddr <= "00"; wait for 10 ns;
        check("lb  neg0 ", s_ByteOut, x"FFFFFFDD");

        -- LB byte 3 (0xAA = 1010_1010): sign bit=1 -> 0xFFFFFFAA
        s_ByteOp <= "1000"; s_ByteAddr <= "11"; wait for 10 ns;
        check("lb  neg3 ", s_ByteOut, x"FFFFFFAA");

        -- LB with positive byte: 0x00 -> 0x00000000
        s_mem    <= x"AA7F00BB";
        s_ByteOp <= "1000"; s_ByteAddr <= "01"; wait for 10 ns;
        check("lb  pos  ", s_ByteOut, x"00000000");

        -- LHU halfword 0 (0xCCDD): zero extend -> 0x0000CCDD
        s_mem    <= x"AABBCCDD";
        s_ByteOp <= "1011"; s_ByteAddr <= "00"; wait for 10 ns;
        check("lhu low  ", s_ByteOut, x"0000CCDD");

        -- LHU halfword 1 (0xAABB): zero extend -> 0x0000AABB
        s_ByteOp <= "1011"; s_ByteAddr <= "10"; wait for 10 ns;
        check("lhu high ", s_ByteOut, x"0000AABB");

        -- LH halfword 0 (0xCCDD = 1100...): sign bit=1 -> 0xFFFFCCDD
        s_ByteOp <= "1010"; s_ByteAddr <= "00"; wait for 10 ns;
        check("lh  neg  ", s_ByteOut, x"FFFFCCDD");

        -- LH halfword 1 (0xAABB): sign bit=1 -> 0xFFFFAABB
        s_ByteOp <= "1010"; s_ByteAddr <= "10"; wait for 10 ns;
        check("lh  neg2 ", s_ByteOut, x"FFFFAABB");


        s_mem    <= x"AA7FFF00";
        s_ByteOp <= "1010"; s_ByteAddr <= "10"; wait for 10 ns;
        check("lh  pos  ", s_ByteOut, x"FFFFAA7F");

        -- =====================================================================
        -- Store-then-load round trip: store a byte and load it back
        -- =====================================================================
        -- Store 0x42 at byte 2, check the merged word
        s_mem    <= x"11223344";
        s_RS2    <= x"00000042";
        s_ByteOp <= "0000"; s_ByteAddr <= "10"; wait for 10 ns;
        check("sb rt wr ", s_ByteOut, x"11423344");

        -- Now load byte 2 back (use the merged result as mem input)
        s_mem    <= x"11423344";
        s_ByteOp <= "1001"; s_ByteAddr <= "10"; wait for 10 ns;
        check("lbu rt rd", s_ByteOut, x"00000042");

        report "tb_byteMd complete" severity note;
        wait;

    end process;

end behavior;
