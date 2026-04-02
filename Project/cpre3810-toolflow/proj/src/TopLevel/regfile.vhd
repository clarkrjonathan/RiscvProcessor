library IEEE;
use IEEE.std_logic_1164.all;

entity regfile is
  port(
    i_CLK      : in  std_logic;                      -- Clock
    i_RST      : in  std_logic;                      -- Reset
    i_WE       : in  std_logic;                      -- Write enable
    i_WR_ADDR  : in  std_logic_vector(4 downto 0);   -- Write address (rd)
    i_WR_DATA  : in  std_logic_vector(31 downto 0);  -- Write data
    i_RD_ADDR1 : in  std_logic_vector(4 downto 0);   -- Read address 1 (rs1)
    i_RD_ADDR2 : in  std_logic_vector(4 downto 0);   -- Read address 2 (rs2)
    o_RD_DATA1 : out std_logic_vector(31 downto 0);  -- Read data 1
    o_RD_DATA2 : out std_logic_vector(31 downto 0)   -- Read data 2
  );
end regfile;

architecture structural of regfile is
  
  -- Component: N-bit register
  component reg_N
    generic(N : integer := 32;
    	    RST_VAL	:	std_logic_vector(N-1 downto 0) := (others => '0'));
    port(
      i_CLK : in  std_logic;
      i_RST : in  std_logic;
      i_WE  : in  std_logic;
      i_D   : in  std_logic_vector(N-1 downto 0);
      o_Q   : out std_logic_vector(N-1 downto 0)
    );
  end component;
  
  -- Component: 5:32 decoder
  component decoder5to32
    port(
      i_EN : in  std_logic;
      i_A  : in  std_logic_vector(4 downto 0);
      o_Y  : out std_logic_vector(31 downto 0)
    );
  end component;
  
  -- Component: 32:1 32-bit mux
  component mux_32to1_32bit
    port(
      in0, in1, in2, in3, in4, in5, in6, in7     : in  std_logic_vector(31 downto 0);
      in8, in9, in10, in11, in12, in13, in14, in15 : in  std_logic_vector(31 downto 0);
      in16, in17, in18, in19, in20, in21, in22, in23 : in  std_logic_vector(31 downto 0);
      in24, in25, in26, in27, in28, in29, in30, in31 : in  std_logic_vector(31 downto 0);
      sel  : in  std_logic_vector(4 downto 0);
      dout : out std_logic_vector(31 downto 0)
    );
  end component;
  
  -- Type for array of 32-bit vectors
  type reg_array is array (0 to 31) of std_logic_vector(31 downto 0);
  
  -- Internal signals
  signal s_reg_write_en : std_logic_vector(31 downto 0);  -- Individual write enables
  signal s_reg_data : reg_array;  -- Register outputs
  
begin
  
  -- Decoder: Generate individual write enables for each register
  DECODER: decoder5to32
    port map(
      i_EN => i_WE,
      i_A  => i_WR_ADDR,
      o_Y  => s_reg_write_en
    );
  
  -- Register 0: Hardwired to zero (reset always active)
  REG_0: reg_N
    generic map(N => 32)
    port map(
      i_CLK => i_CLK,
      i_RST => '1',              -- Always in reset to maintain zero
      i_WE  => '0',              -- Never write
      i_D   => (others => '0'),
      o_Q   => s_reg_data(0)
    );
  
  -- Registers 1-31: Normal registers
  GEN_REGS: for i in 1 to 31 generate
    REG_I: reg_N
      generic map(N => 32)
      port map(
        i_CLK => i_CLK,
        i_RST => i_RST,
        i_WE  => s_reg_write_en(i),
        i_D   => i_WR_DATA,
        o_Q   => s_reg_data(i)
      );
  end generate GEN_REGS;
  
  -- Read Port 1: Mux for rs1
  MUX_RS1: mux_32to1_32bit
    port map(
      in0  => s_reg_data(0),  in1  => s_reg_data(1),
      in2  => s_reg_data(2),  in3  => s_reg_data(3),
      in4  => s_reg_data(4),  in5  => s_reg_data(5),
      in6  => s_reg_data(6),  in7  => s_reg_data(7),
      in8  => s_reg_data(8),  in9  => s_reg_data(9),
      in10 => s_reg_data(10), in11 => s_reg_data(11),
      in12 => s_reg_data(12), in13 => s_reg_data(13),
      in14 => s_reg_data(14), in15 => s_reg_data(15),
      in16 => s_reg_data(16), in17 => s_reg_data(17),
      in18 => s_reg_data(18), in19 => s_reg_data(19),
      in20 => s_reg_data(20), in21 => s_reg_data(21),
      in22 => s_reg_data(22), in23 => s_reg_data(23),
      in24 => s_reg_data(24), in25 => s_reg_data(25),
      in26 => s_reg_data(26), in27 => s_reg_data(27),
      in28 => s_reg_data(28), in29 => s_reg_data(29),
      in30 => s_reg_data(30), in31 => s_reg_data(31),
      sel  => i_RD_ADDR1,
      dout => o_RD_DATA1
    );
  
  -- Read Port 2: Mux for rs2
  MUX_RS2: mux_32to1_32bit
    port map(
      in0  => s_reg_data(0),  in1  => s_reg_data(1),
      in2  => s_reg_data(2),  in3  => s_reg_data(3),
      in4  => s_reg_data(4),  in5  => s_reg_data(5),
      in6  => s_reg_data(6),  in7  => s_reg_data(7),
      in8  => s_reg_data(8),  in9  => s_reg_data(9),
      in10 => s_reg_data(10), in11 => s_reg_data(11),
      in12 => s_reg_data(12), in13 => s_reg_data(13),
      in14 => s_reg_data(14), in15 => s_reg_data(15),
      in16 => s_reg_data(16), in17 => s_reg_data(17),
      in18 => s_reg_data(18), in19 => s_reg_data(19),
      in20 => s_reg_data(20), in21 => s_reg_data(21),
      in22 => s_reg_data(22), in23 => s_reg_data(23),
      in24 => s_reg_data(24), in25 => s_reg_data(25),
      in26 => s_reg_data(26), in27 => s_reg_data(27),
      in28 => s_reg_data(28), in29 => s_reg_data(29),
      in30 => s_reg_data(30), in31 => s_reg_data(31),
      sel  => i_RD_ADDR2,
      dout => o_RD_DATA2
    );
  
end structural;
