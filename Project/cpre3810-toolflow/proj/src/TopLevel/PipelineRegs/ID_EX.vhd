-------------------------------------------------------------------------
-- ID_EX.vhd  --  ID/EX Pipeline Register
--
-- Forwarding is handled UPSTREAM of this register by the forwarding_unit
-- mux in the decode stage. This register simply stores whatever RS1Data
-- and RS2Data it receives -- no per-field WE override needed.
--
-- Fields:
--   Data:    PC(32), PCInc(32), Inst(32), RS1Data(32), RS2Data(32), Imm(32)
--   Control: ALUCTL(9), jalr(1), jump(1), branch(1), AUIPC(1), ALUSrc(1),
--            memWrite(1), byteOp(4), regWrite(1), WRBCKSEL(2), haltFlag(1)
--
-- For software-scheduled use: tie i_WE='1', i_Squash='0'.
-- For hardware hazard use:
--   i_WE driven by NOT(stall[2]) from hazard unit
--   i_Squash driven by squash[2] from hazard unit
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.RISCV_types.all;

entity ID_EX is
  generic(
    NOP_PC       : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_PCINC    : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_INST     : std_logic_vector(DATA_WIDTH-1 downto 0)    := x"00000033";
    NOP_RS1DATA  : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_RS2DATA  : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_IMM      : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_ALUCTL   : std_logic_vector(ALU_CTL_WIDTH-1 downto 0) := (others => '0');
    NOP_JALR     : std_logic_vector(0 downto 0)               := "0";
    NOP_JUMP     : std_logic_vector(0 downto 0)               := "0";
    NOP_BRANCH   : std_logic_vector(0 downto 0)               := "0";
    NOP_AUIPC    : std_logic_vector(0 downto 0)               := "0";
    NOP_ALUSRC   : std_logic_vector(0 downto 0)               := "0";
    NOP_MEMWRITE : std_logic_vector(0 downto 0)               := "0";
    NOP_BYTEOP   : std_logic_vector(BYTE_OP_WIDTH-1 downto 0) := (others => '0');
    NOP_REGWRITE : std_logic_vector(0 downto 0)               := "0";
    NOP_WRBCKSEL : std_logic_vector(1 downto 0)               := (others => '0');
    NOP_HALTFLAG : std_logic_vector(0 downto 0)               := "0"
  );
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
    o_haltFlag : out std_logic
  );
end ID_EX;

architecture structure of ID_EX is

  component reg_N is
    generic(N       : integer := 32;
            RST_VAL : std_logic_vector := (0 => '0'));
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic_vector(N-1 downto 0);
      o_Q   : out std_logic_vector(N-1 downto 0)
    );
  end component;

  -- Squash-muxed D inputs
  signal s_D_PC       : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_PCInc    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_Inst     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_RS1Data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_RS2Data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_Imm      : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_ALUCTL   : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
  signal s_D_jalr     : std_logic_vector(0 downto 0);
  signal s_D_jump     : std_logic_vector(0 downto 0);
  signal s_D_branch   : std_logic_vector(0 downto 0);
  signal s_D_AUIPC    : std_logic_vector(0 downto 0);
  signal s_D_ALUSrc   : std_logic_vector(0 downto 0);
  signal s_D_memWrite : std_logic_vector(0 downto 0);
  signal s_D_byteOp   : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
  signal s_D_regWrite : std_logic_vector(0 downto 0);
  signal s_D_WRBCKSEL : std_logic_vector(1 downto 0);
  signal s_D_haltFlag : std_logic_vector(0 downto 0);

  -- reg_N output wires for 1-bit fields
  signal s_Q_jalr     : std_logic_vector(0 downto 0);
  signal s_Q_jump     : std_logic_vector(0 downto 0);
  signal s_Q_branch   : std_logic_vector(0 downto 0);
  signal s_Q_AUIPC    : std_logic_vector(0 downto 0);
  signal s_Q_ALUSrc   : std_logic_vector(0 downto 0);
  signal s_Q_memWrite : std_logic_vector(0 downto 0);
  signal s_Q_regWrite : std_logic_vector(0 downto 0);
  signal s_Q_haltFlag : std_logic_vector(0 downto 0);

begin

  -- Squash mux: select NOP constants when i_Squash='1'
  s_D_PC       <= NOP_PC       when i_Squash = '1' else i_PC;
  s_D_PCInc    <= NOP_PCINC    when i_Squash = '1' else i_PCInc;
  s_D_Inst     <= NOP_INST     when i_Squash = '1' else i_Inst;
  s_D_RS1Data  <= NOP_RS1DATA  when i_Squash = '1' else i_RS1Data;
  s_D_RS2Data  <= NOP_RS2DATA  when i_Squash = '1' else i_RS2Data;
  s_D_Imm      <= NOP_IMM      when i_Squash = '1' else i_Imm;
  s_D_ALUCTL   <= NOP_ALUCTL   when i_Squash = '1' else i_ALUCTL;
  s_D_jalr     <= NOP_JALR     when i_Squash = '1' else (0 => i_jalr);
  s_D_jump     <= NOP_JUMP     when i_Squash = '1' else (0 => i_jump);
  s_D_branch   <= NOP_BRANCH   when i_Squash = '1' else (0 => i_branch);
  s_D_AUIPC    <= NOP_AUIPC    when i_Squash = '1' else (0 => i_AUIPC);
  s_D_ALUSrc   <= NOP_ALUSRC   when i_Squash = '1' else (0 => i_ALUSrc);
  s_D_memWrite <= NOP_MEMWRITE when i_Squash = '1' else (0 => i_memWrite);
  s_D_byteOp   <= NOP_BYTEOP   when i_Squash = '1' else i_byteOp;
  s_D_regWrite <= NOP_REGWRITE when i_Squash = '1' else (0 => i_regWrite);
  s_D_WRBCKSEL <= NOP_WRBCKSEL when i_Squash = '1' else i_WRBCKSEL;
  s_D_haltFlag <= NOP_HALTFLAG when i_Squash = '1' else (0 => i_haltFlag);

  -- Register instantiations
  reg_PC: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_PC)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_PC, o_Q => o_PC);

  reg_PCInc: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_PCINC)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_PCInc, o_Q => o_PCInc);

  reg_Inst: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_INST)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_Inst, o_Q => o_Inst);

  reg_RS1Data: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_RS1DATA)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_RS1Data, o_Q => o_RS1Data);

  reg_RS2Data: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_RS2DATA)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_RS2Data, o_Q => o_RS2Data);

  reg_Imm: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_IMM)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_Imm, o_Q => o_Imm);

  reg_ALUCTL: reg_N
    generic map(N => ALU_CTL_WIDTH, RST_VAL => NOP_ALUCTL)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_ALUCTL, o_Q => o_ALUCTL);

  reg_jalr: reg_N
    generic map(N => 1, RST_VAL => NOP_JALR)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_jalr, o_Q => s_Q_jalr);
  o_jalr <= s_Q_jalr(0);

  reg_jump: reg_N
    generic map(N => 1, RST_VAL => NOP_JUMP)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_jump, o_Q => s_Q_jump);
  o_jump <= s_Q_jump(0);

  reg_branch: reg_N
    generic map(N => 1, RST_VAL => NOP_BRANCH)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_branch, o_Q => s_Q_branch);
  o_branch <= s_Q_branch(0);

  reg_AUIPC: reg_N
    generic map(N => 1, RST_VAL => NOP_AUIPC)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_AUIPC, o_Q => s_Q_AUIPC);
  o_AUIPC <= s_Q_AUIPC(0);

  reg_ALUSrc: reg_N
    generic map(N => 1, RST_VAL => NOP_ALUSRC)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_ALUSrc, o_Q => s_Q_ALUSrc);
  o_ALUSrc <= s_Q_ALUSrc(0);

  reg_memWrite: reg_N
    generic map(N => 1, RST_VAL => NOP_MEMWRITE)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_memWrite, o_Q => s_Q_memWrite);
  o_memWrite <= s_Q_memWrite(0);

  reg_byteOp: reg_N
    generic map(N => BYTE_OP_WIDTH, RST_VAL => NOP_BYTEOP)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_byteOp, o_Q => o_byteOp);

  reg_regWrite: reg_N
    generic map(N => 1, RST_VAL => NOP_REGWRITE)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_regWrite, o_Q => s_Q_regWrite);
  o_regWrite <= s_Q_regWrite(0);

  reg_WRBCKSEL: reg_N
    generic map(N => 2, RST_VAL => NOP_WRBCKSEL)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_WRBCKSEL, o_Q => o_WRBCKSEL);

  reg_haltFlag: reg_N
    generic map(N => 1, RST_VAL => NOP_HALTFLAG)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_haltFlag, o_Q => s_Q_haltFlag);
  o_haltFlag <= s_Q_haltFlag(0);

end structure;
