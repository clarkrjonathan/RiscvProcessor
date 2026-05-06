library IEEE;
use IEEE.std_logic_1164.all;

entity org_N is
  generic(
    N : integer := 8  -- Width of input/output vectors
  );
  port(
    i_A : in  std_logic_vector(N-1 downto 0);
    i_B : in  std_logic_vector(N-1 downto 0);
    o_Q : out std_logic_vector(N-1 downto 0)
  );
end org_N;

architecture structural of org_N is

  component org2
    port(
      i_A : in  std_logic;
      i_B : in  std_logic;
      o_F : out std_logic
    );
  end component;

begin


  gen_org: for i in 0 to N-1 generate
    U_ORG: org2
      port map(
        i_A => i_A(i),
        i_B => i_B(i),
        o_F => o_Q(i)
      );
  end generate gen_org;

end structural;

