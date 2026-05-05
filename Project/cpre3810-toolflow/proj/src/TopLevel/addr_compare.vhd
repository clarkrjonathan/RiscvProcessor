-------------------------------------------------------------------------
-- addr_compare.vhd
-- 5-bit address equality comparator.
-- Output o_Match is '1' when i_A == i_B, '0' otherwise.
-- Built from xorg2 + invg (XNOR per bit) then AND tree reduction.
--
-- XNOR per bit: eq_i = NOT(A_i XOR B_i)
-- AND tree:
--   level1_01 = eq0 AND eq1
--   level1_23 = eq2 AND eq3
--   level2_0  = level1_01 AND eq4
--   o_Match   = level2_0 AND level1_23
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity addr_compare is
  port(
    i_A     : in  std_logic_vector(4 downto 0);
    i_B     : in  std_logic_vector(4 downto 0);
    o_Match : out std_logic
  );
end addr_compare;

architecture structure of addr_compare is

  component xorg2 is
    port(i_A : in std_logic; i_B : in std_logic; o_F : out std_logic);
  end component;

  component invg is
    port(i_A : in std_logic; o_F : out std_logic);
  end component;

  component andg2 is
    port(i_A : in std_logic; i_B : in std_logic; o_F : out std_logic);
  end component;

  -- XOR outputs (one per bit)
  signal s_xor0, s_xor1, s_xor2, s_xor3, s_xor4 : std_logic;
  -- XNOR outputs (inverted XOR = equality per bit)
  signal s_eq0,  s_eq1,  s_eq2,  s_eq3,  s_eq4  : std_logic;
  -- AND tree intermediates
  signal s_and_01, s_and_23, s_and_4_01 : std_logic;

begin

  -- XOR each bit pair
  XOR0: xorg2 port map(i_A => i_A(0), i_B => i_B(0), o_F => s_xor0);
  XOR1: xorg2 port map(i_A => i_A(1), i_B => i_B(1), o_F => s_xor1);
  XOR2: xorg2 port map(i_A => i_A(2), i_B => i_B(2), o_F => s_xor2);
  XOR3: xorg2 port map(i_A => i_A(3), i_B => i_B(3), o_F => s_xor3);
  XOR4: xorg2 port map(i_A => i_A(4), i_B => i_B(4), o_F => s_xor4);

  -- Invert to get XNOR (bit equality)
  INV0: invg port map(i_A => s_xor0, o_F => s_eq0);
  INV1: invg port map(i_A => s_xor1, o_F => s_eq1);
  INV2: invg port map(i_A => s_xor2, o_F => s_eq2);
  INV3: invg port map(i_A => s_xor3, o_F => s_eq3);
  INV4: invg port map(i_A => s_xor4, o_F => s_eq4);

  -- AND tree: reduce 5 equality bits to one match signal
  AND_01:   andg2 port map(i_A => s_eq0,      i_B => s_eq1,      o_F => s_and_01);
  AND_23:   andg2 port map(i_A => s_eq2,      i_B => s_eq3,      o_F => s_and_23);
  AND_4_01: andg2 port map(i_A => s_eq4,      i_B => s_and_01,   o_F => s_and_4_01);
  AND_FINAL:andg2 port map(i_A => s_and_4_01, i_B => s_and_23,   o_F => o_Match);

end structure;