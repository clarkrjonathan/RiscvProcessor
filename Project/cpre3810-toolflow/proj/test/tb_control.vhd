-- ============================================================
-- tb_control.vhd
-- ============================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_control is
end tb_control;

architecture behavior of tb_control is

    component control is
        port(
            i_Inst     : in  std_logic_vector(31 downto 0);
            o_jalr     : out std_logic;
            o_jump     : out std_logic;
            o_regWrite : out std_logic;
            o_branch   : out std_logic;
            o_WRBCKSEL : out std_logic_vector(1 downto 0);
            o_byteOp   : out std_logic_vector(3 downto 0);
            o_ALUOp    : out std_logic_vector(3 downto 0);
            o_AUIPC    : out std_logic;
            o_ALUSrc   : out std_logic;
            o_HaltS    : out std_logic;
            o_memWrite : out std_logic
        );
    end component;

    signal s_Inst     : std_logic_vector(31 downto 0);
    signal s_jalr     : std_logic;
    signal s_jump     : std_logic;
    signal s_regWrite : std_logic;
    signal s_branch   : std_logic;
    signal s_WRBCKSEL : std_logic_vector(1 downto 0);
    signal s_byteOp   : std_logic_vector(3 downto 0);
    signal s_ALUOp    : std_logic_vector(3 downto 0);
    signal s_AUIPC    : std_logic;
    signal s_ALUSrc   : std_logic;
    signal s_HaltS    : std_logic;
    signal s_memWrite : std_logic;

    procedure check(
        name       : in string;
        jalr       : in std_logic;
        jump       : in std_logic;
        regWrite   : in std_logic;
        branch     : in std_logic;
        WRBCKSEL   : in std_logic_vector(1 downto 0);
        byteOp     : in std_logic_vector(3 downto 0);
        ALUOp      : in std_logic_vector(3 downto 0);
        AUIPC      : in std_logic;
        ALUSrc     : in std_logic;
        HaltS      : in std_logic;
        memWrite   : in std_logic;
        exp_jalr     : in std_logic;
        exp_jump     : in std_logic;
        exp_regWrite : in std_logic;
        exp_branch   : in std_logic;
        exp_WRBCKSEL : in std_logic_vector(1 downto 0);
        exp_byteOp   : in std_logic_vector(3 downto 0);
        exp_ALUOp    : in std_logic_vector(3 downto 0);
        exp_AUIPC    : in std_logic;
        exp_ALUSrc   : in std_logic;
        exp_HaltS    : in std_logic;
        exp_memWrite : in std_logic
    ) is
        variable pass : boolean := true;
    begin
        if not std_match(jalr,     exp_jalr)     then pass := false; end if;
        if not std_match(jump,     exp_jump)     then pass := false; end if;
        if not std_match(regWrite, exp_regWrite) then pass := false; end if;
        if not std_match(branch,   exp_branch)   then pass := false; end if;
        if not std_match(WRBCKSEL, exp_WRBCKSEL) then pass := false; end if;
        if not std_match(byteOp,   exp_byteOp)   then pass := false; end if;
        if not std_match(ALUOp,    exp_ALUOp)    then pass := false; end if;
        if not std_match(AUIPC,    exp_AUIPC)    then pass := false; end if;
        if not std_match(ALUSrc,   exp_ALUSrc)   then pass := false; end if;
        if not std_match(HaltS,    exp_HaltS)    then pass := false; end if;
        if not std_match(memWrite, exp_memWrite) then pass := false; end if;
        if pass then
            report "control " & name & " PASS" severity note;
        else
            report "control " & name & " FAIL" severity error;
        end if;
    end procedure;

begin

    UUT: control
        port map(
            i_Inst     => s_Inst,
            o_jalr     => s_jalr,
            o_jump     => s_jump,
            o_regWrite => s_regWrite,
            o_branch   => s_branch,
            o_WRBCKSEL => s_WRBCKSEL,
            o_byteOp   => s_byteOp,
            o_ALUOp    => s_ALUOp,
            o_AUIPC    => s_AUIPC,
            o_ALUSrc   => s_ALUSrc,
            o_HaltS    => s_HaltS,
            o_memWrite => s_memWrite
        );

    process
    begin
        -- jalr jump rW  br  WRBCK byteOp ALUOp  AUIPC ALUSrc HaltS memW

        -- LB: regWrite=1, WRBCKSEL=10, byteOp=1000
        s_Inst <= x"00408183"; wait for 10 ns;
        check("LB  ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"10","1000","----",'-','-','0','0');

        -- LH: byteOp=1010
        s_Inst <= x"00409183"; wait for 10 ns;
        check("LH  ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"10","1010","----",'-','-','0','0');

        -- LW: byteOp=1100
        s_Inst <= x"0040A183"; wait for 10 ns;
        check("LW  ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"10","1100","----",'-','-','0','0');

        -- LBU: byteOp=1001
        s_Inst <= x"0040C183"; wait for 10 ns;
        check("LBU ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"10","1001","----",'-','-','0','0');

        -- LHU: byteOp=1011
        s_Inst <= x"0040D183"; wait for 10 ns;
        check("LHU ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"10","1011","----",'-','-','0','0');

        -- ADDI: WRBCKSEL=11, ALUOp=0000, ALUSrc=1
        s_Inst <= x"00508193"; wait for 10 ns;
        check("ADDI", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0000",'-','1','0','0');

        -- SLTI: ALUOp=0010
        s_Inst <= x"0050A193"; wait for 10 ns;
        check("SLTI", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0010",'-','1','0','0');

        -- SLTIU: ALUOp=0011
        s_Inst <= x"0050B193"; wait for 10 ns;
        check("SLTU", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0011",'-','1','0','0');

        -- XORI: ALUOp=0100
        s_Inst <= x"0050C193"; wait for 10 ns;
        check("XORI", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0100",'-','1','0','0');

        -- ORI: ALUOp=0111
        s_Inst <= x"0050E193"; wait for 10 ns;
        check("ORI ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0111",'-','1','0','0');

        -- ANDI: ALUOp=1000
        s_Inst <= x"0050F193"; wait for 10 ns;
        check("ANDI", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","1000",'-','1','0','0');

        -- SLLI: ALUOp=0001
        s_Inst <= x"00109193"; wait for 10 ns;
        check("SLLI", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0001",'-','1','0','0');

        -- SRLI: ALUOp=0101
        s_Inst <= x"0010D193"; wait for 10 ns;
        check("SRLI", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0101",'-','1','0','0');

        -- SRAI: ALUOp=0110
        s_Inst <= x"4010D193"; wait for 10 ns;
        check("SRAI", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0110",'-','1','0','0');

        -- LUI: WRBCKSEL=01
        s_Inst <= x"000011B7"; wait for 10 ns;
        check("LUI ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"01","----","----",'-','-','0','0');

        -- AUIPC: WRBCKSEL=00, AUIPC=1
        s_Inst <= x"00001197"; wait for 10 ns;
        check("AUIP", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"00","----","----",'1','-','0','0');

        -- SW: regWrite=0, byteOp=0100, ALUOp=0000, ALUSrc=1, memWrite=1
        s_Inst <= x"0020A023"; wait for 10 ns;
        check("SW  ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','0',"--","0100","0000",'-','1','0','1');

        -- ADD: WRBCKSEL=11, ALUOp=0000, ALUSrc=0
        s_Inst <= x"002081B3"; wait for 10 ns;
        check("ADD ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0000",'-','0','0','0');

        -- SUB: ALUOp=1111
        s_Inst <= x"402081B3"; wait for 10 ns;
        check("SUB ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","1111",'-','0','0','0');

        -- SLL: ALUOp=0001
        s_Inst <= x"002091B3"; wait for 10 ns;
        check("SLL ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0001",'-','0','0','0');

        -- SLT: ALUOp=0010
        s_Inst <= x"0020A1B3"; wait for 10 ns;
        check("SLT ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0010",'-','0','0','0');

        -- SLTU: ALUOp=0011
        s_Inst <= x"0020B1B3"; wait for 10 ns;
        check("SLTU", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0011",'-','0','0','0');

        -- XOR: ALUOp=0100
        s_Inst <= x"0020C1B3"; wait for 10 ns;
        check("XOR ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0100",'-','0','0','0');

        -- SRL: ALUOp=0101
        s_Inst <= x"0020D1B3"; wait for 10 ns;
        check("SRL ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0101",'-','0','0','0');

        -- SRA: ALUOp=0110
        s_Inst <= x"4020D1B3"; wait for 10 ns;
        check("SRA ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0110",'-','0','0','0');

        -- OR: ALUOp=0111
        s_Inst <= x"0020E1B3"; wait for 10 ns;
        check("OR  ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","0111",'-','0','0','0');

        -- AND: ALUOp=1000
        s_Inst <= x"0020F1B3"; wait for 10 ns;
        check("AND ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','1','0',"11","----","1000",'-','0','0','0');

        -- BEQ: branch=1, ALUOp=1001
        s_Inst <= x"00208463"; wait for 10 ns;
        check("BEQ ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','1',"--","----","1001",'-','0','0','0');

        -- BNE: ALUOp=1010
        s_Inst <= x"00209463"; wait for 10 ns;
        check("BNE ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','1',"--","----","1010",'-','0','0','0');

        -- BLT: ALUOp=1011
        s_Inst <= x"0020C463"; wait for 10 ns;
        check("BLT ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','1',"--","----","1011",'-','0','0','0');

        -- BGE: ALUOp=1100
        s_Inst <= x"0020D463"; wait for 10 ns;
        check("BGE ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','1',"--","----","1100",'-','0','0','0');

        -- BLTU: ALUOp=1101
        s_Inst <= x"0020E463"; wait for 10 ns;
        check("BLTU", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','1',"--","----","1101",'-','0','0','0');

        -- BGEU: ALUOp=1110
        s_Inst <= x"0020F463"; wait for 10 ns;
        check("BGEU", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','1',"--","----","1110",'-','0','0','0');

        -- JALR: jalr=1, jump=1, regWrite=1, WRBCKSEL=00, AUIPC=0
        s_Inst <= x"000081E7"; wait for 10 ns;
        check("JALR", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '1','1','1','-',"00","----","----",'0','-','0','0');

        -- JAL: jalr=0, jump=1, regWrite=1, WRBCKSEL=00, AUIPC=0
        s_Inst <= x"008001EF"; wait for 10 ns;
        check("JAL ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','1','1','-',"00","----","----",'0','-','0','0');

        -- WFI: HaltS=1, everything else 0/dc
        s_Inst <= x"10500073"; wait for 10 ns;
        check("WFI ", s_jalr,s_jump,s_regWrite,s_branch,s_WRBCKSEL,s_byteOp,s_ALUOp,s_AUIPC,s_ALUSrc,s_HaltS,s_memWrite,
              '0','0','0','-',"--","----","----",'-','-','1','0');

        report "tb_control complete" severity note;
        wait;
    end process;

end behavior;
