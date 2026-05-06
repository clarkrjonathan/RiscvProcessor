-------------------------------------------------------------------------
-- MEM_WB.vhd  --  MEM/WB Pipeline Register
--
-- Fields:
--   Data:    Inst(32), PCWriteBack(32), ALUOut(32), ByteOut(32), Imm(32)
--   Control: regWrite(1), WRBCKSEL(2)
--
-- haltFlag becomes o_Halt directly here -- it is the only stage that
-- drives the real s_Halt simulation signal.
--
-- No forwarding targets in this register.
-- For software-scheduled use: tie i_WE='1', i_Squash='0'.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.RISCV_types.all;

entity MEM_WB is
  generic(
    NOP_INST        : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000033";
    NOP_PCWRITEBACK : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    NOP_ALUOUT      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    NOP_BYTEOUT     : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    NOP_IMM         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    NOP_REGWRITE    : std_logic_vector(0 downto 0)            := "0";
    NOP_WRBCKSEL    : std_logic_vector(1 downto 0)            := (others => '0');
    NOP_HALTFLAG    : std_logic_vector(0 downto 0)            := "0"
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
    o_Halt        : out std_logic   -- only here does haltFlag become s_Halt
  );
end MEM_WB;

architecture structure of MEM_WB is

  component reg_N is
    generic(N       : integer := 32;
            RST_VAL : std_logic_vector := (others => '0'));
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic_vector(N-1 downto 0);
      o_Q   : out std_logic_vector(N-1 downto 0)
    );
  end component;

  signal s_D_Inst        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_PCWriteBack : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_ALUOut      : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_ByteOut     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_Imm         : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_regWrite    : std_logic_vector(0 downto 0);
  signal s_D_WRBCKSEL    : std_logic_vector(1 downto 0);
  signal s_D_haltFlag    : std_logic_vector(0 downto 0);

  signal s_Q_regWrite    : std_logic_vector(0 downto 0);
  signal s_Q_haltFlag    : std_logic_vector(0 downto 0);

begin

  s_D_Inst        <= NOP_INST        when i_Squash = '1' else i_Inst;
  s_D_PCWriteBack <= NOP_PCWRITEBACK when i_Squash = '1' else i_PCWriteBack;
  s_D_ALUOut      <= NOP_ALUOUT      when i_Squash = '1' else i_ALUOut;
  s_D_ByteOut     <= NOP_BYTEOUT     when i_Squash = '1' else i_ByteOut;
  s_D_Imm         <= NOP_IMM         when i_Squash = '1' else i_Imm;
  s_D_regWrite    <= NOP_REGWRITE    when i_Squash = '1' else (0 => i_regWrite);
  s_D_WRBCKSEL    <= NOP_WRBCKSEL    when i_Squash = '1' else i_WRBCKSEL;
  s_D_haltFlag    <= NOP_HALTFLAG    when i_Squash = '1' else (0 => i_haltFlag);

  reg_Inst: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_INST)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_Inst, o_Q => o_Inst);

  reg_PCWriteBack: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_PCWRITEBACK)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_PCWriteBack, o_Q => o_PCWriteBack);

  reg_ALUOut: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_ALUOUT)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_ALUOut, o_Q => o_ALUOut);

  reg_ByteOut: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_BYTEOUT)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_ByteOut, o_Q => o_ByteOut);

  reg_Imm: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_IMM)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_Imm, o_Q => o_Imm);

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
  o_Halt <= s_Q_haltFlag(0);

end structure;
