library IEEE;
use IEEE.std_logic_1164.all;

entity mux4t1_N is
  generic(
    N : integer := 16  -- Width of input/output vectors
  );
  port(
    i_S   : in  std_logic_vector(1 downto 0);
    i_D0  : in  std_logic_vector(N-1 downto 0);
    i_D1  : in  std_logic_vector(N-1 downto 0);
    i_D2  : in  std_logic_vector(N-1 downto 0);
    i_D3  : in  std_logic_vector(N-1 downto 0);
    o_O   : out std_logic_vector(N-1 downto 0)
  );
end mux4t1_N;

architecture dataflow of mux4t1_N is

signal s_Mux1	: std_logic_vector(N-1 downto 0);
signal s_Mux2	: std_logic_vector(N-1 downto 0);

begin
  -- Concurrent signal assignment using when-else
  s_Mux1 <= i_D0 when i_S(0) = '0' else i_D1;
  s_Mux2 <= i_D2 when i_S(0) = '0' else i_D3;
  
  o_O <= s_Mux1 when i_S(1) = '0' else s_Mux2;

end dataflow;
