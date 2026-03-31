library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.RISCV_types.all;

entity control is
    	port(
    		i_Inst		: in std_logic_vector(DATA_WIDTH-1 downto 0);
    		
    		o_jalr		: out std_logic; 
    		o_jump		: out std_logic;
    		o_regWrite	: out std_logic;
    		o_branch	: out std_logic;
    		o_WRBCKSEL	: out std_logic_vector(1 downto 0);
    		o_byteOp	: out std_logic_vector(BYTE_OP_WIDTH-1 downto 0);
    		o_ALUOp		: out std_logic_vector(ALU_OP_WIDTH-1 downto 0);
		o_AUIPC		: out std_logic;
    		o_ALUSrc	: out std_logic;
    		o_HaltS		: out std_logic;
    		o_memWrite	: out std_logic
    	);
end control;

architecture dataflow of control is
signal controlOutput		: std_logic_vector(BYTE_OP_WIDTH + ALU_OP_WIDTH + 2 + 8 - 1 downto 0);

begin
		
		-- controlOutput(17 downto 0):
		-- 17:    jalr
		-- 16:    jump
		-- 15:    regWrite
		-- 14:    branch
		-- 13:12  WRBCKSEL
		-- 11:8   byteOp
		-- 7:4    ALUOp
		-- 3:     AUIPC
		-- 2:     ALUSrc
		-- 1:     HaltS
		-- 0:     memWrite

		controlOutput <=
				    -- LB
				    "00" & "1" & "0" & "10" & "1000" & "----" & "-" & "-" & "0" & "0"
					when std_match(i_Inst, "-----------------000-----0000011") else
				    -- LH
				    "00" & "1" & "0" & "10" & "1010" & "----" & "-" & "-" & "0" & "0"
					when std_match(i_Inst, "-----------------001-----0000011") else
				    -- LW
				    "00" & "1" & "0" & "10" & "1100" & "----" & "-" & "-" & "0" & "0"
					when std_match(i_Inst, "-----------------010-----0000011") else
				    -- LBU
				    "00" & "1" & "0" & "10" & "1001" & "----" & "-" & "-" & "0" & "0"
					when std_match(i_Inst, "-----------------100-----0000011") else
				    -- LHU
				    "00" & "1" & "0" & "10" & "1011" & "----" & "-" & "-" & "0" & "0"
					when std_match(i_Inst, "-----------------101-----0000011") else

				    -- ADDI
				    "00" & "1" & "0" & "11" & "----" & "0000" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "-----------------000-----0010011") else
				    -- SLLI
				    "00" & "1" & "0" & "11" & "----" & "0001" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "0000000----------001-----0010011") else
				    -- SLTI
				    "00" & "1" & "0" & "11" & "----" & "0010" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "-----------------010-----0010011") else
				    -- SLTIU
				    "00" & "1" & "0" & "11" & "----" & "0011" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "-----------------011-----0010011") else
				    -- XORI
				    "00" & "1" & "0" & "11" & "----" & "0100" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "-----------------100-----0010011") else
				    -- SRLI
				    "00" & "1" & "0" & "11" & "----" & "0101" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "0000000----------101-----0010011") else
				    -- SRAI
				    "00" & "1" & "0" & "11" & "----" & "0110" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "0100000----------101-----0010011") else
				    -- ORI
				    "00" & "1" & "0" & "11" & "----" & "0111" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "-----------------110-----0010011") else
				    -- ANDI
				    "00" & "1" & "0" & "11" & "----" & "1000" & "-" & "1" & "0" & "0"
					when std_match(i_Inst, "-----------------111-----0010011") else

				    -- AUIPC
				    "00" & "1" & "0" & "00" & "----" & "----" & "1" & "-" & "0" & "0"
					when std_match(i_Inst, "-------------------------0010111") else

				    -- SW
				    "00" & "0" & "0" & "--" & "0100" & "0000" & "-" & "1" & "0" & "1"
					when std_match(i_Inst, "-----------------010-----0100011") else

				    -- ADD
				    "00" & "1" & "0" & "11" & "----" & "0000" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------000-----0110011") else
				    -- SUB
				    "00" & "1" & "0" & "11" & "----" & "1111" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0100000----------000-----0110011") else
				    -- SLL
				    "00" & "1" & "0" & "11" & "----" & "0001" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------001-----0110011") else
				    -- SLT
				    "00" & "1" & "0" & "11" & "----" & "0010" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------010-----0110011") else
				    -- SLTU
				    "00" & "1" & "0" & "11" & "----" & "0011" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------011-----0110011") else
				    -- XOR
				    "00" & "1" & "0" & "11" & "----" & "0100" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------100-----0110011") else
				    -- SRL
				    "00" & "1" & "0" & "11" & "----" & "0101" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------101-----0110011") else
				    -- SRA
				    "00" & "1" & "0" & "11" & "----" & "0110" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0100000----------101-----0110011") else
				    -- OR
				    "00" & "1" & "0" & "11" & "----" & "0111" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------110-----0110011") else
				    -- AND
				    "00" & "1" & "0" & "11" & "----" & "1000" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "0000000----------111-----0110011") else

				    -- LUI
				    "00" & "1" & "0" & "01" & "----" & "----" & "-" & "-" & "0" & "0"
					when std_match(i_Inst, "-------------------------0110111") else

				    -- BEQ
				    "00" & "0" & "1" & "--" & "----" & "1001" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "-----------------000-----1100011") else
				    -- BNE
				    "00" & "0" & "1" & "--" & "----" & "1010" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "-----------------001-----1100011") else
				    -- BLT
				    "00" & "0" & "1" & "--" & "----" & "1011" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "-----------------100-----1100011") else
				    -- BGE
				    "00" & "0" & "1" & "--" & "----" & "1100" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "-----------------101-----1100011") else
				    -- BLTU
				    "00" & "0" & "1" & "--" & "----" & "1101" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "-----------------110-----1100011") else
				    -- BGEU
				    "00" & "0" & "1" & "--" & "----" & "1110" & "-" & "0" & "0" & "0"
					when std_match(i_Inst, "-----------------111-----1100011") else

				    -- JALR
				    "11" & "1" & "-" & "00" & "----" & "----" & "0" & "-" & "0" & "0"
					when std_match(i_Inst, "-----------------000-----1100111") else
				    -- JAL
				    "01" & "1" & "-" & "00" & "----" & "----" & "0" & "-" & "0" & "0"
					when std_match(i_Inst, "-------------------------1101111") else

				    -- WFI
				    "00" & "0" & "-" & "--" & "----" & "----" & "-" & "-" & "1" & "0"
					when std_match(i_Inst, "0001000----------000-----1110011") else

    		(others => '0');

	
		o_jalr      <= controlOutput(17);
		o_jump      <= controlOutput(16);
		o_regWrite  <= controlOutput(15);
		o_branch    <= controlOutput(14);
		o_WRBCKSEL  <= controlOutput(13 downto 12);
		o_byteOp    <= controlOutput(11 downto 8);
		o_ALUOp     <= controlOutput(7 downto 4);
		o_AUIPC     <= controlOutput(3);
		o_ALUSrc    <= controlOutput(2);
		o_HaltS     <= controlOutput(1);
		o_memWrite  <= controlOutput(0);
		
end dataflow;
