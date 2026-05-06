-- ============================================================
-- tb_mux4t1_N.vhd
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mux4t1_N is
end tb_mux4t1_N;

architecture behavior of tb_mux4t1_N is

    component mux4t1_N is
        generic(N : integer := 32);
        port(
            i_S  : in  std_logic_vector(1 downto 0);
            i_D0 : in  std_logic_vector(31 downto 0);
            i_D1 : in  std_logic_vector(31 downto 0);
            i_D2 : in  std_logic_vector(31 downto 0);
            i_D3 : in  std_logic_vector(31 downto 0);
            o_O  : out std_logic_vector(31 downto 0)
        );
    end component;

    signal s_S  : std_logic_vector(1 downto 0);
    signal s_D0 : std_logic_vector(31 downto 0);
    signal s_D1 : std_logic_vector(31 downto 0);
    signal s_D2 : std_logic_vector(31 downto 0);
    signal s_D3 : std_logic_vector(31 downto 0);
    signal s_O  : std_logic_vector(31 downto 0);

    procedure check(
        name     : in string;
        got      : in std_logic_vector(31 downto 0);
        expected : in std_logic_vector(31 downto 0)
    ) is
    begin
        if got = expected then
            report "mux4t1_N " & name & " PASS" severity note;
        else
            report "mux4t1_N " & name & " FAIL: got 0x" & to_hstring(got)
                   & " expected 0x" & to_hstring(expected) severity error;
        end if;
    end procedure;

begin

    UUT: mux4t1_N
        generic map(N => 32)
        port map(
            i_S  => s_S,
            i_D0 => s_D0,
            i_D1 => s_D1,
            i_D2 => s_D2,
            i_D3 => s_D3,
            o_O  => s_O
        );

    process
    begin
        s_D0 <= x"AAAAAAAA";
        s_D1 <= x"BBBBBBBB";
        s_D2 <= x"CCCCCCCC";
        s_D3 <= x"DDDDDDDD";

        -- select each input
        s_S <= "00"; wait for 10 ns;
        check("sel 00", s_O, x"AAAAAAAA");
        s_S <= "01"; wait for 10 ns;
        check("sel 01", s_O, x"BBBBBBBB");
        s_S <= "10"; wait for 10 ns;
        check("sel 10", s_O, x"CCCCCCCC");
        s_S <= "11"; wait for 10 ns;
        check("sel 11", s_O, x"DDDDDDDD");

        -- change inputs and verify correct one still selected
        s_D0 <= x"00000001";
        s_D1 <= x"00000002";
        s_D2 <= x"00000003";
        s_D3 <= x"00000004";
        s_S <= "00"; wait for 10 ns;
        check("new 00", s_O, x"00000001");
        s_S <= "01"; wait for 10 ns;
        check("new 01", s_O, x"00000002");
        s_S <= "10"; wait for 10 ns;
        check("new 10", s_O, x"00000003");
        s_S <= "11"; wait for 10 ns;
        check("new 11", s_O, x"00000004");

        -- all same value - output should always match
        s_D0 <= x"DEADBEEF";
        s_D1 <= x"DEADBEEF";
        s_D2 <= x"DEADBEEF";
        s_D3 <= x"DEADBEEF";
        s_S <= "00"; wait for 10 ns;
        check("same 00", s_O, x"DEADBEEF");
        s_S <= "11"; wait for 10 ns;
        check("same 11", s_O, x"DEADBEEF");

        -- all zeros
        s_D0 <= x"00000000"; s_D1 <= x"00000000";
        s_D2 <= x"00000000"; s_D3 <= x"00000000";
        s_S <= "10"; wait for 10 ns;
        check("zeros", s_O, x"00000000");

        report "tb_mux4t1_N complete" severity note;
        wait;
    end process;

end behavior;