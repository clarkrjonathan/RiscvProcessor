-- Quartus Prime VHDL Template
-- Single-port RAM with single read/write address

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity mem is

	generic
	(
		DATA_WIDTH : natural := 32;
		ADDR_WIDTH : natural := 10;
		-- [TOOLFLOW/GHDL] Optional hex file used to pre-load the RAM in
		-- simulation. One DATA_WIDTH-bit word per line, lowest address first
		-- (this is exactly the format RARS' "dump HexText" produces and what
		-- ModelSim's `mem load -format hex` consumed). "" => zero-initialised.
		-- The datapath/control logic below is unchanged; this generic only
		-- provides an initial value for the `ram` signal, replacing the
		-- ModelSim-only `mem load` command that GHDL cannot perform.
		INIT_FILE  : string := ""
	);

	port
	(
		clk		: in std_logic;
		addr	        : in std_logic_vector((ADDR_WIDTH-1) downto 0);
		data	        : in std_logic_vector((DATA_WIDTH-1) downto 0);
		we		: in std_logic := '1';
		q		: out std_logic_vector((DATA_WIDTH -1) downto 0)
	);

end mem;

architecture rtl of mem is

	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
	type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;

	-- [TOOLFLOW/GHDL] Load the RAM contents from a hex file at elaboration.
	-- If the file is empty/missing (e.g. during synthesis), the RAM is simply
	-- zero-initialised, matching RARS' zero-filled data memory. This makes the
	-- initial value synthesis-safe: a missing file never raises an error.
	impure function init_ram(fname : string) return memory_t is
		variable mem_v   : memory_t := (others => (others => '0'));
		file     f       : text;
		variable fstatus : file_open_status;
		variable l       : line;
		variable word_v  : std_logic_vector((DATA_WIDTH-1) downto 0);
		variable idx     : integer := 0;
	begin
		if fname = "" then
			return mem_v;
		end if;
		file_open(fstatus, f, fname, read_mode);
		if fstatus /= open_ok then
			return mem_v;  -- file absent (e.g. synthesis): leave zero-filled
		end if;
		while (not endfile(f)) and (idx < 2**ADDR_WIDTH) loop
			readline(f, l);
			if l'length > 0 then
				hread(l, word_v);
				mem_v(idx) := word_v;
				idx := idx + 1;
			end if;
		end loop;
		file_close(f);
		return mem_v;
	end function;

	-- Declare the RAM signal and specify a default value.	Quartus Prime
	-- will load the provided memory initialization file (.mif).
	signal ram : memory_t := init_ram(INIT_FILE);

begin

	process(clk)
	begin
	if(rising_edge(clk)) then
		if(we = '1') then
			ram(to_integer(unsigned(addr))) <= data;
		end if;
	end if;
	end process;

	q <= ram(to_integer(unsigned(addr)));

end rtl;
