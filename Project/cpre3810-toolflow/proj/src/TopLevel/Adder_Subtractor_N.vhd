library IEEE;
use IEEE.std_logic_1164.all;


library work;
use work.RISCV_types.all;


entity Adder_Subtractor_N is
generic(N : integer := DATA_WIDTH);
port(
iA      : in  std_logic_vector(N-1 downto 0);
iB      : in  std_logic_vector(N-1 downto 0);
iSUB    : in  std_logic; -- 0 = add, 1 = subtract
oSUM    : out std_logic_vector(N-1 downto 0);
oCout   : out std_logic
);
end Adder_Subtractor_N;

architecture structural of Adder_Subtractor_N is

    ------------------------------------------------------------------------
    -- Adder
    ------------------------------------------------------------------------ 
    component adder_N is
  	generic(N : integer := DATA_WIDTH);
	  port(
	    iA    : in  std_logic_vector(N-1 downto 0);
	    iB    : in  std_logic_vector(N-1 downto 0);
	    iCin  : in  std_logic;
	    oS    : out std_logic_vector(N-1 downto 0);
	    oCout : out std_logic
	  );
	end component;
    ------------------------------------------------------------------------
    -- XOR
    ------------------------------------------------------------------------ 
    component xorg_N is
    	generic(N: integer := DATA_WIDTH);
    	port(
    		i_A	: in std_logic_vector(N-1 downto 0);
    		i_B	: in std_logic_vector(N-1 downto 0);
    		o_Q	: out std_logic_vector(N-1 downto 0)
    		);
    	end component;


	-- Internal signals
	signal s_Binv  : std_logic_vector(N-1 downto 0);
	signal s_Bsel  : std_logic_vector(N-1 downto 0);

begin


U_XOR: xorg_N
	generic map(N => N)
	port map(
		i_A => iB,
		i_B => (others => iSUB),
		o_Q => s_Bsel
	);


-- Ripple Carry Adder (instantiate the N-bit adder you named `adder_N`)
U_ADDER: adder_N
	generic map(N => N)
	port map(
		iA    => iA,
		iB    => s_Bsel,
		iCin  => iSUB,    -- carry-in is SUB (0 => add, 1 => add two's complement)
		oS    => oSUM,
		oCout => oCout
	);

end structural;

