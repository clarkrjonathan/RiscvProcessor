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
    	    RST_VAL : std_logic_vector := (0 => '0'));
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
  
  -- Component: 2:1 32-bit mux (used for write-forwarding bypass)
  component mux2t1_N
    generic(N : integer := 32);
    port(
      i_S  : in  std_logic;
      i_D0 : in  std_logic_vector(N-1 downto 0);
      i_D1 : in  std_logic_vector(N-1 downto 0);
      o_O  : out std_logic_vector(N-1 downto 0)
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
  signal s_reg_data     : reg_array;  -- Raw register outputs (from reg_N)
  signal s_reg_out      : reg_array;  -- Post-bypass mux outputs (fed to read muxes)
  signal s_SpWriteEnable : std_logic;
  
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
    generic map(N => 32, RST_VAL => x"00000000")
    port map(
      i_CLK => i_CLK,
      i_RST => '1',              -- Always in reset to maintain zero
      i_WE  => '1',              -- Never write
      i_D   => (others => '0'),
      o_Q   => s_reg_data(0)
    );
    
    s_SpWriteEnable <= s_reg_write_en(2) when i_RST = '0' else '1';
  
	GEN_REGS: for i in 1 to 31 generate

	    REG_SP: if i = 2 generate
		REG_I: reg_N
		    generic map(
		        N       => 32,
		        RST_VAL => x"7FFFEFFC"
		    )
		    port map(
		        i_CLK => i_CLK,
		        i_RST => i_RST,
		        i_WE  => s_SpWriteEnable,
		        i_D   => i_WR_DATA,
		        o_Q   => s_reg_data(i)
		    );
	    end generate REG_SP;

	    REG_NORMAL: if i /= 2 generate
		REG_I: reg_N
		    generic map(N => 32, RST_VAL => x"00000000")
		    port map(
		        i_CLK => i_CLK,
		        i_RST => i_RST,
		        i_WE  => s_reg_write_en(i),
		        i_D   => i_WR_DATA,
		        o_Q   => s_reg_data(i)
		    );
	    end generate REG_NORMAL;

	end generate GEN_REGS;

  ---------------------------------------------------------------------------
  -- Write-forwarding bypass muxes
  -- For registers 1-31: when the write enable for that register is asserted,
  -- the read output returns i_WR_DATA directly rather than the stored value.
  -- This implements same-cycle write-to-read forwarding so that a WB write
  -- and an ID read of the same register in the same cycle returns the new value.
  -- Register 0 is hardwired zero -- no bypass, always reads s_reg_data(0).
  ---------------------------------------------------------------------------

  -- x0: no bypass, always zero
  s_reg_out(0) <= s_reg_data(0);

  -- Registers 1-31: bypass mux selects write data when write enable is asserted
  GEN_BYPASS: for i in 1 to 31 generate
    BYPASS_MUX: mux2t1_N
      generic map(N => 32)
      port map(
        i_S  => s_reg_write_en(i),  -- WE for this register: '1' = forward write data
        i_D0 => s_reg_data(i),      -- normal: stored register value
        i_D1 => i_WR_DATA,          -- bypass: value being written this cycle
        o_O  => s_reg_out(i)
      );
  end generate GEN_BYPASS;
  
  -- Read Port 1: Mux for rs1
  MUX_RS1: mux_32to1_32bit
    port map(
      in0  => s_reg_out(0),  in1  => s_reg_out(1),
      in2  => s_reg_out(2),  in3  => s_reg_out(3),
      in4  => s_reg_out(4),  in5  => s_reg_out(5),
      in6  => s_reg_out(6),  in7  => s_reg_out(7),
      in8  => s_reg_out(8),  in9  => s_reg_out(9),
      in10 => s_reg_out(10), in11 => s_reg_out(11),
      in12 => s_reg_out(12), in13 => s_reg_out(13),
      in14 => s_reg_out(14), in15 => s_reg_out(15),
      in16 => s_reg_out(16), in17 => s_reg_out(17),
      in18 => s_reg_out(18), in19 => s_reg_out(19),
      in20 => s_reg_out(20), in21 => s_reg_out(21),
      in22 => s_reg_out(22), in23 => s_reg_out(23),
      in24 => s_reg_out(24), in25 => s_reg_out(25),
      in26 => s_reg_out(26), in27 => s_reg_out(27),
      in28 => s_reg_out(28), in29 => s_reg_out(29),
      in30 => s_reg_out(30), in31 => s_reg_out(31),
      sel  => i_RD_ADDR1,
      dout => o_RD_DATA1
    );
  
  -- Read Port 2: Mux for rs2
  MUX_RS2: mux_32to1_32bit
    port map(
      in0  => s_reg_out(0),  in1  => s_reg_out(1),
      in2  => s_reg_out(2),  in3  => s_reg_out(3),
      in4  => s_reg_out(4),  in5  => s_reg_out(5),
      in6  => s_reg_out(6),  in7  => s_reg_out(7),
      in8  => s_reg_out(8),  in9  => s_reg_out(9),
      in10 => s_reg_out(10), in11 => s_reg_out(11),
      in12 => s_reg_out(12), in13 => s_reg_out(13),
      in14 => s_reg_out(14), in15 => s_reg_out(15),
      in16 => s_reg_out(16), in17 => s_reg_out(17),
      in18 => s_reg_out(18), in19 => s_reg_out(19),
      in20 => s_reg_out(20), in21 => s_reg_out(21),
      in22 => s_reg_out(22), in23 => s_reg_out(23),
      in24 => s_reg_out(24), in25 => s_reg_out(25),
      in26 => s_reg_out(26), in27 => s_reg_out(27),
      in28 => s_reg_out(28), in29 => s_reg_out(29),
      in30 => s_reg_out(30), in31 => s_reg_out(31),
      sel  => i_RD_ADDR2,
      dout => o_RD_DATA2
    );
  
end structural;
