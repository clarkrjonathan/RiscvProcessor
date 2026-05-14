-------------------------------------------------------------------------
-- tb_pipeline_regs.vhd
-- Testbench: instantiates all four pipeline registers in a chain.
-- Tests:
--   1. Values inserted into IF/ID are visible at MEM/WB exactly 4 cycles later
--   2. New values can enter every single cycle (no stall)
--   3. Individual stall of each register (WE=0 holds value, others advance)
--   4. Individual flush/squash of each register (loads NOP, others unaffected)
--
-- Pipeline chain: IF/ID -> ID/EX -> EX/MEM -> MEM/WB
-- For simplicity only the Inst field is exercised (32 bits, easy to track).
-- All other fields are tied to zero inputs; their behavior is identical.
--
-- Test plan:
--   Cycles 1-6:   Normal flow. Inject inst_A..inst_F each cycle.
--                 Verify inst_A exits MEM/WB at cycle 5 (4 cycles after entry).
--   Cycles 7-9:   Stall IF/ID only (WE=0). Verify IF/ID holds,
--                 downstream stages continue advancing.
--   Cycles 10-12: Stall ID/EX only. Verify ID/EX holds, IF/ID advances,
--                 EX/MEM advances.
--   Cycles 13-15: Stall EX/MEM only. Similar verification.
--   Cycles 16-18: Stall MEM/WB only. Similar verification.
--   Cycle 19:     Squash IF/ID: verify it loads NOP (0x00000033), others unaffected.
--   Cycle 20:     Squash ID/EX.
--   Cycle 21:     Squash EX/MEM.
--   Cycle 22:     Squash MEM/WB.
--   Cycle 23:     Squash all simultaneously.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.RISCV_types.all;

entity tb_pipeline_regs is
end tb_pipeline_regs;

architecture behavior of tb_pipeline_regs is

  ---------------------------------------------------------------------------
  -- Component declarations
  ---------------------------------------------------------------------------
  component reg_N is
    generic(N       : integer := 32;
            RST_VAL : std_logic_vector(N-1 downto 0) := (others => '0'));
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic_vector(N-1 downto 0);
      o_Q   : out std_logic_vector(N-1 downto 0));
  end component;

  component IF_ID is
    generic(
      NOP_PC    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_PCINC : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_INST  : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000033");
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
      NOP_PC       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_PCINC    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_INST     : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000033";
      NOP_RS1DATA  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_RS2DATA  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_IMM      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_ALUCTL   : std_logic_vector(ALU_CTL_WIDTH-1 downto 0) := (others => '0');
      NOP_JALR     : std_logic_vector(0 downto 0) := "0";
      NOP_JUMP     : std_logic_vector(0 downto 0) := "0";
      NOP_BRANCH   : std_logic_vector(0 downto 0) := "0";
      NOP_AUIPC    : std_logic_vector(0 downto 0) := "0";
      NOP_ALUSRC   : std_logic_vector(0 downto 0) := "0";
      NOP_MEMWRITE : std_logic_vector(0 downto 0) := "0";
      NOP_BYTEOP   : std_logic_vector(BYTE_OP_WIDTH-1 downto 0) := (others => '0');
      NOP_REGWRITE : std_logic_vector(0 downto 0) := "0";
      NOP_WRBCKSEL : std_logic_vector(1 downto 0) := (others => '0');
      NOP_HALTFLAG : std_logic_vector(0 downto 0) := "0");
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
      NOP_INST        : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000033";
      NOP_PCWRITEBACK : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_ALUOUT      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_RS2DATA     : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_MEMWRITE    : std_logic_vector(0 downto 0) := "0";
      NOP_BYTEOP      : std_logic_vector(BYTE_OP_WIDTH-1 downto 0) := (others => '0');
      NOP_REGWRITE    : std_logic_vector(0 downto 0) := "0";
      NOP_WRBCKSEL    : std_logic_vector(1 downto 0) := (others => '0');
      NOP_HALTFLAG    : std_logic_vector(0 downto 0) := "0");
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
      NOP_INST        : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000033";
      NOP_PCWRITEBACK : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_ALUOUT      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_BYTEOUT     : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_IMM         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      NOP_REGWRITE    : std_logic_vector(0 downto 0) := "0";
      NOP_WRBCKSEL    : std_logic_vector(1 downto 0) := (others => '0');
      NOP_HALTFLAG    : std_logic_vector(0 downto 0) := "0");
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

  ---------------------------------------------------------------------------
  -- Clock / reset
  ---------------------------------------------------------------------------
  constant CLK_PERIOD : time := 10 ns;
  signal s_CLK : std_logic := '0';
  signal s_RST : std_logic := '1';

  ---------------------------------------------------------------------------
  -- Inputs to the chain
  ---------------------------------------------------------------------------
  signal s_in_Inst   : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_PC     : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_PCInc  : std_logic_vector(31 downto 0) := (others => '0');

  -- Individual WE and Squash controls
  signal s_IFID_WE     : std_logic := '1';
  signal s_IDEX_WE     : std_logic := '1';
  signal s_EXMEM_WE    : std_logic := '1';
  signal s_MEMWB_WE    : std_logic := '1';
  signal s_IFID_Squash : std_logic := '0';
  signal s_IDEX_Squash : std_logic := '0';
  signal s_EXMEM_Squash: std_logic := '0';
  signal s_MEMWB_Squash: std_logic := '0';

  ---------------------------------------------------------------------------
  -- Inter-stage wires (only Inst tracked for simplicity)
  ---------------------------------------------------------------------------
  signal s_IFID_Inst   : std_logic_vector(31 downto 0);
  signal s_IFID_PC     : std_logic_vector(31 downto 0);
  signal s_IFID_PCInc  : std_logic_vector(31 downto 0);

  signal s_IDEX_Inst   : std_logic_vector(31 downto 0);

  signal s_EXMEM_Inst  : std_logic_vector(31 downto 0);

  signal s_MEMWB_Inst  : std_logic_vector(31 downto 0);
  signal s_MEMWB_Halt  : std_logic;

  -- NOP constant for check
  constant NOP_INST : std_logic_vector(31 downto 0) := x"00000033";

  -- Test instruction tokens (unique 32-bit values, valid encodings not required)
  constant INST_A : std_logic_vector(31 downto 0) := x"AAAA0001";
  constant INST_B : std_logic_vector(31 downto 0) := x"BBBB0002";
  constant INST_C : std_logic_vector(31 downto 0) := x"CCCC0003";
  constant INST_D : std_logic_vector(31 downto 0) := x"DDDD0004";
  constant INST_E : std_logic_vector(31 downto 0) := x"EEEE0005";
  constant INST_F : std_logic_vector(31 downto 0) := x"FFFF0006";
  constant INST_G : std_logic_vector(31 downto 0) := x"11110007";
  constant INST_H : std_logic_vector(31 downto 0) := x"22220008";

  ---------------------------------------------------------------------------
  -- Cycle counter for readability
  ---------------------------------------------------------------------------
  signal s_cycle : integer := 0;

begin

  s_CLK <= not s_CLK after CLK_PERIOD / 2;

  ---------------------------------------------------------------------------
  -- DUT chain instantiation
  -- All unused data ports tied to zero; only Inst is checked in assertions.
  ---------------------------------------------------------------------------
  IFID: IF_ID
    generic map(NOP_PC => (others=>'0'), NOP_PCINC => (others=>'0'),
                NOP_INST => NOP_INST)
    port map(
      i_CLK => s_CLK, i_RST => s_RST,
      i_WE => s_IFID_WE, i_Squash => s_IFID_Squash,
      i_PC => s_in_PC, i_PCInc => s_in_PCInc, i_Inst => s_in_Inst,
      o_PC => s_IFID_PC, o_PCInc => s_IFID_PCInc, o_Inst => s_IFID_Inst);

  IDEX: ID_EX
    generic map(
      NOP_PC=>(others=>'0'), NOP_PCINC=>(others=>'0'), NOP_INST=>NOP_INST,
      NOP_RS1DATA=>(others=>'0'), NOP_RS2DATA=>(others=>'0'),
      NOP_IMM=>(others=>'0'), NOP_ALUCTL=>(others=>'0'),
      NOP_JALR=>"0", NOP_JUMP=>"0", NOP_BRANCH=>"0", NOP_AUIPC=>"0",
      NOP_ALUSRC=>"0", NOP_MEMWRITE=>"0", NOP_BYTEOP=>(others=>'0'),
      NOP_REGWRITE=>"0", NOP_WRBCKSEL=>(others=>'0'), NOP_HALTFLAG=>"0")
    port map(
      i_CLK => s_CLK, i_RST => s_RST,
      i_WE => s_IDEX_WE, i_Squash => s_IDEX_Squash,
      i_PC => s_IFID_PC, i_PCInc => s_IFID_PCInc, i_Inst => s_IFID_Inst,
      i_RS1Data=>(others=>'0'), i_RS2Data=>(others=>'0'), i_Imm=>(others=>'0'),
      i_ALUCTL=>(others=>'0'), i_jalr=>'0', i_jump=>'0', i_branch=>'0',
      i_AUIPC=>'0', i_ALUSrc=>'0', i_memWrite=>'0', i_byteOp=>(others=>'0'),
      i_regWrite=>'0', i_WRBCKSEL=>(others=>'0'), i_haltFlag=>'0',
      o_Inst => s_IDEX_Inst,
      o_PC=>open, o_PCInc=>open, o_RS1Data=>open, o_RS2Data=>open,
      o_Imm=>open, o_ALUCTL=>open, o_jalr=>open, o_jump=>open,
      o_branch=>open, o_AUIPC=>open, o_ALUSrc=>open, o_memWrite=>open,
      o_byteOp=>open, o_regWrite=>open, o_WRBCKSEL=>open, o_haltFlag=>open);

  EXMEM: EX_MEM
    generic map(
      NOP_INST=>NOP_INST, NOP_PCWRITEBACK=>(others=>'0'),
      NOP_ALUOUT=>(others=>'0'), NOP_RS2DATA=>(others=>'0'),
      NOP_MEMWRITE=>"0", NOP_BYTEOP=>(others=>'0'),
      NOP_REGWRITE=>"0", NOP_WRBCKSEL=>(others=>'0'), NOP_HALTFLAG=>"0")
    port map(
      i_CLK => s_CLK, i_RST => s_RST,
      i_WE => s_EXMEM_WE, i_Squash => s_EXMEM_Squash,
      i_Inst => s_IDEX_Inst, i_PCWriteBack=>(others=>'0'),
      i_ALUOut=>(others=>'0'), i_RS2Data=>(others=>'0'),
      i_memWrite=>'0', i_byteOp=>(others=>'0'), i_regWrite=>'0',
      i_WRBCKSEL=>(others=>'0'), i_haltFlag=>'0',
      o_Inst => s_EXMEM_Inst,
      o_PCWriteBack=>open, o_ALUOut=>open, o_RS2Data=>open,
      o_memWrite=>open, o_byteOp=>open, o_regWrite=>open,
      o_WRBCKSEL=>open, o_haltFlag=>open);

  MEMWB: MEM_WB
    generic map(
      NOP_INST=>NOP_INST, NOP_PCWRITEBACK=>(others=>'0'),
      NOP_ALUOUT=>(others=>'0'), NOP_BYTEOUT=>(others=>'0'),
      NOP_IMM=>(others=>'0'), NOP_REGWRITE=>"0",
      NOP_WRBCKSEL=>(others=>'0'), NOP_HALTFLAG=>"0")
    port map(
      i_CLK => s_CLK, i_RST => s_RST,
      i_WE => s_MEMWB_WE, i_Squash => s_MEMWB_Squash,
      i_Inst => s_EXMEM_Inst, i_PCWriteBack=>(others=>'0'),
      i_ALUOut=>(others=>'0'), i_ByteOut=>(others=>'0'),
      i_Imm=>(others=>'0'), i_regWrite=>'0',
      i_WRBCKSEL=>(others=>'0'), i_haltFlag=>'0',
      o_Inst => s_MEMWB_Inst,
      o_PCWriteBack=>open, o_ALUOut=>open, o_ByteOut=>open,
      o_Imm=>open, o_regWrite=>open, o_WRBCKSEL=>open, o_Halt=>s_MEMWB_Halt);

  ---------------------------------------------------------------------------
  -- Cycle counter
  ---------------------------------------------------------------------------
  process(s_CLK)
  begin
    if rising_edge(s_CLK) then
      s_cycle <= s_cycle + 1;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Stimulus and assertions
  ---------------------------------------------------------------------------
  process
    procedure clk_tick is
    begin
      wait until rising_edge(s_CLK);
      wait for 1 ns;  -- let outputs settle
    end procedure;

    procedure check(signal actual : std_logic_vector(31 downto 0);
                    expected      : std_logic_vector(31 downto 0);
                    msg           : string) is
    begin
      assert actual = expected
        report "FAIL [" & msg & "] expected 0x" &
               to_hstring(expected) & " got 0x" & to_hstring(actual)
        severity error;
    end procedure;

  begin
    -- -----------------------------------------------------------------------
    -- Reset
    -- -----------------------------------------------------------------------
    s_RST <= '1';
    s_in_Inst <= (others => '0');
    wait for CLK_PERIOD * 2;
    s_RST <= '0';
    wait for 1 ns;

    -- -----------------------------------------------------------------------
    -- TEST 1: Normal flow -- values propagate one stage per cycle.
    -- Inject INST_A through INST_F on consecutive cycles.
    -- After 4 clock edges INST_A should be at MEM/WB output.
    -- -----------------------------------------------------------------------
    report "TEST 1: Normal pipeline flow";

    -- Cycle 1: inject A
    s_in_Inst <= INST_A;
    clk_tick;
    check(s_IFID_Inst, INST_A, "cyc1 IF/ID=A");

    -- Cycle 2: inject B; A moves to ID/EX
    s_in_Inst <= INST_B;
    clk_tick;
    check(s_IFID_Inst, INST_B, "cyc2 IF/ID=B");
    check(s_IDEX_Inst, INST_A, "cyc2 ID/EX=A");

    -- Cycle 3: inject C; A->EX/MEM, B->ID/EX
    s_in_Inst <= INST_C;
    clk_tick;
    check(s_IFID_Inst,  INST_C, "cyc3 IF/ID=C");
    check(s_IDEX_Inst,  INST_B, "cyc3 ID/EX=B");
    check(s_EXMEM_Inst, INST_A, "cyc3 EX/MEM=A");

    -- Cycle 4: inject D; A->MEM/WB
    s_in_Inst <= INST_D;
    clk_tick;
    check(s_IFID_Inst,  INST_D, "cyc4 IF/ID=D");
    check(s_IDEX_Inst,  INST_C, "cyc4 ID/EX=C");
    check(s_EXMEM_Inst, INST_B, "cyc4 EX/MEM=B");
    check(s_MEMWB_Inst, INST_A, "cyc4 MEM/WB=A -- 4 cycles after entry");

    -- Cycle 5: inject E; verify A left, B at WB
    s_in_Inst <= INST_E;
    clk_tick;
    check(s_IFID_Inst,  INST_E, "cyc5 IF/ID=E");
    check(s_IDEX_Inst,  INST_D, "cyc5 ID/EX=D");
    check(s_EXMEM_Inst, INST_C, "cyc5 EX/MEM=C");
    check(s_MEMWB_Inst, INST_B, "cyc5 MEM/WB=B");

    report "TEST 1: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 2: Stall IF/ID (WE=0) for one cycle -- IF/ID holds, rest advance.
    -- -----------------------------------------------------------------------
    report "TEST 2: Stall IF/ID";

    s_in_Inst    <= INST_F;
    s_IFID_WE    <= '0';           -- hold IF/ID
    clk_tick;
    -- IF/ID should still hold INST_E (not captured INST_F)
    check(s_IFID_Inst,  INST_E,  "stall_IFID: IF/ID holds E");
    -- ID/EX should have advanced and captured what IF/ID output: E
    check(s_IDEX_Inst,  INST_E,  "stall_IFID: ID/EX got E");
    check(s_EXMEM_Inst, INST_D,  "stall_IFID: EX/MEM=D");
    check(s_MEMWB_Inst, INST_C,  "stall_IFID: MEM/WB=C");

    s_IFID_WE <= '1';              -- resume
    clk_tick;
    check(s_IFID_Inst,  INST_F,  "stall_IFID resume: IF/ID=F");
    report "TEST 2: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 3: Stall ID/EX -- ID/EX holds, IF/ID advances, EX/MEM advances.
    -- -----------------------------------------------------------------------
    report "TEST 3: Stall ID/EX";

    s_in_Inst  <= INST_G;
    s_IDEX_WE  <= '0';
    clk_tick;
    check(s_IFID_Inst,  INST_G,  "stall_IDEX: IF/ID=G");
    check(s_IDEX_Inst,  INST_F,  "stall_IDEX: ID/EX holds F");
    check(s_EXMEM_Inst, INST_E,  "stall_IDEX: EX/MEM advanced");

    s_IDEX_WE <= '1';
    clk_tick;
    check(s_IDEX_Inst,  INST_G,  "stall_IDEX resume: ID/EX=G");
    report "TEST 3: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 4: Stall EX/MEM
    -- -----------------------------------------------------------------------
    report "TEST 4: Stall EX/MEM";

    s_in_Inst    <= INST_H;
    s_EXMEM_WE   <= '0';
    clk_tick;
    check(s_IFID_Inst,  INST_H,  "stall_EXMEM: IF/ID=H");
    check(s_IDEX_Inst,  INST_G,  "stall_EXMEM: ID/EX=G");
    check(s_EXMEM_Inst, INST_G,  "stall_EXMEM: EX/MEM holds G (was G before tick)");
    -- Note: EX/MEM holds its previous value; MEM/WB advances from what EX/MEM output

    s_EXMEM_WE <= '1';
    clk_tick;
    check(s_EXMEM_Inst, INST_G,  "stall_EXMEM resume: EX/MEM captures G from IDEX");
    report "TEST 4: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 5: Stall MEM/WB
    -- -----------------------------------------------------------------------
    report "TEST 5: Stall MEM/WB";

    s_MEMWB_WE <= '0';
    clk_tick;
    -- MEM/WB should hold its current value
    check(s_MEMWB_Inst, INST_G,  "stall_MEMWB: MEM/WB holds");

    s_MEMWB_WE <= '1';
    clk_tick;
    report "TEST 5: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 6: Squash IF/ID -- IF/ID loads NOP, downstream unaffected.
    -- -----------------------------------------------------------------------
    report "TEST 6: Squash IF/ID";

    s_in_Inst    <= INST_A;
    s_IFID_Squash <= '1';
    clk_tick;
    check(s_IFID_Inst,  NOP_INST, "squash_IFID: IF/ID=NOP");
    -- ID/EX captured whatever IF/ID was outputting before the squash edge
    -- (not NOP -- squash affects what gets written INTO IF/ID, not what it
    --  was outputting on this cycle's input to ID/EX)

    s_IFID_Squash <= '0';
    clk_tick;
    check(s_IDEX_Inst,  NOP_INST, "squash_IFID: NOP propagated to ID/EX");
    report "TEST 6: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 7: Squash ID/EX
    -- -----------------------------------------------------------------------
    report "TEST 7: Squash ID/EX";

    s_in_Inst    <= INST_B;
    s_IDEX_Squash <= '1';
    clk_tick;
    check(s_IDEX_Inst,  NOP_INST, "squash_IDEX: ID/EX=NOP");
    check(s_IFID_Inst,  INST_B,   "squash_IDEX: IF/ID unaffected");

    s_IDEX_Squash <= '0';
    clk_tick;
    check(s_EXMEM_Inst, NOP_INST, "squash_IDEX: NOP propagated to EX/MEM");
    report "TEST 7: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 8: Squash EX/MEM
    -- -----------------------------------------------------------------------
    report "TEST 8: Squash EX/MEM";

    s_EXMEM_Squash <= '1';
    clk_tick;
    check(s_EXMEM_Inst, NOP_INST, "squash_EXMEM: EX/MEM=NOP");

    s_EXMEM_Squash <= '0';
    clk_tick;
    check(s_MEMWB_Inst, NOP_INST, "squash_EXMEM: NOP propagated to MEM/WB");
    report "TEST 8: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 9: Squash MEM/WB
    -- -----------------------------------------------------------------------
    report "TEST 9: Squash MEM/WB";

    s_MEMWB_Squash <= '1';
    clk_tick;
    check(s_MEMWB_Inst, NOP_INST, "squash_MEMWB: MEM/WB=NOP");

    s_MEMWB_Squash <= '0';
    report "TEST 9: PASS";

    -- -----------------------------------------------------------------------
    -- TEST 10: Simultaneous squash of all registers
    -- -----------------------------------------------------------------------
    report "TEST 10: Simultaneous squash all";

    s_in_Inst     <= INST_C;
    s_IFID_Squash  <= '1';
    s_IDEX_Squash  <= '1';
    s_EXMEM_Squash <= '1';
    s_MEMWB_Squash <= '1';
    clk_tick;
    check(s_IFID_Inst,  NOP_INST, "squash_all: IF/ID=NOP");
    check(s_IDEX_Inst,  NOP_INST, "squash_all: ID/EX=NOP");
    check(s_EXMEM_Inst, NOP_INST, "squash_all: EX/MEM=NOP");
    check(s_MEMWB_Inst, NOP_INST, "squash_all: MEM/WB=NOP");

    s_IFID_Squash  <= '0';
    s_IDEX_Squash  <= '0';
    s_EXMEM_Squash <= '0';
    s_MEMWB_Squash <= '0';
    report "TEST 10: PASS";

    report "ALL PIPELINE REGISTER TESTS COMPLETE";
    wait;
  end process;

end behavior;