-------------------------------------------------------------------------
-- Henry Duwe
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- RISCV_Processor.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a skeleton of a RISCV_Processor  
-- implementation.

-- 01/29/2019 by H3::Design created.
-- 04/10/2025 by AP::Coverted to RISC-V.
-- 02/19/2026 by H3::Renamed PC and handled OVFL
-------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

entity RISCV_Processor is
  generic(N : integer := DATA_WIDTH);
  port(iCLK            : in std_logic;
       iRST            : in std_logic;
       iInstLd         : in std_logic;
       iInstAddr       : in std_logic_vector(N-1 downto 0);
       iInstExt        : in std_logic_vector(N-1 downto 0);
       oALUOut         : out std_logic_vector(N-1 downto 0)); -- TODO: Hook this up to the output of the ALU. It is important for synthesis that you have this output that can effectively be impacted by all other components so they are not optimized away.

end  RISCV_Processor;


architecture structure of RISCV_Processor is

  -- Required data memory signals
  signal s_DMemWr       : std_logic; -- TODO: use this signal as the final active high data memory write enable signal
  signal s_DMemAddr     : std_logic_vector(N-1 downto 0); -- TODO: use this signal as the final data memory address input
  signal s_DMemData     : std_logic_vector(N-1 downto 0); -- TODO: use this signal as the final data memory data input
  signal s_DMemOut      : std_logic_vector(N-1 downto 0); -- TODO: use this signal as the data memory output
 
  -- Required register file signals 
  signal s_RegWr        : std_logic; -- TODO: use this signal as the final active high write enable input to the register file
  signal s_RegWrAddr    : std_logic_vector(4 downto 0); -- TODO: use this signal as the final destination register address input
  signal s_RegWrData    : std_logic_vector(N-1 downto 0); -- TODO: use this signal as the final data memory data input

  -- Required instruction memory signals
  signal s_IMemAddr     : std_logic_vector(N-1 downto 0); -- Do not assign this signal, assign to s_PC instead
  signal s_PC : std_logic_vector(N-1 downto 0); -- TODO: use this signal as your intended final instruction memory address input.
  signal s_Inst         : std_logic_vector(N-1 downto 0); -- TODO: use this signal as the instruction signal 

  -- Required halt signal -- for simulation
  signal s_Halt         : std_logic;  -- TODO: this signal indicates to the simulation that intended program execution has completed. (Use WFI with Opcode: 111 0011 func3: 000 and func12: 000100000101 -- func12 is imm field from I-format)

  -- Required overflow signal -- for overflow exception detection
  signal s_Ovfl         : std_logic;  -- this signal indicates an overflow exception would have been initiated

  component mem is
    generic(ADDR_WIDTH : integer;
            DATA_WIDTH : integer);
    port(
          clk          : in std_logic;
          addr         : in std_logic_vector((ADDR_WIDTH-1) downto 0);
          data         : in std_logic_vector((DATA_WIDTH-1) downto 0);
          we           : in std_logic := '1';
          q            : out std_logic_vector((DATA_WIDTH -1) downto 0));
    end component;
    
    
    
    
    ------------------------------------------------------------------------
    -- DFLIP FLOP REG FILE
    ------------------------------------------------------------------------ 
    component regfile is
  	port(
	    i_CLK      : in  std_logic;                      -- Clock
	    i_RST      : in  std_logic;                      -- Reset
	    i_WE       : in  std_logic;                      -- Write enable
	    i_WR_ADDR  : in  std_logic_vector(4 downto 0);   -- Write address (rd)
	    i_WR_DATA  : in  std_logic_vector(31 downto 0);  -- Write data
	    i_RD_ADDR1 : in  std_logic_vector(4 downto 0);   -- Read address 1 (rs1)
	    i_RD_ADDR2 : in  std_logic_vector(4 downto 0);   -- Read address 2 (rs2)
	    o_RD_DATA1 : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- Read data 1
	    o_RD_DATA2 : out std_logic_vector(DATA_WIDTH-1 downto 0)   -- Read data 2
  	);
	end component;





    ------------------------------------------------------------------------
    -- DFLIP FLOP REG (For Program counter)
    ------------------------------------------------------------------------ 
    component reg_N is
  	generic(N : integer := DATA_WIDTH);  -- width of register
  		port(
    		i_CLK : in  std_logic;     -- clock
    		i_RST : in  std_logic;     -- reset
    		i_WE  : in  std_logic;     -- write enable
    		i_D   : in  std_logic_vector(N-1 downto 0); -- data in
    		o_Q   : out std_logic_vector(N-1 downto 0)  -- data out
  		);
	end component;




    ------------------------------------------------------------------------
    -- 2 to 1 By N bits Mux
    ------------------------------------------------------------------------ 
    component mux2t1_N is
	  generic(N : integer := DATA_WIDTH);
  		port(
    		i_S   : in  std_logic;
    		i_D0  : in  std_logic_vector(N-1 downto 0);
    		i_D1  : in  std_logic_vector(N-1 downto 0);
    		o_O   : out std_logic_vector(N-1 downto 0)
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
    -- Byte Module
    ------------------------------------------------------------------------ 
    component byteMd is
    		port(
		i_ByteOp	: in std_logic_vector(BYTE_OP_WIDTH - 1 downto 0);
		i_mem		: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		i_RS2		: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		o_ByteOut	: out std_logic_vector(DATA_WIDTH - 1 downto 0)
		);
	end component;
    




    ------------------------------------------------------------------------
    --Immediate Generator
    ------------------------------------------------------------------------ 	
    component immGen is
    		port(
    		i_Inst	: in std_logic_vector(DATA_WIDTH - 1 downto 0);
    		o_Imm	: out std_logic_vector(DATA_WIDTH - 1 downto 0)
    		);	
    end component;
    
    
    
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
    -- ALU
    ------------------------------------------------------------------------ 
    component ALU is
    	port(
    		i_A		: in std_logic_vector(DATA_WIDTH-1 downto 0);
    		i_B		: in std_logic_vector(DATA_WIDTH-1 downto 0);
    		i_ALUCTL	: in std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
    		o_Zero		: out std_logic;
    		o_Output	: out std_logic_vector(DATA_WIDTH-1 downto 0)
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
    -- Control Module
    ------------------------------------------------------------------------ 
    component control is
    	port(
    		i_Inst		: in std_logic_vector(DATA_WIDTH-1 downto 0);
    		
    		o_jalr		: out std_logic; 
    		o_jump		: out std_logic;
    		o_regWrite	: out std_logic;
    		o_branch	: out std_logic;
    		o_WRBCKSEL	: out std_logic_vector(1 downto 0);
    		o_byteOp	: out std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
    		o_ALUOp		: out std_logic_vector(ALU_OP_WIDTH-1 downto 0);
		o_AUIPC		: out std_logic;
    		o_ALUSrc	: out std_logic;
    		o_HaltS		: out std_logic;
    		o_memWrite	: out std_logic
    	);
    end component;
    
    
    
    ------------------------------------------------------------------------
    -- ALU Control
    ------------------------------------------------------------------------     
    component ALUCtl is
    	port(
    		i_ALUOp	:	in std_logic_vector(ALU_OP_WIDTH-1 downto 0);
    		o_ALUCTL:	out std_logic_vector(ALU_CTL_WIDTH-1 downto 0)
    	);
    end component;

  -- TODO: You may add any additional signals or components your implementation 
  --       requires below this comment
  
  ---------------------------------------------------------------------------
  --CONTROL SIGNALS
  ---------------------------------------------------------------------------
  signal s_jalr			: std_logic;
  signal s_jump			: std_logic;
  signal s_branch		: std_logic;
  signal s_WRBCKSEL		: std_logic_vector(1 downto 0);
  signal s_ALUOp		: std_logic_vector(ALU_OP_WIDTH-1 downto 0);
  signal s_AUIPC		: std_logic;
  signal s_ALUSrc		: std_logic;
  
  ---------------------------------------------------------------------------
  --ALU SIGNALS
  ---------------------------------------------------------------------------
  signal s_ALUOut		: std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_ALUCTL		: std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
  signal s_ALUZero		: std_logic;
  signal s_B			: std_logic_vector(DATA_WIDTH-1 downto 0);
  
  ---------------------------------------------------------------------------
  --BYTEMOD SIGNALS
  ---------------------------------------------------------------------------
  signal s_byteOp		: std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
  signal s_byteOut		: std_logic_vector(DATA_WIDTH-1 downto 0);
  
  ---------------------------------------------------------------------------
  --IMM SIGNALS
  ---------------------------------------------------------------------------
  signal s_Imm			: std_logic_vector(DATA_WIDTH-1 downto 0);
  
  ---------------------------------------------------------------------------
  --REGISTER FILE SIGNALS
  ---------------------------------------------------------------------------
  signal s_RS1Data		: std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_RS2Data		: std_logic_vector(DATA_WIDTH-1 downto 0);
  
  ---------------------------------------------------------------------------
  --FETCH SIGNALS
  ---------------------------------------------------------------------------
  signal s_IncPC		: std_logic_vector(DATA_WIDTH-1 downto 0); --This is always the next pc instruction SEQUENTIALLY
  signal s_PCWriteBack		: std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_RS1_PC		: std_logic_vector(DATA_WIDTH-1 downto 0); --Either RS1 or PC depending on inst
  signal s_PCNext		: std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_PCFetch		: std_logic_vector(DATA_WIDTH-1 downto 0); --The value fetched for the next pc, the actual next instruction address input to PC
  signal s_BranchJumpAdded	: std_logic_vector(DATA_WIDTH-1 downto 0); -- The result of the branch/jump adder
  
  signal s_BranchJump		: std_logic; --0 if we are normally incrementing PC, 1 if branch/jump
  
  signal s_CondMet		: std_logic; --Adjusted zero bit for blt, bltu, and bne
  
  

begin
  s_Ovfl <= '0'; -- RISC-V does not have hardware overflow detection.
  -- TODO: This is required to be your final input to your instruction memory. This provides a feasible method to externally load the memory module which means that the synthesis tool must assume it knows nothing about the values stored in the instruction memory. If this is not included, much, if not all of the design is optimized out because the synthesis tool will believe the memory to be all zeros.
  with iInstLd select
    s_IMemAddr <= s_PC when '0',
      iInstAddr when others;


  IMem: mem
    generic map(ADDR_WIDTH => ADDR_WIDTH,
                DATA_WIDTH => N)
    port map(clk  => iCLK,
             addr => s_IMemAddr(11 downto 2),
             data => iInstExt,
             we   => iInstLd,
             q    => s_Inst);
  
  DMem: mem
    generic map(ADDR_WIDTH => ADDR_WIDTH,
                DATA_WIDTH => N)
    port map(clk  => iCLK,
             addr => s_DMemAddr(11 downto 2),
             data => s_DMemData,
             we   => s_DMemWr,
             q    => s_DMemOut);

  -- TODO: Ensure that s_Halt is connected to an output control signal produced from decoding the Halt instruction (Opcode: 01 0100)

  -- TODO: Implement the rest of your processor below this comment! 
  
  
  -------------------------------------------------------------------------------------------------------------------
  --CONTROL MODULE
  -------------------------------------------------------------------------------------------------------------------
  ControlMod: control
  	port map(
  		i_Inst		=> s_Inst, --Instruction src
  		
    		o_jalr		=> s_jalr, --enabled if pc source is reg
    		o_jump		=> s_jump, --enabled if pc source 
    		o_regWrite	=> s_RegWr,
    		o_branch	=> s_branch,
    		o_WRBCKSEL	=> s_WRBCKSEL,
    		o_byteOp	=> s_byteOp,
    		o_ALUOp		=> s_ALUOp,
    		o_AUIPC		=> s_AUIPC,
    		o_ALUSrc	=> s_ALUSrc,
    		o_HaltS 	=> s_Halt,
    		o_memWrite	=> s_DMemWr);
  

  
  
  -------------------------------------------------------------------------------------------------------------------
  --WRITE BACK SELECT MUX
  -------------------------------------------------------------------------------------------------------------------
  WriteBackMux: mux4t1_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		i_S		=> s_WRBCKSEL,
  		i_D0		=> s_PCWriteBack,
  		i_D1		=> s_Imm,
  		i_D2		=> s_ByteOut,
  		i_D3		=> s_ALUOut,
  		o_O		=> s_RegWrData --this actually drives the write data
  		);
  
  
 
 
 
  -------------------------------------------------------------------------------------------------------------------
  --REGISTER FILE
  -------------------------------------------------------------------------------------------------------------------
  s_RegWrAddr <= s_Inst(11 downto 7); --rd address always same slot in instruction
   
  RegisterFile: regfile
  	port map(
	    i_CLK      		=> iCLK,
	    i_RST      		=> iRST,
	    i_WE       		=> s_RegWr,
	    i_WR_ADDR  		=> s_RegWrAddr, --rd address
	    i_WR_DATA  		=> s_RegWrData, --rd data
	    i_RD_ADDR1 		=> s_Inst(19 downto 15), --rs1 address
	    i_RD_ADDR2 		=> s_Inst(24 downto 20), --rs2 address
	    o_RD_DATA1 		=> s_RS1Data,
	    o_RD_DATA2		=> s_RS2Data);
  
  

  -------------------------------------------------------------------------------------------------------------------
  --BRANCH VS JUMP MUX
  -------------------------------------------------------------------------------------------------------------------
  BranchJumpSel: mux2t1_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		i_S		=> s_jalr,
  		i_D0		=> s_PC,
  		i_D1		=> s_RS1DATA,
  		o_O		=> s_RS1_PC
		);
  

  
  -------------------------------------------------------------------------------------------------------------------
  --BRANCH VS INC MUX - Switches between just typical incrementing PC and a jump/branch
  -------------------------------------------------------------------------------------------------------------------
    BranchIncSel: mux2t1_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		i_S		=> s_BranchJump,
  		i_D0		=> s_IncPC,
  		i_D1		=> s_BranchJumpAdded,
  		o_O		=> s_PCFetch
		);
		
  -------------------------------------------------------------------------------------------------------------------
  --AUIPC MUX -When writing back pc we need to pull the inc adder if jump, BranchJumpAdded if auipc
  -------------------------------------------------------------------------------------------------------------------
        AUIPCMux: mux2t1_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		i_S		=> s_AUIPC,
  		i_D0		=> s_IncPC,
  		i_D1		=> s_BranchJumpAdded,
  		o_O		=> s_PCWriteBack
		);
  
  -------------------------------------------------------------------------------------------------------------------
  --PC INC ADDER
  -------------------------------------------------------------------------------------------------------------------
  	PCIncAdder: adder_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		iA		=> s_PC,
  		iB		=> std_logic_vector(to_unsigned(4, 32)),
  		iCin		=> '0',
  		oS		=> s_IncPc
  	);
  
  -------------------------------------------------------------------------------------------------------------------
  --BRANCH JUMP ADDER
  -------------------------------------------------------------------------------------------------------------------
  	BranchJumpAdder: adder_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		iA		=> s_RS1_PC,
  		iB		=> s_Imm,
  		iCin		=> '0',
  		oS		=> s_BranchJumpAdded
  	);
  
  -------------------------------------------------------------------------------------------------------------------
  --PROGRAM COUNTER  -Register that holds and updates the program address
  -------------------------------------------------------------------------------------------------------------------
  	s_PCNext <= x"00400000" when iRST = '1' else s_PCFetch;
  	
  	ProgramCounter: reg_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		i_CLK		=> iCLK,
  		i_RST		=> '0', --PCNext signal handles resets
  		i_WE		=> '1', --Single cycle, it writes when the clock is enabled
  		i_D		=> s_PCNext,
  		o_Q		=> s_PC
  		);
  
  
  -------------------------------------------------------------------------------------------------------------------
  --BYTE MODULE	-Manages load byte/halfword and store byte/halfword
  -------------------------------------------------------------------------------------------------------------------
  	ByteModule: byteMd
  	port map(
  		i_ByteOp	=> s_byteOp,
  		i_mem		=> s_DMemOut,
  		i_RS2		=> s_RS2Data,
  		o_ByteOut	=> s_byteOut
  		);
  		
  		
  	s_DMemData	<= s_byteOut;
  		

  -------------------------------------------------------------------------------------------------------------------
  --ALU CONTROL MODULE
  -------------------------------------------------------------------------------------------------------------------
  	ALUControl: ALUCtl
  		port map(
  			i_ALUOp		=> s_ALUOp,
  			o_ALUCTL	=> s_ALUCTL
  		);

  
  -------------------------------------------------------------------------------------------------------------------
  --ALU SOURCE MUX -Chooses between RS2 or Immediate
  -------------------------------------------------------------------------------------------------------------------
        ALUSourceMux: mux2t1_N
  	generic map(N => DATA_WIDTH)
  	port map(
  		i_S		=> s_ALUSrc,
  		i_D0		=> s_RS2Data,
  		i_D1		=> s_Imm,
  		o_O		=> s_B
		);


  
  -------------------------------------------------------------------------------------------------------------------
  --ALU
  -------------------------------------------------------------------------------------------------------------------
  	RISCVALU: ALU
  	port map(
  		i_A		=> s_RS1Data,
  		i_B		=> s_B,
  		i_ALUCTL	=> s_ALUCTL,
  		o_Zero		=> s_ALUZero,
  		o_Output	=> s_ALUOut
  		);
  
  	oALUOut		<= s_ALUOut;
	s_DMemAddr 	<= s_ALUOut;

  -------------------------------------------------------------------------------------------------------------------
  --INVERT ZERO XOR
  -------------------------------------------------------------------------------------------------------------------
  	ZeroXor: xorg2
  	port map(
  		i_A	=> s_ALUZero,
  		i_B	=> s_ALUCTL(0),
  		o_F	=> s_CondMet
  		);
  
  
    -------------------------------------------------------------------------------------------------------------------
  --BRANCH JUMP SIGNAL LOGIC
  -------------------------------------------------------------------------------------------------------------------
  s_BranchJump <= (s_CondMet and s_branch) or s_jump;
  
  -------------------------------------------------------------------------------------------------------------------
  --IMMEDIATE GENERATOR
  -------------------------------------------------------------------------------------------------------------------
  	ImmediateGen: immGen
  	port map(
  		i_Inst		=> s_Inst,
  		o_Imm		=> s_Imm
  		);
  
  -------------------------------------------------------------------------------------------------------------------
  --
  -------------------------------------------------------------------------------------------------------------------
end structure;

