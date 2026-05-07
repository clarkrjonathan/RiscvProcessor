-------------------------------------------------------------------------
-- EX_MEM.vhd  --  EX/MEM Pipeline Register
--
-- Fields:
--   Data:    Inst(32), PCWriteBack(32), ALUOut(32), RS2Data(32)
--   Control: memWrite(1), byteOp(4), regWrite(1), WRBCKSEL(2), haltFlag(1)
--
-- No forwarding targets in this register.
-- For software-scheduled use: tie i_WE='1', i_Squash='0'.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.RISCV_types.all;

entity EX_MEM is
  generic(
    NOP_INST        : std_logic_vector(DATA_WIDTH-1 downto 0)    := x"00000033";
    NOP_PCWRITEBACK : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_ALUOUT      : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_RS2DATA     : std_logic_vector(DATA_WIDTH-1 downto 0)    := (others => '0');
    NOP_MEMWRITE    : std_logic_vector(0 downto 0)               := "0";
    NOP_BYTEOP      : std_logic_vector(BYTE_OP_WIDTH-1 downto 0) := (others => '0');
    NOP_REGWRITE    : std_logic_vector(0 downto 0)               := "0";
    NOP_WRBCKSEL    : std_logic_vector(1 downto 0)               := (others => '0');
    NOP_HALTFLAG    : std_logic_vector(0 downto 0)               := "0"
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
end EX_MEM;

architecture structure of EX_MEM is

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

  signal s_D_Inst        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_PCWriteBack : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_ALUOut      : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_RS2Data     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_memWrite    : std_logic_vector(0 downto 0);
  signal s_D_byteOp      : std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
  signal s_D_regWrite    : std_logic_vector(0 downto 0);
  signal s_D_WRBCKSEL    : std_logic_vector(1 downto 0);
  signal s_D_haltFlag    : std_logic_vector(0 downto 0);

  signal s_Q_memWrite    : std_logic_vector(0 downto 0);
  signal s_Q_regWrite    : std_logic_vector(0 downto 0);
  signal s_Q_haltFlag    : std_logic_vector(0 downto 0);

begin

  s_D_Inst        <= NOP_INST        when i_Squash = '1' else i_Inst;
  s_D_PCWriteBack <= NOP_PCWRITEBACK when i_Squash = '1' else i_PCWriteBack;
  s_D_ALUOut      <= NOP_ALUOUT      when i_Squash = '1' else i_ALUOut;
  s_D_RS2Data     <= NOP_RS2DATA     when i_Squash = '1' else i_RS2Data;
  s_D_memWrite    <= NOP_MEMWRITE    when i_Squash = '1' else (0 => i_memWrite);
  s_D_byteOp      <= NOP_BYTEOP      when i_Squash = '1' else i_byteOp;
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

  reg_RS2Data: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_RS2DATA)
    port map(i_CLK => i_CLK, i_RST => i_RST, i_WE => i_WE,
             i_D => s_D_RS2Data, o_Q => o_RS2Data);

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
