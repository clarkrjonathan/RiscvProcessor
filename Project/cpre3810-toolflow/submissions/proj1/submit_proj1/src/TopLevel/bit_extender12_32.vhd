library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bit_extender12_32 is

	generic
	(
		INPUT_WIDTH : integer := 12;
		OUTPUT_WIDTH : integer:= 32
	);

	port
	(
		se	: in std_logic; --sign extend select
		input	: in std_logic_vector((INPUT_WIDTH - 1) downto 0);
		output	: out std_logic_vector((OUTPUT_WIDTH - 1) downto 0)
	
	);

end bit_extender12_32;

architecture dataflow of bit_extender12_32 is
begin
	process(se, input, output)
	begin
		if se = '1' then
			output(31 downto 12) <= (others => input(11));
			output(11 downto 0) <= input;
		else
			output(31 downto 12) <= (others => '0');
			output(11 downto 0) <= input;
		end if;
	end process;
end dataflow;