-------------------------------------------------------------------------
-- IF_ID.vhd  --  IF/ID Pipeline Register
--
-- Fields:  PC (32), PCInc (32), Inst (32)
--
-- Squash: muxes NOP constants onto every D input before the register.
-- Stall:  i_WE = '0' holds all fields.
--
-- No forwarding targets in this register.
-- For software-scheduled use: tie i_WE='1', i_Squash='0'.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.RISCV_types.all;

entity IF_ID is
  generic(
    NOP_PC    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    NOP_PCINC : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    NOP_INST  : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000033"
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
end IF_ID;

architecture structure of IF_ID is

  component reg_N is
    generic(N       : integer := 32;
            RST_VAL : std_logic_vector(N-1 downto 0) := (others => '0'));
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic_vector(N-1 downto 0);
      o_Q   : out std_logic_vector(N-1 downto 0)
    );
  end component;

  signal s_D_PC    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_PCInc : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_D_Inst  : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  s_D_PC    <= NOP_PC    when i_Squash = '1' else i_PC;
  s_D_PCInc <= NOP_PCINC when i_Squash = '1' else i_PCInc;
  s_D_Inst  <= NOP_INST  when i_Squash = '1' else i_Inst;

  reg_PC: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_PC)
    port map(i_CLK => i_CLK, i_RST => i_RST,
             i_WE => i_WE, i_D => s_D_PC, o_Q => o_PC);

  reg_PCInc: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_PCINC)
    port map(i_CLK => i_CLK, i_RST => i_RST,
             i_WE => i_WE, i_D => s_D_PCInc, o_Q => o_PCInc);

  reg_Inst: reg_N
    generic map(N => DATA_WIDTH, RST_VAL => NOP_INST)
    port map(i_CLK => i_CLK, i_RST => i_RST,
             i_WE => i_WE, i_D => s_D_Inst, o_Q => o_Inst);

end structure;