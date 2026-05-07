-------------------------------------------------------------------------
-- RISCV_Processor.vhd  --  5-Stage Pipelined RISC-V Processor
--
-- HARDWARE HAZARD VERSION
-- Includes hazard detection unit and forwarding unit.
-- No software-inserted NOPs required for data hazards or control hazards.
--
-- Key changes from software-scheduled version:
--   1. hazard_detect instantiated; drives stall and squash vectors
--   2. forwarding_unit instantiated in decode stage; muxes RS1/RS2 before ID/EX
--   3. PC WE = NOT stall[4]
--   4. IF/ID WE = NOT stall[3], squash = squash[3]
--   5. ID/EX WE = NOT stall[2], squash = squash[2]
--      (stall[2] is currently always 0 per hazard unit design but wired
--       for completeness and future expansion)
--   6. EX/MEM and Imm passthrough reg_N WE = NOT stall[1]
--   7. MEM/WB WE = NOT stall[0]
--   8. Consolidated ALU/AUIPC mux moved BEFORE EX/MEM register so
--      EX/MEM.ALUOut carries the correct forwarding value in all cases.
--      PCWriteBack field in EX/MEM is now only the JAL/JALR return address.
--   9. ID_EX forwarding ports removed (forwarding is upstream via mux).
--
-- Stall vector  (5b): bit4=PC, bit3=IF/ID, bit2=ID/EX, bit1=EX/MEM, bit0=MEM/WB
-- Squash vector (4b): bit3=IF/ID, bit2=ID/EX, bit1=EX/MEM, bit0=MEM/WB
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.RISCV_types.all;

entity RISCV_Processor is
  generic(N : integer := DATA_WIDTH);
  port(
    iCLK     : in  std_logic;
    iRST     : in  std_logic;
    iInstLd  : in  std_logic;
    iInstAddr: in  std_logic_vector(N-1 downto 0);
    iInstExt : in  std_logic_vector(N-1 downto 0);
    oALUOut  : out std_logic_vector(N-1 downto 0)
  );
end RISCV_Processor;

architecture structure of RISCV_Processor is

  ---------------------------------------------------------------------------
  -- Component declarations
  ---------------------------------------------------------------------------
  component mem is
    generic(ADDR_WIDTH : integer; DATA_WIDTH : integer);
    port(clk  : in  std_logic;
         addr : in  std_logic_vector((ADDR_WIDTH-1) downto 0);
         data : in  std_logic_vector((DATA_WIDTH-1) downto 0);
         we   : in  std_logic := '1';
         q    : out std_logic_vector((DATA_WIDTH-1) downto 0));
  end component;

  component regfile is
    port(
      i_CLK      : in  std_logic;
      i_RST      : in  std_logic;
      i_WE       : in  std_logic;
      i_WR_ADDR  : in  std_logic_vector(4 downto 0);
      i_WR_DATA  : in  std_logic_vector(31 downto 0);
      i_RD_ADDR1 : in  std_logic_vector(4 downto 0);
      i_RD_ADDR2 : in  std_logic_vector(4 downto 0);
      o_RD_DATA1 : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RD_DATA2 : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;

  component reg_N is
    generic(N       : integer := DATA_WIDTH;
            RST_VAL : std_logic_vector := (0 => '0'));
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic_vector(N-1 downto 0);
      o_Q   : out std_logic_vector(N-1 downto 0));
  end component;

  component mux2t1_N is
    generic(N : integer := DATA_WIDTH);
    port(
      i_S  : in  std_logic;
      i_D0 : in  std_logic_vector(N-1 downto 0);
      i_D1 : in  std_logic_vector(N-1 downto 0);
      o_O  : out std_logic_vector(N-1 downto 0));
  end component;

  component mux4t1_N is
    generic(N : integer := DATA_WIDTH);
    port(
      i_S  : in  std_logic_vector(1 downto 0);
      i_D0 : in  std_logic_vector(N-1 downto 0);
      i_D1 : in  std_logic_vector(N-1 downto 0);
      i_D2 : in  std_logic_vector(N-1 downto 0);
      i_D3 : in  std_logic_vector(N-1 downto 0);
      o_O  : out std_logic_vector(N-1 downto 0));
  end component;

  component byteMd is
    port(
      i_ByteOp  : in  std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      i_ByteAddr: in  std_logic_vector(1 downto 0);
      i_mem     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS2     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_ByteOut : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;

  component immGen is
    port(
      i_Inst : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Imm  : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;

  component adder_N is
    generic(N : integer := DATA_WIDTH);
    port(
      iA    : in  std_logic_vector(N-1 downto 0);
      iB    : in  std_logic_vector(N-1 downto 0);
      iCin  : in  std_logic;
      oS    : out std_logic_vector(N-1 downto 0);
      oCout : out std_logic);
  end component;

  component ALU is
    port(
      i_A      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_B      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_ALUCTL : in  std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
      o_Zero   : out std_logic;
      o_Output : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;

  component ALUCtl is
    port(
      i_ALUOp  : in  std_logic_vector(ALU_OP_WIDTH-1 downto 0);
      o_ALUCTL : out std_logic_vector(ALU_CTL_WIDTH-1 downto 0));
  end component;

  component control is
    port(
      i_Inst    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_jalr    : out std_logic;
      o_jump    : out std_logic;
      o_regWrite: out std_logic;
      o_branch  : out std_logic;
      o_WRBCKSEL: out std_logic_vector(1 downto 0);
      o_byteOp  : out std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      o_ALUOp   : out std_logic_vector(ALU_OP_WIDTH-1 downto 0);
      o_AUIPC   : out std_logic;
      o_ALUSrc  : out std_logic;
      o_HaltS   : out std_logic;
      o_memWrite: out std_logic);
  end component;

  component xorg2 is
    port(i_A : in std_logic; i_B : in std_logic; o_F : out std_logic);
  end component;

  component invg is
    port(i_A : in std_logic; o_F : out std_logic);
  end component;

  component IF_ID is
    generic(
      NOP_PC    : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_PCINC : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_INST  : std_logic_vector(DATA_WIDTH-1 downto 0));
    port(
      i_CLK    : in  std_logic;
      i_RST    : in  std_logic;
      i_WE     : in  std_logic;
      i_Squash : in  std_logic;
      i_PC     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_PCInc  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_Inst   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_PC     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_PCInc  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Inst   : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;

  component ID_EX is
    generic(
      NOP_PC       : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_PCINC    : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_INST     : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_RS1DATA  : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_RS2DATA  : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_IMM      : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_ALUCTL   : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
      NOP_JALR     : std_logic_vector(0 downto 0);
      NOP_JUMP     : std_logic_vector(0 downto 0);
      NOP_BRANCH   : std_logic_vector(0 downto 0);
      NOP_AUIPC    : std_logic_vector(0 downto 0);
      NOP_ALUSRC   : std_logic_vector(0 downto 0);
      NOP_MEMWRITE : std_logic_vector(0 downto 0);
      NOP_BYTEOP   : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      NOP_REGWRITE : std_logic_vector(0 downto 0);
      NOP_WRBCKSEL : std_logic_vector(1 downto 0);
      NOP_HALTFLAG : std_logic_vector(0 downto 0));
    port(
      i_CLK      : in  std_logic;
      i_RST      : in  std_logic;
      i_WE       : in  std_logic;
      i_Squash   : in  std_logic;
      i_PC       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_PCInc    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_Inst     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS1Data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS2Data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_Imm      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_ALUCTL   : in  std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
      i_jalr     : in  std_logic;
      i_jump     : in  std_logic;
      i_branch   : in  std_logic;
      i_AUIPC    : in  std_logic;
      i_ALUSrc   : in  std_logic;
      i_memWrite : in  std_logic;
      i_byteOp   : in  std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      i_regWrite : in  std_logic;
      i_WRBCKSEL : in  std_logic_vector(1 downto 0);
      i_haltFlag : in  std_logic;
      o_PC       : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_PCInc    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Inst     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RS1Data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RS2Data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Imm      : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_ALUCTL   : out std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
      o_jalr     : out std_logic;
      o_jump     : out std_logic;
      o_branch   : out std_logic;
      o_AUIPC    : out std_logic;
      o_ALUSrc   : out std_logic;
      o_memWrite : out std_logic;
      o_byteOp   : out std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      o_regWrite : out std_logic;
      o_WRBCKSEL : out std_logic_vector(1 downto 0);
      o_haltFlag : out std_logic);
  end component;

  component EX_MEM is
    generic(
      NOP_INST        : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_PCWRITEBACK : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_ALUOUT      : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_RS2DATA     : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_MEMWRITE    : std_logic_vector(0 downto 0);
      NOP_BYTEOP      : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      NOP_REGWRITE    : std_logic_vector(0 downto 0);
      NOP_WRBCKSEL    : std_logic_vector(1 downto 0);
      NOP_HALTFLAG    : std_logic_vector(0 downto 0));
    port(
      i_CLK         : in  std_logic;
      i_RST         : in  std_logic;
      i_WE          : in  std_logic;
      i_Squash      : in  std_logic;
      i_Inst        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_PCWriteBack : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_ALUOut      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS2Data     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_memWrite    : in  std_logic;
      i_byteOp      : in  std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      i_regWrite    : in  std_logic;
      i_WRBCKSEL    : in  std_logic_vector(1 downto 0);
      i_haltFlag    : in  std_logic;
      o_Inst        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_PCWriteBack : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_ALUOut      : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RS2Data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_memWrite    : out std_logic;
      o_byteOp      : out std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      o_regWrite    : out std_logic;
      o_WRBCKSEL    : out std_logic_vector(1 downto 0);
      o_haltFlag    : out std_logic);
  end component;

  component MEM_WB is
    generic(
      NOP_INST        : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_PCWRITEBACK : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_ALUOUT      : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_BYTEOUT     : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_IMM         : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_REGWRITE    : std_logic_vector(0 downto 0);
      NOP_WRBCKSEL    : std_logic_vector(1 downto 0);
      NOP_HALTFLAG    : std_logic_vector(0 downto 0));
    port(
      i_CLK         : in  std_logic;
      i_RST         : in  std_logic;
      i_WE          : in  std_logic;
      i_Squash      : in  std_logic;
      i_Inst        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_PCWriteBack : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_ALUOut      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_ByteOut     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_Imm         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_regWrite    : in  std_logic;
      i_WRBCKSEL    : in  std_logic_vector(1 downto 0);
      i_haltFlag    : in  std_logic;
      o_Inst        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_PCWriteBack : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_ALUOut      : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_ByteOut     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Imm         : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_regWrite    : out std_logic;
      o_WRBCKSEL    : out std_logic_vector(1 downto 0);
      o_Halt        : out std_logic);
  end component;

  component hazard_detect is
    port(
      i_IFID_Inst  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_IDEX_Inst  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_EXMEM_Inst : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_BranchJump : in  std_logic;
      o_Stall      : out std_logic_vector(4 downto 0);
      o_Squash     : out std_logic_vector(3 downto 0);
      o_FWD_RS1    : out std_logic_vector(2 downto 0);
      o_FWD_RS2    : out std_logic_vector(2 downto 0));
  end component;

  component forwarding_unit is
    port(
      i_FWD_RS1      : in  std_logic_vector(2 downto 0);
      i_FWD_RS2      : in  std_logic_vector(2 downto 0);
      i_RS1_RegFile  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS2_RegFile  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_EX_ALUOut    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_EXMEM_ALUOut : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_MEM_ByteOut  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RS1Data      : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RS2Data      : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;

  ---------------------------------------------------------------------------
  -- Required top-level signals
  ---------------------------------------------------------------------------
  signal s_DMemWr    : std_logic;
  signal s_DMemAddr  : std_logic_vector(N-1 downto 0);
  signal s_DMemData  : std_logic_vector(N-1 downto 0);
  signal s_DMemOut   : std_logic_vector(N-1 downto 0);
  signal s_RegWr     : std_logic;
  signal s_RegWrAddr : std_logic_vector(4 downto 0);
  signal s_RegWrData : std_logic_vector(N-1 downto 0);
  signal s_IMemAddr  : std_logic_vector(N-1 downto 0);
  signal s_PC        : std_logic_vector(N-1 downto 0);
  signal s_Inst      : std_logic_vector(N-1 downto 0);
  signal s_Halt      : std_logic;
  signal s_Ovfl      : std_logic;

  ---------------------------------------------------------------------------
  -- Hazard / stall / squash control
  ---------------------------------------------------------------------------
  signal s_Stall       : std_logic_vector(4 downto 0);
  signal s_Squash      : std_logic_vector(3 downto 0);
  signal s_FWD_RS1     : std_logic_vector(2 downto 0);
  signal s_FWD_RS2     : std_logic_vector(2 downto 0);

  -- Inverted stall bits for WE ports
  signal s_PC_WE       : std_logic;
  signal s_IFID_WE     : std_logic;
  signal s_IDEX_WE     : std_logic;
  signal s_EXMEM_WE    : std_logic;
  signal s_MEMWB_WE    : std_logic;

  ---------------------------------------------------------------------------
  -- FETCH stage
  ---------------------------------------------------------------------------
  signal s_IncPC          : std_logic_vector(N-1 downto 0);
  signal s_PCFetch        : std_logic_vector(N-1 downto 0);
  signal s_BranchJump_EX  : std_logic;
  signal s_BranchTarget   : std_logic_vector(N-1 downto 0);

  ---------------------------------------------------------------------------
  -- IF/ID register outputs
  ---------------------------------------------------------------------------
  signal id_PC    : std_logic_vector(N-1 downto 0);
  signal id_PCInc : std_logic_vector(N-1 downto 0);
  signal id_Inst  : std_logic_vector(N-1 downto 0);

  ---------------------------------------------------------------------------
  -- DECODE stage signals
  ---------------------------------------------------------------------------
  signal s_RS1Data_RF  : std_logic_vector(N-1 downto 0);  -- raw regfile output
  signal s_RS2Data_RF  : std_logic_vector(N-1 downto 0);
  signal s_RS1Data_FWD : std_logic_vector(N-1 downto 0);  -- after forwarding mux
  signal s_RS2Data_FWD : std_logic_vector(N-1 downto 0);
  signal s_Imm         : std_logic_vector(N-1 downto 0);
  signal s_ALUCTL      : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
  signal s_ALUOp       : std_logic_vector(ALU_OP_WIDTH-1 downto 0);
  signal s_jalr_d      : std_logic;
  signal s_jump_d      : std_logic;
  signal s_branch_d    : std_logic;
  signal s_WRBCKSEL_d  : std_logic_vector(1 downto 0);
  signal s_byteOp_d    : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
  signal s_AUIPC_d     : std_logic;
  signal s_ALUSrc_d    : std_logic;
  signal s_haltFlag_d  : std_logic;
  signal s_memWrite_d  : std_logic;
  signal s_regWrite_d  : std_logic;

  ---------------------------------------------------------------------------
  -- ID/EX register outputs
  ---------------------------------------------------------------------------
  signal ex_PC       : std_logic_vector(N-1 downto 0);
  signal ex_PCInc    : std_logic_vector(N-1 downto 0);
  signal ex_Inst     : std_logic_vector(N-1 downto 0);
  signal ex_RS1Data  : std_logic_vector(N-1 downto 0);
  signal ex_RS2Data  : std_logic_vector(N-1 downto 0);
  signal ex_Imm      : std_logic_vector(N-1 downto 0);
  signal ex_ALUCTL   : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
  signal ex_jalr     : std_logic;
  signal ex_jump     : std_logic;
  signal ex_branch   : std_logic;
  signal ex_AUIPC    : std_logic;
  signal ex_ALUSrc   : std_logic;
  signal ex_memWrite : std_logic;
  signal ex_byteOp   : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
  signal ex_regWrite : std_logic;
  signal ex_WRBCKSEL : std_logic_vector(1 downto 0);
  signal ex_haltFlag : std_logic;

  ---------------------------------------------------------------------------
  -- EXECUTE stage signals
  ---------------------------------------------------------------------------
  signal s_ALU_B           : std_logic_vector(N-1 downto 0);
  signal s_ALUOut_EX       : std_logic_vector(N-1 downto 0);
  signal s_ALUZero_EX      : std_logic;
  signal s_CondMet_EX      : std_logic;
  signal s_BJAdder_A       : std_logic_vector(N-1 downto 0);
  signal s_BranchJumpAdded : std_logic_vector(N-1 downto 0);
  -- PCWriteBack: only JAL/JALR return address (AUIPC now in ALUOut via mux)
  signal s_PCWriteBack_EX  : std_logic_vector(N-1 downto 0);
  -- Consolidated ALUOut: mux between ALU result and AUIPC result
  -- This is what enters EX/MEM ALUOut field and is the forwarding source
  signal s_ALUOut_Consol   : std_logic_vector(N-1 downto 0);
  
  signal s_LUI_Inst        : std_logic;
  signal s_LUIALU_Consol   : std_logic_vector(N-1 downto 0);

  ---------------------------------------------------------------------------
  -- EX/MEM register outputs
  ---------------------------------------------------------------------------
  signal mem_Inst        : std_logic_vector(N-1 downto 0);
  signal mem_PCWriteBack : std_logic_vector(N-1 downto 0);
  signal mem_ALUOut      : std_logic_vector(N-1 downto 0);
  signal mem_RS2Data     : std_logic_vector(N-1 downto 0);
  signal mem_memWrite    : std_logic;
  signal mem_byteOp      : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
  signal mem_regWrite    : std_logic;
  signal mem_WRBCKSEL    : std_logic_vector(1 downto 0);
  signal mem_haltFlag    : std_logic;

  ---------------------------------------------------------------------------
  -- MEMORY stage signals
  ---------------------------------------------------------------------------
  signal s_ByteOut_MEM : std_logic_vector(N-1 downto 0);
  signal s_Imm_EX      : std_logic_vector(N-1 downto 0);
  signal s_Imm_MEM     : std_logic_vector(N-1 downto 0);

  ---------------------------------------------------------------------------
  -- MEM/WB register outputs
  ---------------------------------------------------------------------------
  signal wb_Inst        : std_logic_vector(N-1 downto 0);
  signal wb_PCWriteBack : std_logic_vector(N-1 downto 0);
  signal wb_ALUOut      : std_logic_vector(N-1 downto 0);
  signal wb_ByteOut     : std_logic_vector(N-1 downto 0);
  signal wb_Imm         : std_logic_vector(N-1 downto 0);
  signal wb_regWrite    : std_logic;
  signal wb_WRBCKSEL    : std_logic_vector(1 downto 0);

begin

  s_Ovfl <= '0';

  ---------------------------------------------------------------------------
  -- HAZARD DETECTION UNIT
  ---------------------------------------------------------------------------
  HazardUnit: hazard_detect
    port map(
      i_IFID_Inst  => id_Inst,
      i_IDEX_Inst  => ex_Inst,
      i_EXMEM_Inst => mem_Inst,
      i_BranchJump => s_BranchJump_EX,
      o_Stall      => s_Stall,
      o_Squash     => s_Squash,
      o_FWD_RS1    => s_FWD_RS1,
      o_FWD_RS2    => s_FWD_RS2);

  -- Invert stall bits to derive WE signals
  inv_PC_WE:    invg port map(i_A => s_Stall(4), o_F => s_PC_WE);
  inv_IFID_WE:  invg port map(i_A => s_Stall(3), o_F => s_IFID_WE);
  inv_IDEX_WE:  invg port map(i_A => s_Stall(2), o_F => s_IDEX_WE);
  inv_EXMEM_WE: invg port map(i_A => s_Stall(1), o_F => s_EXMEM_WE);
  inv_MEMWB_WE: invg port map(i_A => s_Stall(0), o_F => s_MEMWB_WE);

  ---------------------------------------------------------------------------
  -- INSTRUCTION MEMORY
  ---------------------------------------------------------------------------
  with iInstLd select
    s_IMemAddr <= s_PC       when '0',
                  iInstAddr  when others;

  IMem: mem
    generic map(ADDR_WIDTH => ADDR_WIDTH, DATA_WIDTH => N)
    port map(clk  => iCLK,
             addr => s_IMemAddr(11 downto 2),
             data => iInstExt,
             we   => iInstLd,
             q    => s_Inst);

  ---------------------------------------------------------------------------
  -- DATA MEMORY
  ---------------------------------------------------------------------------
  s_DMemAddr <= mem_ALUOut;
  s_DMemWr   <= mem_memWrite;

  DMem: mem
    generic map(ADDR_WIDTH => ADDR_WIDTH, DATA_WIDTH => N)
    port map(clk  => iCLK,
             addr => s_DMemAddr(11 downto 2),
             data => s_DMemData,
             we   => s_DMemWr,
             q    => s_DMemOut);

  ---------------------------------------------------------------------------
  -- FETCH STAGE
  ---------------------------------------------------------------------------
  PCIncAdder: adder_N
    generic map(N => DATA_WIDTH)
    port map(iA => s_PC, iB => std_logic_vector(to_unsigned(4, 32)),
             iCin => '0', oS => s_IncPC, oCout => open);

  BranchIncSel: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S  => s_BranchJump_EX,
             i_D0 => s_IncPC,
             i_D1 => s_BranchTarget,
             o_O  => s_PCFetch);

  ProgramCounter: reg_N
    generic map(N => 32, RST_VAL => x"00400000")
    port map(i_CLK => iCLK, i_RST => iRST,
             i_WE  => s_PC_WE,
             i_D   => s_PCFetch,
             o_Q   => s_PC);

  ---------------------------------------------------------------------------
  -- IF/ID REGISTER
  -- WE from stall[3], squash from squash[3]
  ---------------------------------------------------------------------------
  IFID_reg: IF_ID
    generic map(
      NOP_PC    => (others => '0'),
      NOP_PCINC => (others => '0'),
      NOP_INST  => x"00000033")
    port map(
      i_CLK    => iCLK, i_RST    => iRST,
      i_WE     => s_IFID_WE,
      i_Squash => s_Squash(3),
      i_PC     => s_PC,   i_PCInc => s_IncPC,  i_Inst => s_Inst,
      o_PC     => id_PC,  o_PCInc => id_PCInc, o_Inst => id_Inst);

  ---------------------------------------------------------------------------
  -- DECODE STAGE
  -- Register file write port driven by WB outputs.
  -- RS1/RS2 read outputs go through forwarding unit before ID/EX.
  ---------------------------------------------------------------------------
  s_RegWrAddr <= wb_Inst(11 downto 7);
  s_RegWr     <= wb_regWrite;

  ControlMod: control
    port map(
      i_Inst     => id_Inst,
      o_jalr     => s_jalr_d,   o_jump     => s_jump_d,
      o_regWrite => s_regWrite_d, o_branch  => s_branch_d,
      o_WRBCKSEL => s_WRBCKSEL_d, o_byteOp => s_byteOp_d,
      o_ALUOp    => s_ALUOp,    o_AUIPC    => s_AUIPC_d,
      o_ALUSrc   => s_ALUSrc_d, o_HaltS    => s_haltFlag_d,
      o_memWrite => s_memWrite_d);
      
      s_LUI_Inst <= ex_WRBCKSEL(0) and (not ex_WRBCKSEL(1));

  ImmediateGen: immGen
    port map(i_Inst => id_Inst, o_Imm => s_Imm);

  ALUControl: ALUCtl
    port map(i_ALUOp => s_ALUOp, o_ALUCTL => s_ALUCTL);

  RegisterFile: regfile
    port map(
      i_CLK      => iCLK,       i_RST      => iRST,
      i_WE       => s_RegWr,    i_WR_ADDR  => s_RegWrAddr,
      i_WR_DATA  => s_RegWrData,
      i_RD_ADDR1 => id_Inst(19 downto 15),
      i_RD_ADDR2 => id_Inst(24 downto 20),
      o_RD_DATA1 => s_RS1Data_RF,
      o_RD_DATA2 => s_RS2Data_RF);

  -- Forwarding unit: muxes register file outputs with forwarded values.
  -- i_EX_ALUOut    = combinatorial ALU output (inst currently in EX)
  -- i_EXMEM_ALUOut = consolidated ALUOut from EX/MEM register
  -- i_MEM_ByteOut  = byte module output from MEM stage
  FwdUnit: forwarding_unit
    port map(
      i_FWD_RS1      => s_FWD_RS1,
      i_FWD_RS2      => s_FWD_RS2,
      i_RS1_RegFile  => s_RS1Data_RF,
      i_RS2_RegFile  => s_RS2Data_RF,
      i_EX_ALUOut    => s_LUIALU_Consol,      -- combinatorial, from EX stage below
      i_EXMEM_ALUOut => mem_ALUOut,        -- from EX/MEM register
      i_MEM_ByteOut  => s_ByteOut_MEM,     -- from byte module in MEM stage
      o_RS1Data      => s_RS1Data_FWD,
      o_RS2Data      => s_RS2Data_FWD);

  ---------------------------------------------------------------------------
  -- ID/EX REGISTER
  -- WE from stall[2] (currently always 1 but wired for completeness)
  -- Squash from squash[2] (load stall OR branch)
  -- RS1Data and RS2Data come from forwarding unit outputs
  ---------------------------------------------------------------------------
  IDEX_reg: ID_EX
    generic map(
      NOP_PC       => (others => '0'), NOP_PCINC    => (others => '0'),
      NOP_INST     => x"00000033",     NOP_RS1DATA  => (others => '0'),
      NOP_RS2DATA  => (others => '0'), NOP_IMM      => (others => '0'),
      NOP_ALUCTL   => (others => '0'), NOP_JALR     => "0",
      NOP_JUMP     => "0",             NOP_BRANCH   => "0",
      NOP_AUIPC    => "0",             NOP_ALUSRC   => "0",
      NOP_MEMWRITE => "0",             NOP_BYTEOP   => (others => '0'),
      NOP_REGWRITE => "0",             NOP_WRBCKSEL => (others => '0'),
      NOP_HALTFLAG => "0")
    port map(
      i_CLK      => iCLK,          i_RST      => iRST,
      i_WE       => s_IDEX_WE,     i_Squash   => s_Squash(2),
      i_PC       => id_PC,         i_PCInc    => id_PCInc,
      i_Inst     => id_Inst,
      i_RS1Data  => s_RS1Data_FWD, -- from forwarding unit
      i_RS2Data  => s_RS2Data_FWD, -- from forwarding unit
      i_Imm      => s_Imm,
      i_ALUCTL   => s_ALUCTL,      i_jalr     => s_jalr_d,
      i_jump     => s_jump_d,      i_branch   => s_branch_d,
      i_AUIPC    => s_AUIPC_d,     i_ALUSrc   => s_ALUSrc_d,
      i_memWrite => s_memWrite_d,  i_byteOp   => s_byteOp_d,
      i_regWrite => s_regWrite_d,  i_WRBCKSEL => s_WRBCKSEL_d,
      i_haltFlag => s_haltFlag_d,
      o_PC       => ex_PC,         o_PCInc    => ex_PCInc,
      o_Inst     => ex_Inst,       o_RS1Data  => ex_RS1Data,
      o_RS2Data  => ex_RS2Data,    o_Imm      => ex_Imm,
      o_ALUCTL   => ex_ALUCTL,     o_jalr     => ex_jalr,
      o_jump     => ex_jump,       o_branch   => ex_branch,
      o_AUIPC    => ex_AUIPC,      o_ALUSrc   => ex_ALUSrc,
      o_memWrite => ex_memWrite,   o_byteOp   => ex_byteOp,
      o_regWrite => ex_regWrite,   o_WRBCKSEL => ex_WRBCKSEL,
      o_haltFlag => ex_haltFlag);

  ---------------------------------------------------------------------------
  -- EXECUTE STAGE
  ---------------------------------------------------------------------------

  -- BranchJumpAdder input A: PC (PC-relative) or RS1 (JALR)
  BranchJumpASel: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S => ex_jalr, i_D0 => ex_PC, i_D1 => ex_RS1Data,
             o_O => s_BJAdder_A);

  BranchJumpAdder: adder_N
    generic map(N => DATA_WIDTH)
    port map(iA => s_BJAdder_A, iB => ex_Imm, iCin => '0',
             oS => s_BranchJumpAdded, oCout => open);

  s_BranchTarget <= s_BranchJumpAdded;

  -- ALU source mux: RS2 or Imm
  ALUSourceMux: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S => ex_ALUSrc, i_D0 => ex_RS2Data, i_D1 => ex_Imm,
             o_O => s_ALU_B);

  RISCVALU: ALU
    port map(i_A => ex_RS1Data, i_B => s_ALU_B, i_ALUCTL => ex_ALUCTL,
             o_Zero => s_ALUZero_EX, o_Output => s_ALUOut_EX);

  oALUOut <= s_ALUOut_EX;

  -- Branch condition
  ZeroXor: xorg2
    port map(i_A => s_ALUZero_EX, i_B => ex_ALUCTL(0), o_F => s_CondMet_EX);

  s_BranchJump_EX <= (s_CondMet_EX and ex_branch) or ex_jump;

  -- PCWriteBack: only JAL/JALR return address (PC+4)
  -- AUIPC result goes through the consolidated ALUOut mux below instead
  s_PCWriteBack_EX <= ex_PCInc;

  -- Consolidated ALUOut mux: AUIPC uses BranchJumpAdded, all others use ALUOut
  -- This signal is what enters EX/MEM ALUOut and serves as the forwarding source
  AUIPCConsolMux: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S  => ex_AUIPC,
             i_D0 => s_ALUOut_EX,       -- normal ALU result
             i_D1 => s_BranchJumpAdded, -- AUIPC: PC + Imm
             o_O  => s_ALUOut_Consol);
             
  -- Need to also consolidate with LUI Imm value so that the same value can be forwarded without
  -- Additional complexity to Hazard and Forwarding units
  LUIALUConsolMux: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S  => s_LUI_Inst,
             i_D0 => s_ALUOut_Consol,       -- normal ALU result
             i_D1 => ex_Imm, -- AUIPC: PC + Imm
             o_O  => s_LUIALU_Consol);	
 

  -- Imm passthrough EX -> MEM (for LUI in WB)
  -- Follows EX/MEM stall bit so it stalls in sync with the rest of EX/MEM
  s_Imm_EX <= ex_Imm;

  reg_Imm_EX_MEM: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => x"00000000")
    port map(i_CLK => iCLK, i_RST => iRST,
             i_WE  => s_EXMEM_WE,
             i_D   => s_Imm_EX,
             o_Q   => s_Imm_MEM);

  ---------------------------------------------------------------------------
  -- EX/MEM REGISTER
  -- ALUOut input is now the consolidated signal (covers ALU and AUIPC)
  -- PCWriteBack carries only the JAL/JALR return address
  -- WE from stall[1], squash from squash[1] (always 0 currently)
  ---------------------------------------------------------------------------
  EXMEM_reg: EX_MEM
    generic map(
      NOP_INST        => x"00000033", NOP_PCWRITEBACK => (others => '0'),
      NOP_ALUOUT      => (others => '0'), NOP_RS2DATA => (others => '0'),
      NOP_MEMWRITE    => "0",         NOP_BYTEOP   => (others => '0'),
      NOP_REGWRITE    => "0",         NOP_WRBCKSEL => (others => '0'),
      NOP_HALTFLAG    => "0")
    port map(
      i_CLK         => iCLK,          i_RST         => iRST,
      i_WE          => s_EXMEM_WE,    i_Squash      => s_Squash(1),
      i_Inst        => ex_Inst,
      i_PCWriteBack => s_PCWriteBack_EX,
      i_ALUOut      => s_LUIALU_Consol,  -- consolidated ALU/AUIPC/LUI result
      i_RS2Data     => ex_RS2Data,
      i_memWrite    => ex_memWrite,    i_byteOp      => ex_byteOp,
      i_regWrite    => ex_regWrite,    i_WRBCKSEL    => ex_WRBCKSEL,
      i_haltFlag    => ex_haltFlag,
      o_Inst        => mem_Inst,
      o_PCWriteBack => mem_PCWriteBack,
      o_ALUOut      => mem_ALUOut,
      o_RS2Data     => mem_RS2Data,
      o_memWrite    => mem_memWrite,   o_byteOp      => mem_byteOp,
      o_regWrite    => mem_regWrite,   o_WRBCKSEL    => mem_WRBCKSEL,
      o_haltFlag    => mem_haltFlag);

  ---------------------------------------------------------------------------
  -- MEMORY STAGE
  ---------------------------------------------------------------------------
  ByteModule: byteMd
    port map(
      i_ByteOp   => mem_byteOp,
      i_ByteAddr => mem_ALUOut(1 downto 0),
      i_mem      => s_DMemOut,
      i_RS2      => mem_RS2Data,
      o_ByteOut  => s_ByteOut_MEM);

  s_DMemData <= s_ByteOut_MEM;

  ---------------------------------------------------------------------------
  -- MEM/WB REGISTER
  -- WE from stall[0], squash from squash[0] (always 0 currently)
  ---------------------------------------------------------------------------
  MEMWB_reg: MEM_WB
    generic map(
      NOP_INST        => x"00000033", NOP_PCWRITEBACK => (others => '0'),
      NOP_ALUOUT      => (others => '0'), NOP_BYTEOUT => (others => '0'),
      NOP_IMM         => (others => '0'), NOP_REGWRITE => "0",
      NOP_WRBCKSEL    => (others => '0'), NOP_HALTFLAG => "0")
    port map(
      i_CLK         => iCLK,       i_RST         => iRST,
      i_WE          => s_MEMWB_WE, i_Squash      => s_Squash(0),
      i_Inst        => mem_Inst,
      i_PCWriteBack => mem_PCWriteBack,
      i_ALUOut      => mem_ALUOut,
      i_ByteOut     => s_ByteOut_MEM,
      i_Imm         => s_Imm_MEM,
      i_regWrite    => mem_regWrite,  i_WRBCKSEL => mem_WRBCKSEL,
      i_haltFlag    => mem_haltFlag,
      o_Inst        => wb_Inst,
      o_PCWriteBack => wb_PCWriteBack,
      o_ALUOut      => wb_ALUOut,
      o_ByteOut     => wb_ByteOut,
      o_Imm         => wb_Imm,
      o_regWrite    => wb_regWrite,   o_WRBCKSEL => wb_WRBCKSEL,
      o_Halt        => s_Halt);

  ---------------------------------------------------------------------------
  -- WRITEBACK STAGE
  ---------------------------------------------------------------------------
  WriteBackMux: mux4t1_N
    generic map(N => DATA_WIDTH)
    port map(
      i_S  => wb_WRBCKSEL,
      i_D0 => wb_PCWriteBack,  -- JAL/JALR return address
      i_D1 => wb_Imm,          -- LUI
      i_D2 => wb_ByteOut,      -- load
      i_D3 => wb_ALUOut,       -- ALU / AUIPC result
      o_O  => s_RegWrData);

end structure;
