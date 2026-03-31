library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.RISCV_types.all;

-- i_ShiftType: 00 = logical left, 01 = logical right, 10 = arithmetic right
entity barrelShifter is
    port(
        i_Data      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_ShiftAmt  : in  std_logic_vector(4 downto 0);
        i_ShiftType : in  std_logic_vector(1 downto 0);
        o_Result    : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end barrelShifter;

architecture structural of barrelShifter is

    component mux2t1_N is
        generic(N : integer := 16);
        port(
            i_S  : in  std_logic;
            i_D0 : in  std_logic_vector(N-1 downto 0);
            i_D1 : in  std_logic_vector(N-1 downto 0);
            o_O  : out std_logic_vector(N-1 downto 0)
        );
    end component;

    -- fill bit: '0' for logical, i_Data(31) for arithmetic right
    signal s_fill : std_logic;

    -- intermediate signals between stages
    -- s_sX is the output of stage X
    signal s_s0 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_s1 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_s2 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_s3 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_s4 : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- reversed input/output for left shift (we implement left shift
    -- by reversing the input, doing a right shift, then reversing output)
    signal s_dataIn  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_dataOut : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- fill bit is sign bit only for arithmetic right shift
    s_fill <= i_Data(DATA_WIDTH-1) when i_ShiftType = "10" else '0';

    -- for left shift, reverse the input bits so we can reuse the right shift network
    -- for right shifts, pass through directly
    GEN_IN: for i in 0 to DATA_WIDTH-1 generate
        s_dataIn(i) <= i_Data(DATA_WIDTH-1-i) when i_ShiftType = "00" else i_Data(i);
    end generate;

    -- Stage 0: shift by 0 or 1
    MUX_S0: mux2t1_N
        generic map(N => DATA_WIDTH)
        port map(
            i_S  => i_ShiftAmt(0),
            i_D0 => s_dataIn,
            i_D1 => s_fill & s_dataIn(DATA_WIDTH-1 downto 1),
            o_O  => s_s0
        );

    -- Stage 1: shift by 0 or 2
    MUX_S1: mux2t1_N
        generic map(N => DATA_WIDTH)
        port map(
            i_S  => i_ShiftAmt(1),
            i_D0 => s_s0,
            i_D1 => s_fill & s_fill & s_s0(DATA_WIDTH-1 downto 2),
            o_O  => s_s1
        );

    -- Stage 2: shift by 0 or 4
    MUX_S2: mux2t1_N
        generic map(N => DATA_WIDTH)
        port map(
            i_S  => i_ShiftAmt(2),
            i_D0 => s_s1,
            i_D1 => s_fill & s_fill & s_fill & s_fill & s_s1(DATA_WIDTH-1 downto 4),
            o_O  => s_s2
        );

    -- Stage 3: shift by 0 or 8
    MUX_S3: mux2t1_N
        generic map(N => DATA_WIDTH)
        port map(
            i_S  => i_ShiftAmt(3),
            i_D0 => s_s2,
            i_D1 => s_fill & s_fill & s_fill & s_fill &
                    s_fill & s_fill & s_fill & s_fill &
                    s_s2(DATA_WIDTH-1 downto 8),
            o_O  => s_s3
        );

    -- Stage 4: shift by 0 or 16
    MUX_S4: mux2t1_N
        generic map(N => DATA_WIDTH)
        port map(
            i_S  => i_ShiftAmt(4),
            i_D0 => s_s3,
            i_D1 => s_fill & s_fill & s_fill & s_fill &
                    s_fill & s_fill & s_fill & s_fill &
                    s_fill & s_fill & s_fill & s_fill &
                    s_fill & s_fill & s_fill & s_fill &
                    s_s3(DATA_WIDTH-1 downto 16),
            o_O  => s_s4
        );

    -- for left shift, reverse the output bits back
    GEN_OUT: for i in 0 to DATA_WIDTH-1 generate
        s_dataOut(i) <= s_s4(DATA_WIDTH-1-i) when i_ShiftType = "00" else s_s4(i);
    end generate;

    o_Result <= s_dataOut;

end structural;
