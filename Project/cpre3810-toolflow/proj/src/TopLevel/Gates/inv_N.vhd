library IEEE;
use IEEE.std_logic_1164.all;

entity inv_N is
  generic(
    N : integer := 8  -- Width of input/output vectors
  );
  port(
    i_D : in  std_logic_vector(N-1 downto 0);
    o_Q : out std_logic_vector(N-1 downto 0)
  );
end inv_N;

architecture structural of inv_N is

  -- Single-bit inverter component (matches your invg.vhd)
  component invg
    port(
      i_A : in  std_logic;
      o_F : out std_logic
    );
  end component;

begin

  -- Generate N instances of single-bit inverter
  gen_inv: for i in 0 to N-1 generate
    U_INV: invg
      port map(
        i_A => i_D(i),
        o_F => o_Q(i)
      );
  end generate gen_inv;

end structural;

