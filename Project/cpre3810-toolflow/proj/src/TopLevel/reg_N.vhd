
library IEEE;
use IEEE.std_logic_1164.all;

entity reg_N is
  generic(N		: integer := 32;
  	  RST_VAL	: std_logic_vector(N-1 downto 0) := (others => '0'));  -- width of register
  port(
    i_CLK : in  std_logic;     -- clock
    i_RST : in  std_logic;     -- reset
    i_WE  : in  std_logic;     -- write enable
    i_D   : in  std_logic_vector(N-1 downto 0); -- data in
    o_Q   : out std_logic_vector(N-1 downto 0)  -- data out
  );
end reg_N;

architecture structural of reg_N is

  -- Component declaration for dffg
  component dffg is
  generic(RST_VAL	: std_logic);
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic;
      o_Q   : out std_logic
    );
  end component;
  


begin



  -- Generate N flip-flops
  GEN_REG: for i in 0 to N-1 generate
    DFFI: dffg
    	generic map(RST_VAL	=> RST_VAL(i))
      port map(
        i_CLK => i_CLK,
        i_RST => i_RST,
        i_WE  => i_WE,
        i_D   => i_D(i),
        o_Q   => o_Q(i)
      );
  end generate GEN_REG;
  
  

end structural;

