library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
-- reg_N: N-bit register built from dffg flip-flops.
--
-- RST_VAL is constrained to (N-1 downto 0) in the entity so that
-- RST_VAL(i) in the generate loop always indexes correctly with a
-- known, stable downto range: RST_VAL(0)=LSB, RST_VAL(N-1)=MSB.
--
-- Component declarations in files that instantiate reg_N use
-- unconstrained std_logic_vector for RST_VAL -- this satisfies
-- synthesis tools that reject constrained generics at the component
-- declaration level. VHDL binds components to entities by name so
-- the unconstrained component declaration works correctly with this
-- constrained entity in both ModelSim and synthesis.

entity reg_N is
  generic(
    N       : integer := 32;
    RST_VAL : std_logic_vector := (0 => '0')
  );
  port(
    i_CLK : in  std_logic;
    i_RST : in  std_logic;
    i_WE  : in  std_logic;
    i_D   : in  std_logic_vector(N-1 downto 0);
    o_Q   : out std_logic_vector(N-1 downto 0)
  );
end reg_N;

architecture structural of reg_N is

constant c_RST : std_logic_vector(N-1 downto 0) 
      := std_logic_vector(resize(unsigned(RST_VAL), N));

  component dffg is
    generic(RST_VAL : std_logic);
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic;
      o_Q   : out std_logic
    );
  end component;

begin

  GEN_REG: for i in 0 to N-1 generate
    DFFI: dffg
      generic map(RST_VAL => c_RST(i))
      port map(
        i_CLK => i_CLK,
        i_RST => i_RST,
        i_WE  => i_WE,
        i_D   => i_D(i),
        o_Q   => o_Q(i)
      );
  end generate GEN_REG;

end structural;
