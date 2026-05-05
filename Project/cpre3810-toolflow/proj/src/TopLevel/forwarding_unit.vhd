-------------------------------------------------------------------------
-- forwarding_unit.vhd
--
-- Sits in the Decode stage, between the register file read ports and the
-- ID/EX register data inputs. Selects the correct RS1 and RS2 values to
-- feed into ID/EX based on forwarding control signals from the hazard
-- detection unit.
--
-- Forwarding control vector (3 bits per RS, from hazard_detect):
--   bit 2     = forward enable ('1' = use forwarded value)
--   bits 1:0  = source select:
--     "00" = EX ALUOut      (combinatorial ALU result, inst finishing EX)
--     "01" = EX/MEM ALUOut  (consolidated: covers ALU result and AUIPC)
--     "10" = MEM ByteOut    (byte module output, inst finishing MEM / load)
--
-- When forward enable is '0', the register file read data passes through
-- unchanged regardless of the source select bits.
--
-- This is a purely combinatorial module -- no registers, no clock.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.RISCV_types.all;

entity forwarding_unit is
  port(
    -- Forwarding control from hazard detection unit
    i_FWD_RS1      : in  std_logic_vector(2 downto 0);  -- {en, src[1:0]}
    i_FWD_RS2      : in  std_logic_vector(2 downto 0);

    -- Register file read outputs (the baseline values)
    i_RS1_RegFile  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    i_RS2_RegFile  : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Forwarding sources
    i_EX_ALUOut    : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- from EX stage
    i_EXMEM_ALUOut : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- from EX/MEM reg
    i_MEM_ByteOut  : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- from MEM byte mod

    -- Muxed outputs to ID/EX register inputs
    o_RS1Data      : out std_logic_vector(DATA_WIDTH-1 downto 0);
    o_RS2Data      : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end forwarding_unit;

architecture structure of forwarding_unit is

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

  component mux2t1_N is
    generic(N : integer := DATA_WIDTH);
    port(
      i_S  : in  std_logic;
      i_D0 : in  std_logic_vector(N-1 downto 0);
      i_D1 : in  std_logic_vector(N-1 downto 0);
      o_O  : out std_logic_vector(N-1 downto 0)
    );
  end component;

  -- Source mux outputs (before enable gate)
  signal s_RS1_fwd_val : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal s_RS2_fwd_val : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  ---------------------------------------------------------------------------
  -- RS1 forwarding
  --
  -- Stage 1: 4-to-1 mux selects among the 3 forwarding sources.
  --   D0 = EX ALUOut      (src "00")
  --   D1 = EX/MEM ALUOut  (src "01")
  --   D2 = MEM ByteOut    (src "10")
  --   D3 = unused         (src "11", ties to EX/MEM as safe default)
  --
  -- Stage 2: 2-to-1 mux gates on forward enable.
  --   enable='0' -> pass register file value through
  --   enable='1' -> use selected forwarding source
  ---------------------------------------------------------------------------
  RS1_src_mux: mux4t1_N
    generic map(N => DATA_WIDTH)
    port map(
      i_S  => i_FWD_RS1(1 downto 0),
      i_D0 => i_EX_ALUOut,
      i_D1 => i_EXMEM_ALUOut,
      i_D2 => i_MEM_ByteOut,
      i_D3 => i_EXMEM_ALUOut,   -- "11" unused; tie to EXMEM as safe default
      o_O  => s_RS1_fwd_val);

  RS1_en_mux: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(
      i_S  => i_FWD_RS1(2),     -- forward enable bit
      i_D0 => i_RS1_RegFile,    -- no forward: use register file
      i_D1 => s_RS1_fwd_val,    -- forward: use selected source
      o_O  => o_RS1Data);

  ---------------------------------------------------------------------------
  -- RS2 forwarding (identical structure to RS1)
  ---------------------------------------------------------------------------
  RS2_src_mux: mux4t1_N
    generic map(N => DATA_WIDTH)
    port map(
      i_S  => i_FWD_RS2(1 downto 0),
      i_D0 => i_EX_ALUOut,
      i_D1 => i_EXMEM_ALUOut,
      i_D2 => i_MEM_ByteOut,
      i_D3 => i_EXMEM_ALUOut,
      o_O  => s_RS2_fwd_val);

  RS2_en_mux: mux2t1_N
    generic map(N => DATA_WIDTH)
    port map(
      i_S  => i_FWD_RS2(2),
      i_D0 => i_RS2_RegFile,
      i_D1 => s_RS2_fwd_val,
      o_O  => o_RS2Data);

end structure;