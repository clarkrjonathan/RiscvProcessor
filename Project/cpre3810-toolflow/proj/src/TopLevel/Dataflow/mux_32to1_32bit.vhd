library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux_32to1_32bit is
    Port (
        -- 32 input ports, each 32 bits wide
        in0  : in  STD_LOGIC_VECTOR(31 downto 0);
        in1  : in  STD_LOGIC_VECTOR(31 downto 0);
        in2  : in  STD_LOGIC_VECTOR(31 downto 0);
        in3  : in  STD_LOGIC_VECTOR(31 downto 0);
        in4  : in  STD_LOGIC_VECTOR(31 downto 0);
        in5  : in  STD_LOGIC_VECTOR(31 downto 0);
        in6  : in  STD_LOGIC_VECTOR(31 downto 0);
        in7  : in  STD_LOGIC_VECTOR(31 downto 0);
        in8  : in  STD_LOGIC_VECTOR(31 downto 0);
        in9  : in  STD_LOGIC_VECTOR(31 downto 0);
        in10 : in  STD_LOGIC_VECTOR(31 downto 0);
        in11 : in  STD_LOGIC_VECTOR(31 downto 0);
        in12 : in  STD_LOGIC_VECTOR(31 downto 0);
        in13 : in  STD_LOGIC_VECTOR(31 downto 0);
        in14 : in  STD_LOGIC_VECTOR(31 downto 0);
        in15 : in  STD_LOGIC_VECTOR(31 downto 0);
        in16 : in  STD_LOGIC_VECTOR(31 downto 0);
        in17 : in  STD_LOGIC_VECTOR(31 downto 0);
        in18 : in  STD_LOGIC_VECTOR(31 downto 0);
        in19 : in  STD_LOGIC_VECTOR(31 downto 0);
        in20 : in  STD_LOGIC_VECTOR(31 downto 0);
        in21 : in  STD_LOGIC_VECTOR(31 downto 0);
        in22 : in  STD_LOGIC_VECTOR(31 downto 0);
        in23 : in  STD_LOGIC_VECTOR(31 downto 0);
        in24 : in  STD_LOGIC_VECTOR(31 downto 0);
        in25 : in  STD_LOGIC_VECTOR(31 downto 0);
        in26 : in  STD_LOGIC_VECTOR(31 downto 0);
        in27 : in  STD_LOGIC_VECTOR(31 downto 0);
        in28 : in  STD_LOGIC_VECTOR(31 downto 0);
        in29 : in  STD_LOGIC_VECTOR(31 downto 0);
        in30 : in  STD_LOGIC_VECTOR(31 downto 0);
        in31 : in  STD_LOGIC_VECTOR(31 downto 0);
        
        -- 5-bit select signal (2^5 = 32)
        sel  : in  STD_LOGIC_VECTOR(4 downto 0);
        
        -- Output
        dout : out STD_LOGIC_VECTOR(31 downto 0)
    );
end mux_32to1_32bit;

architecture dataflow of mux_32to1_32bit is
begin
    -- Dataflow implementation using with/select concurrent statement
    with sel select dout <=
        in0  when "00000",
        in1  when "00001",
        in2  when "00010",
        in3  when "00011",
        in4  when "00100",
        in5  when "00101",
        in6  when "00110",
        in7  when "00111",
        in8  when "01000",
        in9  when "01001",
        in10 when "01010",
        in11 when "01011",
        in12 when "01100",
        in13 when "01101",
        in14 when "01110",
        in15 when "01111",
        in16 when "10000",
        in17 when "10001",
        in18 when "10010",
        in19 when "10011",
        in20 when "10100",
        in21 when "10101",
        in22 when "10110",
        in23 when "10111",
        in24 when "11000",
        in25 when "11001",
        in26 when "11010",
        in27 when "11011",
        in28 when "11100",
        in29 when "11101",
        in30 when "11110",
        in31 when "11111",
        (others => 'X') when others;
        
end dataflow;
