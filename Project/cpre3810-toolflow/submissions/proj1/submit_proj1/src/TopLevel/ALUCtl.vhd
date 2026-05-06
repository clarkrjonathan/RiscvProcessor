library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.RISCV_types.all;

entity ALUCtl is
    	port(
    		i_ALUOp		: in	std_logic_vector(ALU_OP_WIDTH-1 downto 0);
  		o_ALUCTL	: out	std_logic_vector(ALU_CTL_WIDTH-1 downto 0)
    	);
end ALUCtl;

architecture dataflow of ALUCtl is

begin
		
		--8:7		shift type
		--6:5		Logic operator
		--4:3		ALU Select
		--2		set less than unsigned
		--1		subtract
		--0		invert zero (outside ALU)
		
		o_ALUCTL <=
				    -- Add
				    "--" & "--" & "01" & "-" & "0" & "-"
					when std_match(i_ALUOp, "0000") else
				-- sll
				    "00" & "--" & "00" & "-" & "-" & "-"
					when std_match(i_ALUOp, "0001") else
				-- slt
				    "--" & "--" & "11" & "0" & "1" & "-"
					when std_match(i_ALUOp, "0010") else
				-- sltu
				    "--" & "--" & "11" & "1" & "1" & "-"
					when std_match(i_ALUOp, "0011") else
				-- xor
				    "--" & "00" & "10" & "-" & "-" & "-"
					when std_match(i_ALUOp, "0100") else
				-- srl
				    "01" & "--" & "00" & "-" & "-" & "-"
					when std_match(i_ALUOp, "0101") else
				-- sra
				    "10" & "--" & "00" & "-" & "-" & "-"
					when std_match(i_ALUOp, "0110") else
				-- or
				    "--" & "10" & "10" & "-" & "-" & "-"
					when std_match(i_ALUOp, "0111") else
				
				-- and
				    "--" & "01" & "10" & "-" & "-" & "-"
					when std_match(i_ALUOp, "1000") else
				-- beq
				    "--" & "--" & "01" & "-" & "1" & "0"
					when std_match(i_ALUOp, "1001") else
				-- bne
				    "--" & "--" & "01" & "-" & "1" & "1"
					when std_match(i_ALUOp, "1010") else
				-- blt
				    "--" & "--" & "11" & "0" & "1" & "1"
					when std_match(i_ALUOp, "1011") else
				-- bge
				    "--" & "--" & "11" & "0" & "1" & "0"
					when std_match(i_ALUOp, "1100") else
				-- bltu
				    "--" & "--" & "11" & "1" & "1" & "1"
					when std_match(i_ALUOp, "1101") else
				-- bgeu
				    "--" & "--" & "11" & "1" & "1" & "0"
					when std_match(i_ALUOp, "1110") else
				-- sub
				    "--" & "--" & "01" & "-" & "1" & "-"
					when std_match(i_ALUOp, "1111") else


				    

    		(others => '0');

end dataflow;
