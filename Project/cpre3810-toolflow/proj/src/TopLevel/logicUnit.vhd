library IEEE;
use IEEE.std_logic_1164.all;


library work;
use work.RISCV_types.all;


entity logicUnit is
	generic(N : integer := DATA_WIDTH);
	port(
		i_A	: in std_logic_vector(N-1 downto 0);
		i_B	: in std_logic_vector(N-1 downto 0);
		i_CTL	: in std_logic_vector(1 downto 0);
		o_O	: out std_logic_vector(N-1 downto 0)
	);
end logicUnit;

architecture structural of logicUnit is
    ------------------------------------------------------------------------
    -- 4 to 1 By N bits Mux
    ------------------------------------------------------------------------ 
    component mux4t1_N is
	  generic(N : integer := DATA_WIDTH);
  		port(
    		i_S   : in  std_logic_vector(1 downto 0);
    		i_D0  : in  std_logic_vector(N-1 downto 0);
    		i_D1  : in  std_logic_vector(N-1 downto 0);
    		i_D2  : in  std_logic_vector(N-1 downto 0);
    		i_D3  : in  std_logic_vector(N-1 downto 0);
    		o_O   : out std_logic_vector(N-1 downto 0)
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


    ------------------------------------------------------------------------
    -- AND
    ------------------------------------------------------------------------ 
	component andg_N is
    	generic(N: integer := DATA_WIDTH);
    	port(
    		i_A	: in std_logic_vector(N-1 downto 0);
    		i_B	: in std_logic_vector(N-1 downto 0);
    		o_Q	: out std_logic_vector(N-1 downto 0)
    		);
    	end component;
    	
    ------------------------------------------------------------------------
    -- OR
    ------------------------------------------------------------------------ 
	component org_N is
    	generic(N: integer := DATA_WIDTH);
    	port(
    		i_A	: in std_logic_vector(N-1 downto 0);
    		i_B	: in std_logic_vector(N-1 downto 0);
    		o_Q	: out std_logic_vector(N-1 downto 0)
    		);
    	end component;


	signal s_XOR	: std_logic_vector(N-1 downto 0);
	signal s_OR	: std_logic_vector(N-1 downto 0);
	signal s_AND	: std_logic_vector(N-1 downto 0);
	
	

begin


    ------------------------------------------------------------------------
    -- XOR
    ------------------------------------------------------------------------ 
	U_XOR: xorg_N
	generic map(N => N)
	port map(
		i_A	=> i_A,
		i_B	=> i_B,
		o_Q	=> s_XOR
	);


    ------------------------------------------------------------------------
    -- AND
    ------------------------------------------------------------------------ 
	U_AND: andg_N
	generic map(N => N)
	port map(
		i_A	=> i_A,
		i_B	=> i_B,
		o_Q	=> s_AND
	);
	
    ------------------------------------------------------------------------
    -- OR
    ------------------------------------------------------------------------ 
	U_OR: org_N
	generic map(N => N)
	port map(
		i_A	=> i_A,
		i_B	=> i_B,
		o_Q	=> s_OR
	);
	
	
    ------------------------------------------------------------------------
    -- SELECT
    ------------------------------------------------------------------------ 
	SelectMux: mux4t1_N
	generic map(N => N)
	port map(
	    	i_S	=> i_CTL,
    		i_D0	=> s_XOR,
    		i_D1	=> s_AND,
    		i_D2	=> s_OR,
    		i_D3	=> (others => '0'),
    		o_O	=> o_O
    	);



end structural;

