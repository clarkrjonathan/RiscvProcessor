-------------------------------------------------------------------------
-- RISCV_Processor.vhd  --  5-Stage Pipelined RISC-V Processor
--
-- Stages: IF | ID | EX | MEM | WB
--
-- This is the SOFTWARE-SCHEDULED version.
-- Hazard handling: programmer inserts NOPs. No hardware hazard detection.
-- Pipeline register stall/squash ports are tied inactive.
--
-- Branch/Jump resolution: Execute stage.
--   s_BranchJump is combinatorial from EX; feeds back directly to the
--   BranchIncSel mux in Fetch. The PC register segments EX from IMem,
--   so there is no critical path interaction. 2-bubble penalty.
--   IF/ID and ID/EX are squashed on the clock edge that loads the new PC.
--
-- Register file: read in ID (from IF/ID.Inst), write in WB (from MEM_WB).
--   Write address = MEM_WB.Inst[11:7]
--   Read addresses = IF_ID.Inst[19:15], IF_ID.Inst[24:20]
--
-- ALUCtl: in Decode (ID), output registered into ID/EX.
-- ImmGen: in Decode (ID), output registered into ID/EX.
-- BranchJumpAdder: in Execute (EX), takes PC and Imm from ID/EX.
--   Input A muxed between ID_EX.PC (PC-relative) and ID_EX.RS1Data (JALR).
-- PCWriteBack (AUIPC mux): in Execute, result registered into EX/MEM.
-- ByteModule: in Memory (MEM), after DMem read, before MEM/WB.
-- WriteBackMux: in Writeback (WB), selects from MEM_WB fields.
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
      o_RD_DATA2 : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  component reg_N is
    generic(N       : integer := DATA_WIDTH;
            RST_VAL : std_logic_vector := (others => '0'));
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic_vector(N-1 downto 0);
      o_Q   : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component mux2t1_N is
    generic(N : integer := DATA_WIDTH);
    port(
      i_S  : in  std_logic;
      i_D0 : in  std_logic_vector(N-1 downto 0);
      i_D1 : in  std_logic_vector(N-1 downto 0);
      o_O  : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component mux4t1_N is
    generic(N : integer := DATA_WIDTH);
    port(
      i_S  : in  std_logic_vector(1 downto 0);
      i_D0 : in  std_logic_vector(N-1 downto 0);
      i_D1 : in  std_logic_vector(N-1 downto 0);
      i_D2 : in  std_logic_vector(N-1 downto 0);
      i_D3 : in  std_logic_vector(N-1 downto 0);
      o_O  : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component byteMd is
    port(
      i_ByteOp  : in  std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      i_ByteAddr: in  std_logic_vector(1 downto 0);
      i_mem     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS2     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_ByteOut : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  component immGen is
    port(
      i_Inst : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Imm  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

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

  component ALU is
    port(
      i_A      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_B      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_ALUCTL : in  std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
      o_Zero   : out std_logic;
      o_Output : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  component ALUCtl is
    port(
      i_ALUOp  : in  std_logic_vector(ALU_OP_WIDTH-1 downto 0);
      o_ALUCTL : out std_logic_vector(ALU_CTL_WIDTH-1 downto 0)
    );
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
      o_memWrite: out std_logic
    );
  end component;

  component xorg2 is
    port(
      i_A : in  std_logic;
      i_B : in  std_logic;
      o_F : out std_logic
    );
  end component;

  -- Pipeline register components
  component IF_ID is
    generic(
      NOP_PC    : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_PCINC : std_logic_vector(DATA_WIDTH-1 downto 0);
      NOP_INST  : std_logic_vector(DATA_WIDTH-1 downto 0)
    );
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
      o_Inst   : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
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
      NOP_HALTFLAG : std_logic_vector(0 downto 0)
    );
    port(
      i_CLK         : in  std_logic;
      i_RST         : in  std_logic;
      i_WE          : in  std_logic;
      i_Squash      : in  std_logic;
      i_PC          : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_PCInc       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_Inst        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS1Data     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_RS2Data     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_Imm         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_ALUCTL      : in  std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
      i_jalr        : in  std_logic;
      i_jump        : in  std_logic;
      i_branch      : in  std_logic;
      i_AUIPC       : in  std_logic;
      i_ALUSrc      : in  std_logic;
      i_memWrite    : in  std_logic;
      i_byteOp      : in  std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      i_regWrite    : in  std_logic;
      i_WRBCKSEL    : in  std_logic_vector(1 downto 0);
      i_haltFlag    : in  std_logic;
      i_FWD_RS1_EN  : in  std_logic;
      i_FWD_RS1Data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      i_FWD_RS2_EN  : in  std_logic;
      i_FWD_RS2Data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      o_PC          : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_PCInc       : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Inst        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RS1Data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_RS2Data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_Imm         : out std_logic_vector(DATA_WIDTH-1 downto 0);
      o_ALUCTL      : out std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
      o_jalr        : out std_logic;
      o_jump        : out std_logic;
      o_branch      : out std_logic;
      o_AUIPC       : out std_logic;
      o_ALUSrc      : out std_logic;
      o_memWrite    : out std_logic;
      o_byteOp      : out std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
      o_regWrite    : out std_logic;
      o_WRBCKSEL    : out std_logic_vector(1 downto 0);
      o_haltFlag    : out std_logic
    );
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
      NOP_HALTFLAG    : std_logic_vector(0 downto 0)
    );
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
      o_haltFlag    : out std_logic
    );
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
      NOP_HALTFLAG    : std_logic_vector(0 downto 0)
    );
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
      o_Halt        : out std_logic
    );
  end component;

  ---------------------------------------------------------------------------
  -- Required signals
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
  signal s_Inst      : std_logic_vector(N-1 downto 0);  -- raw IMem output
  signal s_Halt      : std_logic;
  signal s_Ovfl      : std_logic;

  ---------------------------------------------------------------------------
  -- FETCH stage signals
  ---------------------------------------------------------------------------
  signal s_IncPC          : std_logic_vector(N-1 downto 0);
  signal s_PCFetch        : std_logic_vector(N-1 downto 0);
  -- Branch feedback from EX (combinatorial, crosses back to fetch mux)
  signal s_BranchJump_EX  : std_logic;
  signal s_BranchTarget   : std_logic_vector(N-1 downto 0); -- EX adder result

  ---------------------------------------------------------------------------
  -- IF/ID register outputs  (prefix: id_)
  ---------------------------------------------------------------------------
  signal id_PC    : std_logic_vector(N-1 downto 0);
  signal id_PCInc : std_logic_vector(N-1 downto 0);
  signal id_Inst  : std_logic_vector(N-1 downto 0);

  -- Squash IF/ID and ID/EX when branch/jump resolves in EX
  signal s_IF_ID_Squash : std_logic;
  signal s_ID_EX_Squash : std_logic;

  ---------------------------------------------------------------------------
  -- DECODE stage signals  (combinatorial, feed into ID/EX)
  ---------------------------------------------------------------------------
  signal s_RS1Data  : std_logic_vector(N-1 downto 0);
  signal s_RS2Data  : std_logic_vector(N-1 downto 0);
  signal s_Imm      : std_logic_vector(N-1 downto 0);
  signal s_ALUCTL   : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
  signal s_ALUOp    : std_logic_vector(ALU_OP_WIDTH-1 downto 0);
  -- Control outputs from decode (feed into ID/EX)
  signal s_jalr_d   : std_logic;
  signal s_jump_d   : std_logic;
  signal s_branch_d : std_logic;
  signal s_WRBCKSEL_d: std_logic_vector(1 downto 0);
  signal s_byteOp_d : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
  signal s_AUIPC_d  : std_logic;
  signal s_ALUSrc_d : std_logic;
  signal s_haltFlag_d: std_logic;
  signal s_memWrite_d: std_logic;
  signal s_regWrite_d: std_logic;

  ---------------------------------------------------------------------------
  -- ID/EX register outputs  (prefix: ex_)
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
  signal s_ALU_A        : std_logic_vector(N-1 downto 0); -- RS1 or PC
  signal s_ALU_B        : std_logic_vector(N-1 downto 0); -- RS2 or Imm
  signal s_ALUOut_EX    : std_logic_vector(N-1 downto 0);
  signal s_ALUZero_EX   : std_logic;
  signal s_CondMet_EX   : std_logic;
  signal s_PCWriteBack_EX: std_logic_vector(N-1 downto 0);
  -- BranchJumpAdder
  signal s_BJAdder_A    : std_logic_vector(N-1 downto 0); -- PC or RS1
  signal s_BranchJumpAdded: std_logic_vector(N-1 downto 0);

  ---------------------------------------------------------------------------
  -- EX/MEM register outputs  (prefix: mem_)
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
  signal s_ByteOut_MEM  : std_logic_vector(N-1 downto 0);
  -- Imm must pass through EX/MEM to reach WB for LUI.
  -- We carry it as a passthrough in EX_MEM by adding it as a registered
  -- field. However, since EX_MEM does not have an Imm port in our register
  -- module, we route it separately using a plain reg_N passthrough.
  signal s_Imm_EX       : std_logic_vector(N-1 downto 0); -- = ex_Imm, alias
  signal s_Imm_MEM      : std_logic_vector(N-1 downto 0); -- registered EX->MEM

  ---------------------------------------------------------------------------
  -- MEM/WB register outputs  (prefix: wb_)
  ---------------------------------------------------------------------------
  signal wb_Inst        : std_logic_vector(N-1 downto 0);
  signal wb_PCWriteBack : std_logic_vector(N-1 downto 0);
  signal wb_ALUOut      : std_logic_vector(N-1 downto 0);
  signal wb_ByteOut     : std_logic_vector(N-1 downto 0);
  signal wb_Imm         : std_logic_vector(N-1 downto 0);
  signal wb_regWrite    : std_logic;
  signal wb_WRBCKSEL    : std_logic_vector(1 downto 0);

begin

  s_Ovfl <= '0'; -- RISC-V has no hardware overflow

  ---------------------------------------------------------------------------
  -- INSTRUCTION MEMORY
  ---------------------------------------------------------------------------
  with iInstLd select
    s_IMemAddr <= s_PC when '0',
                  iInstAddr when others;

  IMem: mem
    generic map(ADDR_WIDTH => ADDR_WIDTH, DATA_WIDTH => N)
    port map(clk  => iCLK,
             addr => s_IMemAddr(11 downto 2),
             data => iInstExt,
             we   => iInstLd,
             q    => s_Inst);

  ---------------------------------------------------------------------------
  -- DATA MEMORY
  -- Address and write enable come from EX/MEM register outputs.
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
  -- PC register, PC+4 adder, BranchIncSel mux.
  -- Branch target fed back combinatorially from EX.
  ---------------------------------------------------------------------------

  -- PC+4
  PCIncAdder: adder_N
    generic map(N => DATA_WIDTH)
    port map(iA   => s_PC,
             iB   => std_logic_vector(to_unsigned(4, 32)),
             iCin => '0',
             oS   => s_IncPC,
             oCout => open);

  -- Select next PC: sequential or branch/jump target from EX
  BranchIncSel: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S  => s_BranchJump_EX,
             i_D0 => s_IncPC,
             i_D1 => s_BranchTarget,   -- combinatorial from EX adder
             o_O  => s_PCFetch);

  ProgramCounter: reg_N
    generic map(N => 32, RST_VAL => x"00400000")
    port map(i_CLK => iCLK,
             i_RST => iRST,
             i_WE  => '1',             -- always running in SW-scheduled mode
             i_D   => s_PCFetch,
             o_Q   => s_PC);

  ---------------------------------------------------------------------------
  -- IF/ID REGISTER
  -- Squashed when a branch/jump resolves in EX (2-bubble penalty).
  -- WE tied '1' for software-scheduled version.
  ---------------------------------------------------------------------------
  s_IF_ID_Squash <= s_BranchJump_EX;

  IFID_reg: IF_ID
    generic map(
      NOP_PC    => (others => '0'),
      NOP_PCINC => (others => '0'),
      NOP_INST  => x"00000033")
    port map(
      i_CLK    => iCLK,
      i_RST    => iRST,
      i_WE     => '1',
      i_Squash => s_IF_ID_Squash,
      i_PC     => s_PC,
      i_PCInc  => s_IncPC,
      i_Inst   => s_Inst,
      o_PC     => id_PC,
      o_PCInc  => id_PCInc,
      o_Inst   => id_Inst);

  ---------------------------------------------------------------------------
  -- DECODE STAGE
  -- Control, ImmGen, ALUCtl, RegFile read all operate on id_Inst.
  -- RegFile write port driven by WB outputs.
  ---------------------------------------------------------------------------

  -- Write-back address and data (WB stage drives register file write port)
  s_RegWrAddr <= wb_Inst(11 downto 7);
  s_RegWr     <= wb_regWrite;

  ControlMod: control
    port map(
      i_Inst     => id_Inst,
      o_jalr     => s_jalr_d,
      o_jump     => s_jump_d,
      o_regWrite => s_regWrite_d,
      o_branch   => s_branch_d,
      o_WRBCKSEL => s_WRBCKSEL_d,
      o_byteOp   => s_byteOp_d,
      o_ALUOp    => s_ALUOp,
      o_AUIPC    => s_AUIPC_d,
      o_ALUSrc   => s_ALUSrc_d,
      o_HaltS    => s_haltFlag_d,
      o_memWrite => s_memWrite_d);

  ImmediateGen: immGen
    port map(i_Inst => id_Inst, o_Imm => s_Imm);

  ALUControl: ALUCtl
    port map(i_ALUOp => s_ALUOp, o_ALUCTL => s_ALUCTL);

  RegisterFile: regfile
    port map(
      i_CLK      => iCLK,
      i_RST      => iRST,
      i_WE       => s_RegWr,
      i_WR_ADDR  => s_RegWrAddr,
      i_WR_DATA  => s_RegWrData,
      i_RD_ADDR1 => id_Inst(19 downto 15),
      i_RD_ADDR2 => id_Inst(24 downto 20),
      o_RD_DATA1 => s_RS1Data,
      o_RD_DATA2 => s_RS2Data);

  ---------------------------------------------------------------------------
  -- ID/EX REGISTER
  -- Squashed on branch/jump resolve (same cycle as IF/ID squash).
  -- Forwarding ports tied inactive for SW-scheduled version.
  ---------------------------------------------------------------------------
  s_ID_EX_Squash <= s_BranchJump_EX;

  IDEX_reg: ID_EX
    generic map(
      NOP_PC       => (others => '0'),
      NOP_PCINC    => (others => '0'),
      NOP_INST     => x"00000033",
      NOP_RS1DATA  => (others => '0'),
      NOP_RS2DATA  => (others => '0'),
      NOP_IMM      => (others => '0'),
      NOP_ALUCTL   => (others => '0'),
      NOP_JALR     => "0",
      NOP_JUMP     => "0",
      NOP_BRANCH   => "0",
      NOP_AUIPC    => "0",
      NOP_ALUSRC   => "0",
      NOP_MEMWRITE => "0",
      NOP_BYTEOP   => (others => '0'),
      NOP_REGWRITE => "0",
      NOP_WRBCKSEL => (others => '0'),
      NOP_HALTFLAG => "0")
    port map(
      i_CLK         => iCLK,
      i_RST         => iRST,
      i_WE          => '1',
      i_Squash      => s_ID_EX_Squash,
      i_PC          => id_PC,
      i_PCInc       => id_PCInc,
      i_Inst        => id_Inst,
      i_RS1Data     => s_RS1Data,
      i_RS2Data     => s_RS2Data,
      i_Imm         => s_Imm,
      i_ALUCTL      => s_ALUCTL,
      i_jalr        => s_jalr_d,
      i_jump        => s_jump_d,
      i_branch      => s_branch_d,
      i_AUIPC       => s_AUIPC_d,
      i_ALUSrc      => s_ALUSrc_d,
      i_memWrite    => s_memWrite_d,
      i_byteOp      => s_byteOp_d,
      i_regWrite    => s_regWrite_d,
      i_WRBCKSEL    => s_WRBCKSEL_d,
      i_haltFlag    => s_haltFlag_d,
      -- Forwarding: tied off for SW-scheduled version
      i_FWD_RS1_EN  => '0',
      i_FWD_RS1Data => (others => '0'),
      i_FWD_RS2_EN  => '0',
      i_FWD_RS2Data => (others => '0'),
      o_PC          => ex_PC,
      o_PCInc       => ex_PCInc,
      o_Inst        => ex_Inst,
      o_RS1Data     => ex_RS1Data,
      o_RS2Data     => ex_RS2Data,
      o_Imm         => ex_Imm,
      o_ALUCTL      => ex_ALUCTL,
      o_jalr        => ex_jalr,
      o_jump        => ex_jump,
      o_branch      => ex_branch,
      o_AUIPC       => ex_AUIPC,
      o_ALUSrc      => ex_ALUSrc,
      o_memWrite    => ex_memWrite,
      o_byteOp      => ex_byteOp,
      o_regWrite    => ex_regWrite,
      o_WRBCKSEL    => ex_WRBCKSEL,
      o_haltFlag    => ex_haltFlag);

  ---------------------------------------------------------------------------
  -- EXECUTE STAGE
  --
  -- BranchJumpAdder: input A is RS1 (JALR) or PC (all others)
  -- ALU: input A is always RS1Data, input B is RS2Data or Imm
  -- PCWriteBack: PCInc (JAL/JALR return addr) or BranchJumpAdded (AUIPC)
  -- s_BranchJump_EX: combinatorial, feeds back to fetch this same cycle
  ---------------------------------------------------------------------------

  -- Mux adder input A: JALR uses RS1, everything else uses PC
  BranchJumpASel: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S  => ex_jalr,
             i_D0 => ex_PC,
             i_D1 => ex_RS1Data,
             o_O  => s_BJAdder_A);

  -- Branch/Jump target adder
  BranchJumpAdder: adder_N
    generic map(N => DATA_WIDTH)
    port map(iA   => s_BJAdder_A,
             iB   => ex_Imm,
             iCin => '0',
             oS   => s_BranchJumpAdded,
             oCout => open);

  -- Feed branch target back to fetch mux
  s_BranchTarget <= s_BranchJumpAdded;

  -- ALU source mux: RS2 or Imm
  ALUSourceMux: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S  => ex_ALUSrc,
             i_D0 => ex_RS2Data,
             i_D1 => ex_Imm,
             o_O  => s_ALU_B);

  -- ALU: input A is always RS1Data
  RISCVALU: ALU
    port map(i_A      => ex_RS1Data,
             i_B      => s_ALU_B,
             i_ALUCTL => ex_ALUCTL,
             o_Zero   => s_ALUZero_EX,
             o_Output => s_ALUOut_EX);

  oALUOut <= s_ALUOut_EX;

  -- Branch condition: XOR Zero with ALUCTL(0) to handle BNE/BLT/etc.
  ZeroXor: xorg2
    port map(i_A => s_ALUZero_EX,
             i_B => ex_ALUCTL(0),
             o_F => s_CondMet_EX);

  -- Branch/jump decision: combinatorial, fed back to fetch this cycle
  s_BranchJump_EX <= (s_CondMet_EX and ex_branch) or ex_jump;

  -- PCWriteBack mux: PCInc for JAL/JALR return address, BranchJumpAdded for AUIPC
  AUIPCMux: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(i_S  => ex_AUIPC,
             i_D0 => ex_PCInc,
             i_D1 => s_BranchJumpAdded,
             o_O  => s_PCWriteBack_EX);

  -- Imm passthrough EX -> MEM (for LUI writeback in WB)
  -- Carried as a separate reg_N since EX_MEM module doesn't have an Imm port
  s_Imm_EX <= ex_Imm;

  reg_Imm_EX_MEM: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => (DATA_WIDTH-1 downto 0 => '0'))
    port map(i_CLK => iCLK,
             i_RST => iRST,
             i_WE  => '1',
             i_D   => s_Imm_EX,
             o_Q   => s_Imm_MEM);

  ---------------------------------------------------------------------------
  -- EX/MEM REGISTER
  ---------------------------------------------------------------------------
  EXMEM_reg: EX_MEM
    generic map(
      NOP_INST        => x"00000033",
      NOP_PCWRITEBACK => (others => '0'),
      NOP_ALUOUT      => (others => '0'),
      NOP_RS2DATA     => (others => '0'),
      NOP_MEMWRITE    => "0",
      NOP_BYTEOP      => (others => '0'),
      NOP_REGWRITE    => "0",
      NOP_WRBCKSEL    => (others => '0'),
      NOP_HALTFLAG    => "0")
    port map(
      i_CLK         => iCLK,
      i_RST         => iRST,
      i_WE          => '1',
      i_Squash      => '0',           -- EX/MEM not squashed (EX completes normally)
      i_Inst        => ex_Inst,
      i_PCWriteBack => s_PCWriteBack_EX,
      i_ALUOut      => s_ALUOut_EX,
      i_RS2Data     => ex_RS2Data,
      i_memWrite    => ex_memWrite,
      i_byteOp      => ex_byteOp,
      i_regWrite    => ex_regWrite,
      i_WRBCKSEL    => ex_WRBCKSEL,
      i_haltFlag    => ex_haltFlag,
      o_Inst        => mem_Inst,
      o_PCWriteBack => mem_PCWriteBack,
      o_ALUOut      => mem_ALUOut,
      o_RS2Data     => mem_RS2Data,
      o_memWrite    => mem_memWrite,
      o_byteOp      => mem_byteOp,
      o_regWrite    => mem_regWrite,
      o_WRBCKSEL    => mem_WRBCKSEL,
      o_haltFlag    => mem_haltFlag);

  ---------------------------------------------------------------------------
  -- MEMORY STAGE
  -- Byte module runs after DMem read (loads) and provides write data (stores).
  -- ByteAddr comes from low 2 bits of ALUOut (memory address).
  ---------------------------------------------------------------------------
  ByteModule: byteMd
    port map(
      i_ByteOp   => mem_byteOp,
      i_ByteAddr => mem_ALUOut(1 downto 0),
      i_mem      => s_DMemOut,
      i_RS2      => mem_RS2Data,
      o_ByteOut  => s_ByteOut_MEM);

  -- Store byte/halfword: ByteOut feeds DMem data input
  s_DMemData <= s_ByteOut_MEM;

  ---------------------------------------------------------------------------
  -- MEM/WB REGISTER
  ---------------------------------------------------------------------------
  MEMWB_reg: MEM_WB
    generic map(
      NOP_INST        => x"00000033",
      NOP_PCWRITEBACK => (others => '0'),
      NOP_ALUOUT      => (others => '0'),
      NOP_BYTEOUT     => (others => '0'),
      NOP_IMM         => (others => '0'),
      NOP_REGWRITE    => "0",
      NOP_WRBCKSEL    => (others => '0'),
      NOP_HALTFLAG    => "0")
    port map(
      i_CLK         => iCLK,
      i_RST         => iRST,
      i_WE          => '1',
      i_Squash      => '0',
      i_Inst        => mem_Inst,
      i_PCWriteBack => mem_PCWriteBack,
      i_ALUOut      => mem_ALUOut,
      i_ByteOut     => s_ByteOut_MEM,
      i_Imm         => s_Imm_MEM,
      i_regWrite    => mem_regWrite,
      i_WRBCKSEL    => mem_WRBCKSEL,
      i_haltFlag    => mem_haltFlag,
      o_Inst        => wb_Inst,
      o_PCWriteBack => wb_PCWriteBack,
      o_ALUOut      => wb_ALUOut,
      o_ByteOut     => wb_ByteOut,
      o_Imm         => wb_Imm,
      o_regWrite    => wb_regWrite,
      o_WRBCKSEL    => wb_WRBCKSEL,
      o_Halt        => s_Halt);

  ---------------------------------------------------------------------------
  -- WRITEBACK STAGE
  -- 4-to-1 mux selects write data; address comes from WB instruction rd field.
  ---------------------------------------------------------------------------
  WriteBackMux: mux4t1_N
    generic map(N => DATA_WIDTH)
    port map(
      i_S  => wb_WRBCKSEL,
      i_D0 => wb_PCWriteBack,  -- JAL/JALR return address, or AUIPC result
      i_D1 => wb_Imm,          -- LUI
      i_D2 => wb_ByteOut,      -- load (byte/half/word)
      i_D3 => wb_ALUOut,       -- ALU result (R-type, I-type)
      o_O  => s_RegWrData);

end structure;
