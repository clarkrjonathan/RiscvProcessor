-------------------------------------------------------------------------
-- adder_N.vhd
-- N-bit ripple-carry adder using structural full adders
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;


library work;
use work.RISCV_types.all;


entity adder_N is
  generic(N : integer := 32);
  port(
    iA    : in  std_logic_vector(N-1 downto 0);
    iB    : in  std_logic_vector(N-1 downto 0);
    iCin  : in  std_logic;
    oS    : out std_logic_vector(N-1 downto 0);
    oCout : out std_logic
  );
end adder_N;

architecture structural of adder_N is
  signal c : std_logic_vector(N downto 0); -- carries between full adders
  component fa is
  	port(
  		iA, iB, iCin	: in std_logic;
  		oS, oCout	: out std_logic
  		);
  end component;
  
begin
  c(0) <= iCin;  -- initialize carry-in

  gen_FA: for i in 0 to N-1 generate
    U_FA: fa
      port map(
        iA   => iA(i),
        iB   => iB(i),
        iCin => c(i),
        oS   => oS(i),
        oCout=> c(i+1)
      );
  end generate;

  oCout <= c(N);  -- final carry-out

end structural;

