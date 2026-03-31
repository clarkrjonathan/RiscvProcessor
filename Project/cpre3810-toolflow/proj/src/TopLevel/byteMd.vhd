library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

entity byteMd is
    port(
        i_ByteOp  : in  std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
        i_ByteAddr : in	std_logic_vector(1 downto 0);
        i_mem     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_RS2     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        o_ByteOut : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end byteMd;

architecture dataflow of byteMd is

signal s_SelectedMemByte		:	std_logic_vector(7 downto 0);
signal s_SelectedMemHalfword		:	std_logic_vector(15 downto 0);

begin

	--Maybe swap with 4t1 mux later to make tighter to hardware
	s_SelectedMemByte	<=
		i_mem(7 downto 0)
			when i_ByteAddr = "00" else
		i_mem(15 downto 8)
			when i_ByteAddr = "01" else
		i_mem(23 downto 16)
			when i_ByteAddr = "10" else
		i_mem(31 downto 24)
			when i_ByteAddr = "11" else
	(others => '0');
	
	s_SelectedMemHalfword	<=
		i_mem(15 downto 0)
			when i_ByteAddr(1) = '0' else
		i_mem(31 downto 16)
			when i_ByteAddr(1) = '1' else
	(others => '0');

	o_ByteOut 		<=
		-- STORES (bit 3 = 0, operate on i_RS2)
		-- sb: replace bottom byte, keep rest of mem
		i_mem(31 downto 8) & i_RS2(7 downto 0)
		    when i_ByteOp = "0000" else
		-- sbu: same as sb, unsigned doesn't matter for writes
		i_mem(31 downto 8) & i_RS2(7 downto 0)
		    when i_ByteOp = "0001" else
		-- sh: replace bottom halfword, keep rest of mem
		i_mem(31 downto 16) & i_RS2(15 downto 0)
		    when i_ByteOp = "0010" else
		-- shu: same as sh
		i_mem(31 downto 16) & i_RS2(15 downto 0)
		    when i_ByteOp = "0011" else
		-- sw: full RS1 replaces mem entirely
		i_RS2
		    when i_ByteOp = "0100" else

		-- LOADS (bit 3 = 1, operate on i_mem)
		-- lb: sign extend bottom byte of mem
		std_logic_vector(resize(signed(s_SelectedMemByte), DATA_WIDTH))
		    when i_ByteOp = "1000" else
		-- lbu: zero extend bottom byte of mem
		std_logic_vector(resize(unsigned(s_SelectedMemByte), DATA_WIDTH))
		    when i_ByteOp = "1001" else
		-- lh: sign extend bottom halfword of mem
		std_logic_vector(resize(signed(s_SelectedMemHalfword), DATA_WIDTH))
		    when i_ByteOp = "1010" else
		-- lhu: zero extend bottom halfword of mem
		std_logic_vector(resize(unsigned(s_SelectedMemHalfword), DATA_WIDTH))
		    when i_ByteOp = "1011" else
		-- lw: pass full mem value
		i_mem
		    when i_ByteOp = "1100" else

        (others => '0');

end dataflow;
