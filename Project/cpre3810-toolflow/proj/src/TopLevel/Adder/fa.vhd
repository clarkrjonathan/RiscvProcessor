-------------------------------------------------------------------------
-- fa.vhd
-- Structural full adder using provided gates
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity fa is
  port(
    iA, iB, iCin : in  std_logic;
    oS, oCout    : out std_logic
  );
end fa;

architecture structural of fa is
  signal w_xor1, w_and1, w_and2 : std_logic;
  component xorg2 is
  	port(
  		i_A,i_B	: in std_logic;
  		o_F	: out std_logic
  	);
  end component;
  
  component org2 is
  	port(
  		i_A,i_B	: in std_logic;
  		o_F	: out std_logic
  	);
  end component;
  
  component andg2 is
  	port(
  		i_A,i_B	: in std_logic;
  		o_F	: out std_logic
  	);
  end component;
  	
begin

  -- Sum calculation: S = A xor B xor Cin
  XOR1: xorg2 port map(i_A => iA, i_B => iB, o_F => w_xor1);
  XOR2: xorg2 port map(i_A => w_xor1, i_B => iCin, o_F => oS);

  -- Carry-out calculation: Cout = (A and B) or (Cin and (A xor B))
  AND1: andg2 port map(i_A => iA, i_B => iB, o_F => w_and1);
  AND2:	andg2 port map(i_A => w_xor1, i_B => iCin, o_F => w_and2);
  OR1:  org2 port map(i_A => w_and1, i_B => w_and2, o_F => oCout);

end structural;

