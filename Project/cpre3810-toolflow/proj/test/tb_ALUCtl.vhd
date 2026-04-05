-- ============================================================
-- tb_ALUCtl.vhd
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

entity tb_ALUCtl is
end tb_ALUCtl;

architecture behavior of tb_ALUCtl is

    component ALUCtl is
        port(
            i_ALUOp  : in  std_logic_vector(ALU_OP_WIDTH-1 downto 0);
            o_ALUCTL : out std_logic_vector(ALU_CTL_WIDTH-1 downto 0)
        );
    end component;

    signal s_ALUOp  : std_logic_vector(ALU_OP_WIDTH-1 downto 0);
    signal s_ALUCTL : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);

    procedure check_ctl(
        op       : in string;
        got      : in std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
        expected : in std_logic_vector(ALU_CTL_WIDTH-1 downto 0)
    ) is
    begin
        if std_match(got, expected) then
            report "ALUCtl " & op & " PASS" severity note;
        else
            report "ALUCtl " & op & " FAIL: got " & to_hstring(got)
                   severity error;
        end if;
    end procedure;

begin

    UUT: ALUCtl
        port map(
            i_ALUOp  => s_ALUOp,
            o_ALUCTL => s_ALUCTL
        );

    process
    begin
        -- ALUCTL bit layout: [8:7]=ShiftType [6:5]=LogicOp [4:3]=ALUSel [2]=USLT [1]=Sub [0]=InvZ

        -- ADD: ALUSel=01, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "0000"; wait for 10 ns;
        check_ctl("ADD ", s_ALUCTL, "----" & "01" & "-" & "0" & "0");

        -- SLL: ShiftType=00, ALUSel=00, InvZ=0, rest dont care
        s_ALUOp <= "0001"; wait for 10 ns;
        check_ctl("SLL ", s_ALUCTL, "00" & "--" & "00" & "-" & "-" & "0");

        -- SLT: ALUSel=11, USLT=0, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "0010"; wait for 10 ns;
        check_ctl("SLT ", s_ALUCTL, "----" & "11" & "0" & "1" & "0");

        -- SLTU: ALUSel=11, USLT=1, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "0011"; wait for 10 ns;
        check_ctl("SLTU", s_ALUCTL, "----" & "11" & "1" & "1" & "0");

        -- XOR: LogicOp=00, ALUSel=10, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "0100"; wait for 10 ns;
        check_ctl("XOR ", s_ALUCTL, "--" & "00" & "10" & "-" & "0" & "0");

        -- SRL: ShiftType=01, ALUSel=00, InvZ=0, rest dont care
        s_ALUOp <= "0101"; wait for 10 ns;
        check_ctl("SRL ", s_ALUCTL, "01" & "--" & "00" & "-" & "-" & "0");

        -- SRA: ShiftType=10, ALUSel=00, InvZ=0, rest dont care
        s_ALUOp <= "0110"; wait for 10 ns;
        check_ctl("SRA ", s_ALUCTL, "10" & "--" & "00" & "-" & "-" & "0");

        -- OR: LogicOp=10, ALUSel=10, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "0111"; wait for 10 ns;
        check_ctl("OR  ", s_ALUCTL, "--" & "10" & "10" & "-" & "0" & "0");

        -- AND: LogicOp=01, ALUSel=10, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "1000"; wait for 10 ns;
        check_ctl("AND ", s_ALUCTL, "--" & "01" & "10" & "-" & "0" & "0");

        -- BEQ: ALUSel=01, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1001"; wait for 10 ns;
        check_ctl("BEQ ", s_ALUCTL, "----" & "01" & "-" & "1" & "0");

        -- BNE: ALUSel=01, Sub=1, InvZ=1, rest dont care
        s_ALUOp <= "1010"; wait for 10 ns;
        check_ctl("BNE ", s_ALUCTL, "----" & "01" & "-" & "1" & "1");

        -- BLT: ALUSel=11, USLT=0, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1011"; wait for 10 ns;
        check_ctl("BLT ", s_ALUCTL, "----" & "11" & "0" & "1" & "0");

        -- BGE: ALUSel=11, USLT=0, Sub=1, InvZ=1, rest dont care
        s_ALUOp <= "1100"; wait for 10 ns;
        check_ctl("BGE ", s_ALUCTL, "----" & "11" & "0" & "1" & "1");

        -- BLTU: ALUSel=11, USLT=1, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1101"; wait for 10 ns;
        check_ctl("BLTU", s_ALUCTL, "----" & "11" & "1" & "1" & "0");

        -- BGEU: ALUSel=11, USLT=1, Sub=1, InvZ=1, rest dont care
        s_ALUOp <= "1110"; wait for 10 ns;
        check_ctl("BGEU", s_ALUCTL, "----" & "11" & "1" & "1" & "1");

        -- SUB: ALUSel=01, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1111"; wait for 10 ns;
        check_ctl("SUB ", s_ALUCTL, "----" & "01" & "-" & "1" & "0");

        report "ALUCtl testbench complete" severity note;
        wait;
    end process;

end behavior;-- ============================================================
-- tb_ALUCtl.vhd
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

entity tb_ALUCtl is
end tb_ALUCtl;

architecture behavior of tb_ALUCtl is

    component ALUCtl is
        port(
            i_ALUOp  : in  std_logic_vector(ALU_OP_WIDTH-1 downto 0);
            o_ALUCTL : out std_logic_vector(ALU_CTL_WIDTH-1 downto 0)
        );
    end component;

    signal s_ALUOp  : std_logic_vector(ALU_OP_WIDTH-1 downto 0);
    signal s_ALUCTL : std_logic_vector(ALU_CTL_WIDTH-1 downto 0);

    procedure check_ctl(
        op       : in string;
        got      : in std_logic_vector(ALU_CTL_WIDTH-1 downto 0);
        expected : in std_logic_vector(ALU_CTL_WIDTH-1 downto 0)
    ) is
    begin
        if std_match(got, expected) then
            report "ALUCtl " & op & " PASS" severity note;
        else
            report "ALUCtl " & op & " FAIL: got " & to_hstring(got)
                   severity error;
        end if;
    end procedure;

begin

    UUT: ALUCtl
        port map(
            i_ALUOp  => s_ALUOp,
            o_ALUCTL => s_ALUCTL
        );

    process
    begin
        -- ALUCTL bit layout: [8:7]=ShiftType [6:5]=LogicOp [4:3]=ALUSel [2]=USLT [1]=Sub [0]=InvZ

        -- ADD: ALUSel=01, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "0000"; wait for 10 ns;
        check_ctl("ADD ", s_ALUCTL, "----" & "01" & "-" & "0" & "-");

        -- SLL: ShiftType=00, ALUSel=00, InvZ=0, rest dont care
        s_ALUOp <= "0001"; wait for 10 ns;
        check_ctl("SLL ", s_ALUCTL, "00" & "--" & "00" & "-" & "-" & "-");

        -- SLT: ALUSel=11, USLT=0, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "0010"; wait for 10 ns;
        check_ctl("SLT ", s_ALUCTL, "----" & "11" & "0" & "1" & "-");

        -- SLTU: ALUSel=11, USLT=1, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "0011"; wait for 10 ns;
        check_ctl("SLTU", s_ALUCTL, "----" & "11" & "1" & "1" & "-");

        -- XOR: LogicOp=00, ALUSel=10, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "0100"; wait for 10 ns;
        check_ctl("XOR ", s_ALUCTL, "--" & "00" & "10" & "-" & "0" & "-");

        -- SRL: ShiftType=01, ALUSel=00, InvZ=0, rest dont care
        s_ALUOp <= "0101"; wait for 10 ns;
        check_ctl("SRL ", s_ALUCTL, "01" & "--" & "00" & "-" & "-" & "-");

        -- SRA: ShiftType=10, ALUSel=00, InvZ=0, rest dont care
        s_ALUOp <= "0110"; wait for 10 ns;
        check_ctl("SRA ", s_ALUCTL, "10" & "--" & "00" & "-" & "-" & "-");

        -- OR: LogicOp=10, ALUSel=10, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "0111"; wait for 10 ns;
        check_ctl("OR  ", s_ALUCTL, "--" & "10" & "10" & "-" & "0" & "-");

        -- AND: LogicOp=01, ALUSel=10, Sub=0, InvZ=0, rest dont care
        s_ALUOp <= "1000"; wait for 10 ns;
        check_ctl("AND ", s_ALUCTL, "--" & "01" & "10" & "-" & "0" & "-");

        -- BEQ: ALUSel=01, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1001"; wait for 10 ns;
        check_ctl("BEQ ", s_ALUCTL, "----" & "01" & "-" & "1" & "0");

        -- BNE: ALUSel=01, Sub=1, InvZ=1, rest dont care
        s_ALUOp <= "1010"; wait for 10 ns;
        check_ctl("BNE ", s_ALUCTL, "----" & "01" & "-" & "1" & "1");

        -- BLT: ALUSel=11, USLT=0, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1011"; wait for 10 ns;
        check_ctl("BLT ", s_ALUCTL, "----" & "11" & "0" & "1" & "0");

        -- BGE: ALUSel=11, USLT=0, Sub=1, InvZ=1, rest dont care
        s_ALUOp <= "1100"; wait for 10 ns;
        check_ctl("BGE ", s_ALUCTL, "----" & "11" & "0" & "1" & "1");

        -- BLTU: ALUSel=11, USLT=1, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1101"; wait for 10 ns;
        check_ctl("BLTU", s_ALUCTL, "----" & "11" & "1" & "1" & "0");

        -- BGEU: ALUSel=11, USLT=1, Sub=1, InvZ=1, rest dont care
        s_ALUOp <= "1110"; wait for 10 ns;
        check_ctl("BGEU", s_ALUCTL, "----" & "11" & "1" & "1" & "1");

        -- SUB: ALUSel=01, Sub=1, InvZ=0, rest dont care
        s_ALUOp <= "1111"; wait for 10 ns;
        check_ctl("SUB ", s_ALUCTL, "----" & "01" & "-" & "1" & "-");

        report "ALUCtl testbench complete" severity note;
        wait;
    end process;

end behavior;
