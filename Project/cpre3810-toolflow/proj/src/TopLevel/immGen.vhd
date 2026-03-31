library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

entity immGen is
port(
		i_Inst		: in std_logic_vector(DATA_WIDTH-1 downto 0);
  		o_Imm		: out std_logic_vector(DATA_WIDTH-1 downto 0)
 );
end immGen;

architecture dataflow of immGen is

begin
	o_Imm <= std_logic_vector(resize(signed(i_Inst(31 downto 20)), DATA_WIDTH)) when std_match(i_Inst, "-------------------------0010011") or
                      std_match(i_Inst, "-------------------------0000011") or
                      std_match(i_Inst, "-------------------------1100111")     -- JALR
        else std_logic_vector(resize(signed(i_Inst(31 downto 25) & i_Inst(11 downto 7)), DATA_WIDTH))
                when std_match(i_Inst, "-------------------------0100011")      -- S-type stores

        else i_Inst(31 downto 12) & x"000"
                when (std_match(i_Inst, "-------------------------0110111") or  -- LUI
                      std_match(i_Inst, "-------------------------0010111"))    -- AUIPC
                      
	else std_logic_vector(resize(signed(i_Inst(31) & i_Inst(19 downto 12) & i_Inst(20) & i_Inst(30 downto 21) & '0'), DATA_WIDTH))
    		when std_match(i_Inst, "-------------------------1101111")
    	else std_logic_vector(resize(signed(i_Inst(31) & i_Inst(7) & i_Inst(30 downto 25) & i_Inst(11 downto 8) & '0'), DATA_WIDTH))
    		when std_match(i_Inst, "-------------------------1100011")

        else (others => '0');
        
end dataflow;
