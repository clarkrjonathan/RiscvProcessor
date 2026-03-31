library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_misc.all;

library work;
use work.RISCV_types.all;

entity ALU is
port(
    		i_A		: in std_logic_vector(DATA_WIDTH-1 downto 0);
    		i_B		: in std_logic_vector(DATA_WIDTH-1 downto 0);
    		i_ALUCTL	: in std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
    		o_Zero		: out std_logic;
    		o_Output	: out std_logic_vector(DATA_WIDTH-1 downto 0)
    	);

end ALU;

architecture structure of ALU is

	
    ------------------------------------------------------------------------
    -- Adder/Subtractor
    ------------------------------------------------------------------------ 
    component Adder_Subtractor_N is
	generic(N : integer := DATA_WIDTH);
	port(
		iA      : in  std_logic_vector(N-1 downto 0);
		iB      : in  std_logic_vector(N-1 downto 0);
		iSUB    : in  std_logic; -- 0 = add, 1 = subtract
		oSUM    : out std_logic_vector(N-1 downto 0);
		oCout   : out std_logic
	);
	end component;
	
    ------------------------------------------------------------------------
    -- Shifter
    ------------------------------------------------------------------------ 
    component barrelShifter is
        port(
            i_Data      : in  std_logic_vector(31 downto 0);
            i_ShiftAmt  : in  std_logic_vector(4 downto 0);
            i_ShiftType : in  std_logic_vector(1 downto 0);
            o_Result    : out std_logic_vector(31 downto 0)
        );
    end component;
    
    ------------------------------------------------------------------------
    -- LOGIC UNIT
    ------------------------------------------------------------------------ 
    component logicUnit is
	generic(N : integer := DATA_WIDTH);
	port(
		i_A	: in std_logic_vector(N-1 downto 0);
		i_B	: in std_logic_vector(N-1 downto 0);
		i_CTL	: in std_logic_vector(1 downto 0);
		o_O	: out std_logic_vector(N-1 downto 0)
	);
    end component;
    
    
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
    -- xor gate
    ------------------------------------------------------------------------ 
	component xorg2 is

	  port(i_A          : in std_logic;
	       i_B          : in std_logic;
	       o_F          : out std_logic);

	end component;
	
    ------------------------------------------------------------------------
    -- xor gate
    ------------------------------------------------------------------------ 
	component org2 is

	  port(i_A          : in std_logic;
	       i_B          : in std_logic;
	       o_F          : out std_logic);

	end component;
	
	
    ------------------------------------------------------------------------
    -- and gate
    ------------------------------------------------------------------------ 
	  component andg2
	    port(
	      i_A : in  std_logic;
	      i_B : in  std_logic;
	      o_F : out std_logic
	    );
	  end component;
    
    ------------------------------------------------------------------------
    --CTL SIGNALS
    ------------------------------------------------------------------------
    signal s_ShiftType		: std_logic_vector(1 downto 0);
    signal s_LogicOp		: std_logic_vector(1 downto 0);
    signal s_ALUSel		: std_logic_vector(1 downto 0);
    signal s_UnsignedSLT	: std_logic;
    signal s_Subtract		: std_logic;
    
    
    ------------------------------------------------------------------------
    --INTERMEDIATE SIGNALS
    ------------------------------------------------------------------------
    signal s_Shifter		: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_AddSub		: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_Logic		: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_Output		: std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal s_SLT		: std_logic;
    
    signal s_ALUOR		: std_logic;
    
    signal s_AxorBSign		: std_logic;
    signal s_SLTFlipSign	: std_logic;
    
    signal s_ANegBPos		: std_logic;
    
    signal s_SLTSigned		: std_logic;
    
    
	
begin

    ------------------------------------------------------------------------
    --Unpacking control
    ------------------------------------------------------------------------
	s_ShiftType	<=	i_ALUCTL(8 downto 7);
	s_LogicOp	<=	i_ALUCTL(6 downto 5);
	s_ALUSel	<=	i_ALUCTL(4 downto 3);
	s_UnsignedSLT	<=	i_ALUCTL(2);
	s_Subtract	<=	i_ALUCTL(1);
	--Last signal is for inverting the zero bit just outside the ALU
	

	U_barrelShifter: barrelShifter
		port map(
			i_Data		=> i_A,
			i_ShiftAmt	=> i_B(4 downto 0),
			i_ShiftType	=> s_ShiftType,
			o_Result	=> s_Shifter
		);
		
	U_adderSubtractor: Adder_Subtractor_N
		generic map(N => DATA_WIDTH)
		port map(
			iA	=> i_A,
			iB	=> i_B,
			iSub	=> s_Subtract,
			oSum	=> s_AddSub
		);

    ------------------------------------------------------------------------
    --Checking if A and B are same sign
    -----------------------------------------------------------------------
	xorSignBits: xorg2
		port map(
			i_A	=> i_A(31),
			i_B	=> i_B(31),
			o_F	=> s_AxorBSign
		);
		
    ------------------------------------------------------------------------
    --Check to see if SLT bit needs flipped
    -----------------------------------------------------------------------
	checkInvertSLT: andg2
		port map(
			i_A	=> s_AxorBSign,
			i_B	=> s_UnsignedSLT,
			o_F	=> s_SLTFlipSign
		);
		
    ------------------------------------------------------------------------
    --If we are doing unsigned slt and AB have different signs, then we flip the sign before putting it at the 0 bit
    -----------------------------------------------------------------------
	forwardSLTSign: xorg2
		port map(
			i_A	=> s_SLTSigned,
			i_B	=> s_SLTFlipSign,
			o_F	=> s_SLT
		);
		
		
    ------------------------------------------------------------------------
    --Overflow protection - we are going to bypass the subtraction if one is positive and one is negative.
    ------------------------------------------------------------------------	
    	AnegBpos: andg2
    		port map(
    			i_A	=> s_AxorBsign,
    			i_B	=> i_A(31),
    			o_F	=> s_ANegBPos
    			);
    	
    	bypassOr: org2
    		port map(
    			i_A	=> s_ANegBPos,
    			i_B	=> s_AddSub(31),
    			o_F	=> s_SLTSigned
    			);
	

    ------------------------------------------------------------------------
    --Logic Unit
    ------------------------------------------------------------------------		
	U_logicUnit: logicUnit
		generic map(N => DATA_WIDTH)
		port map(
			i_A	=> i_A,
			i_B	=> i_B,
			i_CTL	=> s_LogicOp,
			o_O	=> s_Logic
		);
		
		
    ------------------------------------------------------------------------
    --Selector Mux
    ------------------------------------------------------------------------	
	U_selectMux: mux4t1_N
		generic map(N => DATA_WIDTH)
		port map(
			i_S		=> s_ALUSel,
			i_D0		=> s_Shifter,
			i_D1		=> s_AddSub,
			i_D2		=> s_Logic,
			i_D3		=> "0000000000000000000000000000000" & s_SLT,
			o_O		=> s_Output
			);
			
			
	o_Zero		<=	not or_reduce(s_Output);
	o_Output	<= 	s_Output;
	
		
	
end structure;
