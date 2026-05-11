-------------------------------------------------------------------------
-- hazard_detect.vhd
-- Hazard Detection Unit for 5-stage pipelined RISC-V processor.
--
-- Monitors IF/ID, ID/EX, and EX/MEM instructions to detect:
--   (A) RAW data hazards  -> stall + forwarding control signals
--   (B) Control hazards   -> squash signals
--
-- STALL vector (5 bits): bit4=PC, bit3=IF/ID, bit2=ID/EX, bit1=EX/MEM, bit0=MEM/WB
--   Load stall:  "11000"  (stall PC and IF/ID; ID/EX gets a bubble via squash)
--   Branch/jump: "00000"  (no stall needed for control hazards)
--
-- SQUASH vector (4 bits): bit3=IF/ID, bit2=ID/EX, bit1=EX/MEM, bit0=MEM/WB
--   Load stall:  "0100"   (bubble ID/EX only)
--   Branch/jump: "1100"   (bubble IF/ID and ID/EX)
--   Both:        "1100"   (OR of the two -- branch squash dominates)
--
-- FORWARDING vectors (3 bits each):
--   bit 2     = forward enable
--   bits 1:0  = source:
--     "00" = EX ALUOut    (inst currently finishing execute)
--     "01" = EX/MEM ALUOut (consolidated ALU/AUIPC result)
--     "10" = MEM ByteOut  (load result, inst currently finishing memory)
--
-- x0 EXCLUSION:
--   No hazard is signalled when either the source (RS) or destination (RD)
--   address is "00000". Implemented by comparing each address against zero
--   using addr_compare and inverting the result.
--
-- OPCODE CONSTANTS (standard RISC-V):
--   R-type:  "0110011"  writes RD, resolves EX
--   I-ALU:   "0010011"  writes RD, resolves EX
--   Load:    "0000011"  writes RD, resolves MEM (needs stall if in IDEX)
--   Store:   "0100011"  no RD write
--   Branch:  "1100011"  no RD write
--   JAL:     "1101111"  writes RD, resolves EX
--   JALR:    "1100111"  writes RD, resolves EX
--   LUI:     "0110111"  writes RD, resolves EX
--   AUIPC:   "0010111"  writes RD, resolves EX
--
-- REGISTER ADDRESS FIELDS (RISC-V encoding):
--   RS1: inst[19:15]   RS2: inst[24:20]   RD: inst[11:7]
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library work;
use work.RISCV_types.all;

entity hazard_detect is
  port(
    i_IFID_Inst  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    i_IDEX_Inst  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    i_EXMEM_Inst : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    i_BranchJump : in  std_logic;

    -- Stall vector:  bit4=PC, bit3=IF/ID, bit2=ID/EX, bit1=EX/MEM, bit0=MEM/WB
    o_Stall      : out std_logic_vector(4 downto 0);
    -- Squash vector: bit3=IF/ID, bit2=ID/EX, bit1=EX/MEM, bit0=MEM/WB
    o_Squash     : out std_logic_vector(3 downto 0);
    -- Forwarding: {enable, src[1:0]}
    o_FWD_RS1    : out std_logic_vector(2 downto 0);
    o_FWD_RS2    : out std_logic_vector(2 downto 0)
  );
end hazard_detect;

architecture structure of hazard_detect is

  component addr_compare is
    port(
      i_A     : in  std_logic_vector(4 downto 0);
      i_B     : in  std_logic_vector(4 downto 0);
      o_Match : out std_logic
    );
  end component;

  component andg2 is
    port(i_A : in std_logic; i_B : in std_logic; o_F : out std_logic);
  end component;

  component org2 is
    port(i_A : in std_logic; i_B : in std_logic; o_F : out std_logic);
  end component;

  component invg is
    port(i_A : in std_logic; o_F : out std_logic);
  end component;

  constant ZERO_ADDR : std_logic_vector(4 downto 0) := "00000";

  ---------------------------------------------------------------------------
  -- Opcode classification
  ---------------------------------------------------------------------------
  signal s_IDEX_writesRD    : std_logic;
  signal s_IDEX_isLoad      : std_logic;
  signal s_IDEX_resolvesEX  : std_logic;
  signal s_EXMEM_writesRD   : std_logic;
  signal s_EXMEM_isLoad     : std_logic;
  signal s_EXMEM_resolvesEX : std_logic;
  signal s_IFID_usesRS1     : std_logic;
  signal s_IFID_usesRS2     : std_logic;

  ---------------------------------------------------------------------------
  -- x0 exclusion
  ---------------------------------------------------------------------------
  signal s_RS1_isZero      : std_logic;
  signal s_RS2_isZero      : std_logic;
  signal s_IDEX_RD_isZero  : std_logic;
  signal s_EXMEM_RD_isZero : std_logic;
  signal s_RS1_valid       : std_logic;
  signal s_RS2_valid       : std_logic;
  signal s_IDEX_RD_valid   : std_logic;
  signal s_EXMEM_RD_valid  : std_logic;

  ---------------------------------------------------------------------------
  -- Address match signals
  ---------------------------------------------------------------------------
  signal s_RS1_match_IDEX  : std_logic;
  signal s_RS2_match_IDEX  : std_logic;
  signal s_RS1_match_EXMEM : std_logic;
  signal s_RS2_match_EXMEM : std_logic;

  ---------------------------------------------------------------------------
  -- AND tree intermediates for RAW hazard conditions
  -- Each raw check: usesRSx AND RSx_valid AND RD_valid AND writesRD AND match
  -- Done in two levels of andg2 pairs then a final AND with match
  ---------------------------------------------------------------------------
  -- RS1 vs IDEX
  signal s_RS1_IDEX_ab  : std_logic;  -- usesRS1 AND RS1_valid
  signal s_RS1_IDEX_cd  : std_logic;  -- IDEX_RD_valid AND IDEX_writesRD
  signal s_RS1_IDEX_abcd: std_logic;  -- above two ANDed
  signal s_RS1_IDEX_raw : std_logic;  -- AND with address match

  -- RS2 vs IDEX
  signal s_RS2_IDEX_ab  : std_logic;
  signal s_RS2_IDEX_cd  : std_logic;
  signal s_RS2_IDEX_abcd: std_logic;
  signal s_RS2_IDEX_raw : std_logic;

  -- RS1 vs EXMEM
  signal s_RS1_EXMEM_ab  : std_logic;
  signal s_RS1_EXMEM_cd  : std_logic;
  signal s_RS1_EXMEM_abcd: std_logic;
  signal s_RS1_EXMEM_raw : std_logic;

  -- RS2 vs EXMEM
  signal s_RS2_EXMEM_ab  : std_logic;
  signal s_RS2_EXMEM_cd  : std_logic;
  signal s_RS2_EXMEM_abcd: std_logic;
  signal s_RS2_EXMEM_raw : std_logic;

  ---------------------------------------------------------------------------
  -- Stall and forward decision signals
  ---------------------------------------------------------------------------
  signal s_RS1_IDEX_stall  : std_logic;
  signal s_RS2_IDEX_stall  : std_logic;
  signal s_load_stall      : std_logic;

  signal s_RS1_fwd_EX      : std_logic;
  signal s_RS2_fwd_EX      : std_logic;
  signal s_RS1_fwd_EXMEM   : std_logic;
  signal s_RS2_fwd_EXMEM   : std_logic;
  signal s_RS1_fwd_MEM     : std_logic;
  signal s_RS2_fwd_MEM     : std_logic;

  -- Forward enable: OR of all forward conditions per RS
  signal s_RS1_en_a        : std_logic;  -- fwd_EX OR fwd_EXMEM
  signal s_RS1_fwd_en      : std_logic;  -- above OR fwd_MEM
  signal s_RS2_en_a        : std_logic;
  signal s_RS2_fwd_en      : std_logic;

  -- Forward source encoding (when/else, 2-bit)
  signal s_RS1_src         : std_logic_vector(1 downto 0);
  signal s_RS2_src         : std_logic_vector(1 downto 0);

  -- Squash intermediates
  signal s_squash_IDEX     : std_logic;  -- load stall OR branch/jump

  -- NOT of IDEX_isLoad for resolvesEX gate
  signal s_IDEX_notLoad    : std_logic;
  signal s_EXMEM_notLoad   : std_logic;

begin

  ---------------------------------------------------------------------------
  -- OPCODE CLASSIFICATION (when/else on 7-bit opcode slices)
  ---------------------------------------------------------------------------

  -- ID/EX instruction
  s_IDEX_writesRD <=
    '1' when i_IDEX_Inst(6 downto 0) = "0110011" else  -- R-type
    '1' when i_IDEX_Inst(6 downto 0) = "0010011" else  -- I-ALU
    '1' when i_IDEX_Inst(6 downto 0) = "0000011" else  -- Load
    '1' when i_IDEX_Inst(6 downto 0) = "1101111" else  -- JAL
    '1' when i_IDEX_Inst(6 downto 0) = "1100111" else  -- JALR
    '1' when i_IDEX_Inst(6 downto 0) = "0110111" else  -- LUI
    '1' when i_IDEX_Inst(6 downto 0) = "0010111" else  -- AUIPC
    '0';

  s_IDEX_isLoad <=
    '1' when i_IDEX_Inst(6 downto 0) = "0000011" else '0';

  -- resolvesEX = writesRD AND NOT isLoad
  inv_IDEX_load: invg
    port map(i_A => s_IDEX_isLoad, o_F => s_IDEX_notLoad);
  gate_IDEX_resEX: andg2
    port map(i_A => s_IDEX_writesRD, i_B => s_IDEX_notLoad,
             o_F => s_IDEX_resolvesEX);

  -- EX/MEM instruction
  s_EXMEM_writesRD <=
    '1' when i_EXMEM_Inst(6 downto 0) = "0110011" else
    '1' when i_EXMEM_Inst(6 downto 0) = "0010011" else
    '1' when i_EXMEM_Inst(6 downto 0) = "0000011" else
    '1' when i_EXMEM_Inst(6 downto 0) = "1101111" else
    '1' when i_EXMEM_Inst(6 downto 0) = "1100111" else
    '1' when i_EXMEM_Inst(6 downto 0) = "0110111" else
    '1' when i_EXMEM_Inst(6 downto 0) = "0010111" else
    '0';

  s_EXMEM_isLoad <=
    '1' when i_EXMEM_Inst(6 downto 0) = "0000011" else '0';

  inv_EXMEM_load: invg
    port map(i_A => s_EXMEM_isLoad, o_F => s_EXMEM_notLoad);
  gate_EXMEM_resEX: andg2
    port map(i_A => s_EXMEM_writesRD, i_B => s_EXMEM_notLoad,
             o_F => s_EXMEM_resolvesEX);

  -- IF/ID register usage
  s_IFID_usesRS1 <=
    '1' when i_IFID_Inst(6 downto 0) = "0110011" else  -- R-type
    '1' when i_IFID_Inst(6 downto 0) = "0010011" else  -- I-ALU
    '1' when i_IFID_Inst(6 downto 0) = "0000011" else  -- Load
    '1' when i_IFID_Inst(6 downto 0) = "0100011" else  -- Store
    '1' when i_IFID_Inst(6 downto 0) = "1100011" else  -- Branch
    '1' when i_IFID_Inst(6 downto 0) = "1100111" else  -- JALR
    '0';

  s_IFID_usesRS2 <=
    '1' when i_IFID_Inst(6 downto 0) = "0110011" else  -- R-type
    '1' when i_IFID_Inst(6 downto 0) = "0100011" else  -- Store
    '1' when i_IFID_Inst(6 downto 0) = "1100011" else  -- Branch
    '0';

  ---------------------------------------------------------------------------
  -- x0 EXCLUSION
  -- Compare each address against "00000". Match = IS x0. Invert for valid.
  ---------------------------------------------------------------------------
  cmp_RS1_zero:    addr_compare port map(i_A => i_IFID_Inst(19 downto 15),
                                         i_B => ZERO_ADDR, o_Match => s_RS1_isZero);
  cmp_RS2_zero:    addr_compare port map(i_A => i_IFID_Inst(24 downto 20),
                                         i_B => ZERO_ADDR, o_Match => s_RS2_isZero);
  cmp_IDEX_zero:   addr_compare port map(i_A => i_IDEX_Inst(11 downto 7),
                                         i_B => ZERO_ADDR, o_Match => s_IDEX_RD_isZero);
  cmp_EXMEM_zero:  addr_compare port map(i_A => i_EXMEM_Inst(11 downto 7),
                                         i_B => ZERO_ADDR, o_Match => s_EXMEM_RD_isZero);

  inv_RS1:   invg port map(i_A => s_RS1_isZero,      o_F => s_RS1_valid);
  inv_RS2:   invg port map(i_A => s_RS2_isZero,      o_F => s_RS2_valid);
  inv_IDEX:  invg port map(i_A => s_IDEX_RD_isZero,  o_F => s_IDEX_RD_valid);
  inv_EXMEM: invg port map(i_A => s_EXMEM_RD_isZero, o_F => s_EXMEM_RD_valid);

  ---------------------------------------------------------------------------
  -- ADDRESS MATCH
  ---------------------------------------------------------------------------
  cmp_RS1_IDEX:  addr_compare port map(i_A => i_IFID_Inst(19 downto 15),
                                       i_B => i_IDEX_Inst(11 downto 7),
                                       o_Match => s_RS1_match_IDEX);
  cmp_RS2_IDEX:  addr_compare port map(i_A => i_IFID_Inst(24 downto 20),
                                       i_B => i_IDEX_Inst(11 downto 7),
                                       o_Match => s_RS2_match_IDEX);
  cmp_RS1_EXMEM: addr_compare port map(i_A => i_IFID_Inst(19 downto 15),
                                       i_B => i_EXMEM_Inst(11 downto 7),
                                       o_Match => s_RS1_match_EXMEM);
  cmp_RS2_EXMEM: addr_compare port map(i_A => i_IFID_Inst(24 downto 20),
                                       i_B => i_EXMEM_Inst(11 downto 7),
                                       o_Match => s_RS2_match_EXMEM);

  ---------------------------------------------------------------------------
  -- RAW HAZARD CONDITIONS
  -- Condition: usesRSx AND RSx_valid AND RD_valid AND writesRD AND addrMatch
  -- Built as chain: (usesRSx AND RSx_valid) AND (RD_valid AND writesRD) AND match
  ---------------------------------------------------------------------------

  -- RS1 vs IDEX
  gate_RS1_IDEX_ab:   andg2 port map(i_A => s_IFID_usesRS1,   i_B => s_RS1_valid,
                                     o_F => s_RS1_IDEX_ab); -- Is rs1 nonzero and actually consumed as reg
  gate_RS1_IDEX_cd:   andg2 port map(i_A => s_IDEX_RD_valid,  i_B => s_IDEX_writesRD,
                                     o_F => s_RS1_IDEX_cd); -- is rd from idex nonzero and actually produced
  gate_RS1_IDEX_abcd: andg2 port map(i_A => s_RS1_IDEX_ab,    i_B => s_RS1_IDEX_cd,
                                     o_F => s_RS1_IDEX_abcd);
                                     
--is rs1 a raw with the id/ex reg
  gate_RS1_IDEX_raw:  andg2 port map(i_A => s_RS1_IDEX_abcd,  i_B => s_RS1_match_IDEX,
                                     o_F => s_RS1_IDEX_raw); -- is rs1 valid, nonzero, is rd valid, nonzero and
                                     				--are they the same address

  -- RS2 vs IDEX
  gate_RS2_IDEX_ab:   andg2 port map(i_A => s_IFID_usesRS2,   i_B => s_RS2_valid,
                                     o_F => s_RS2_IDEX_ab); -- Is rs2 nonzero and actually consumed as reg
  gate_RS2_IDEX_cd:   andg2 port map(i_A => s_IDEX_RD_valid,  i_B => s_IDEX_writesRD,
                                     o_F => s_RS2_IDEX_cd); -- is rd from idex nonzero and actually produced
  gate_RS2_IDEX_abcd: andg2 port map(i_A => s_RS2_IDEX_ab,    i_B => s_RS2_IDEX_cd,
                                     o_F => s_RS2_IDEX_abcd); --both above true
  --is rs2 a raw with the id/ex reg
  gate_RS2_IDEX_raw:  andg2 port map(i_A => s_RS2_IDEX_abcd,  i_B => s_RS2_match_IDEX,
                                     o_F => s_RS2_IDEX_raw); -- is rs2 valid, nonzero, is rd valid, nonzero and
                                     				--are they the same address

  -- RS1 vs EXMEM
  gate_RS1_EXMEM_ab:   andg2 port map(i_A => s_IFID_usesRS1,   i_B => s_RS1_valid,
                                      o_F => s_RS1_EXMEM_ab);
  gate_RS1_EXMEM_cd:   andg2 port map(i_A => s_EXMEM_RD_valid, i_B => s_EXMEM_writesRD,
                                      o_F => s_RS1_EXMEM_cd);
  gate_RS1_EXMEM_abcd: andg2 port map(i_A => s_RS1_EXMEM_ab,   i_B => s_RS1_EXMEM_cd,
                                      o_F => s_RS1_EXMEM_abcd);
  gate_RS1_EXMEM_raw:  andg2 port map(i_A => s_RS1_EXMEM_abcd, i_B => s_RS1_match_EXMEM,
                                      o_F => s_RS1_EXMEM_raw);

  -- RS2 vs EXMEM
  gate_RS2_EXMEM_ab:   andg2 port map(i_A => s_IFID_usesRS2,   i_B => s_RS2_valid,
                                      o_F => s_RS2_EXMEM_ab);
  gate_RS2_EXMEM_cd:   andg2 port map(i_A => s_EXMEM_RD_valid, i_B => s_EXMEM_writesRD,
                                      o_F => s_RS2_EXMEM_cd);
  gate_RS2_EXMEM_abcd: andg2 port map(i_A => s_RS2_EXMEM_ab,   i_B => s_RS2_EXMEM_cd,
                                      o_F => s_RS2_EXMEM_abcd);
  gate_RS2_EXMEM_raw:  andg2 port map(i_A => s_RS2_EXMEM_abcd, i_B => s_RS2_match_EXMEM,
                                      o_F => s_RS2_EXMEM_raw);

  ---------------------------------------------------------------------------
  -- STALL CONDITIONS
  -- Stall only when the hazardous instruction in ID/EX is a load.
  -- EXMEM loads are resolved by forwarding ByteOut -- no stall.
  ---------------------------------------------------------------------------
  gate_RS1_stall: andg2 port map(i_A => s_RS1_IDEX_raw, i_B => s_IDEX_isLoad,
                                 o_F => s_RS1_IDEX_stall);
  gate_RS2_stall: andg2 port map(i_A => s_RS2_IDEX_raw, i_B => s_IDEX_isLoad,
                                 o_F => s_RS2_IDEX_stall);
  gate_load_stall: org2 port map(i_A => s_RS1_IDEX_stall, i_B => s_RS2_IDEX_stall,
                                 o_F => s_load_stall);

  -- Stall output vector: "11000" on load stall, else "00000"
  -- bit4=PC, bit3=IF/ID tied to s_load_stall; bits 2-0 always 0
  o_Stall <= s_load_stall & s_load_stall & "000";

  ---------------------------------------------------------------------------
  -- FORWARD CONDITIONS
  -- Forward from EX:    IDEX raw hazard AND IDEX resolves in EX (non-load)
  -- Forward from EXMEM: EXMEM raw hazard AND EXMEM resolves in EX (non-load)
  -- Forward from MEM:   EXMEM raw hazard AND EXMEM is a load
  --
  -- Priority: EX > EXMEM > MEM  (handled in source encoding when/else)
  ---------------------------------------------------------------------------
  gate_RS1_fwdEX:    andg2 port map(i_A => s_RS1_IDEX_raw,  i_B => s_IDEX_resolvesEX,
                                    o_F => s_RS1_fwd_EX);
  gate_RS2_fwdEX:    andg2 port map(i_A => s_RS2_IDEX_raw,  i_B => s_IDEX_resolvesEX,
                                    o_F => s_RS2_fwd_EX);
  gate_RS1_fwdEXMEM: andg2 port map(i_A => s_RS1_EXMEM_raw, i_B => s_EXMEM_resolvesEX,
                                    o_F => s_RS1_fwd_EXMEM);
  gate_RS2_fwdEXMEM: andg2 port map(i_A => s_RS2_EXMEM_raw, i_B => s_EXMEM_resolvesEX,
                                    o_F => s_RS2_fwd_EXMEM);
  gate_RS1_fwdMEM:   andg2 port map(i_A => s_RS1_EXMEM_raw, i_B => s_EXMEM_isLoad,
                                    o_F => s_RS1_fwd_MEM);
  gate_RS2_fwdMEM:   andg2 port map(i_A => s_RS2_EXMEM_raw, i_B => s_EXMEM_isLoad,
                                    o_F => s_RS2_fwd_MEM);

  ---------------------------------------------------------------------------
  -- FORWARD ENABLE: OR of all three forward conditions per RS
  ---------------------------------------------------------------------------
  gate_RS1_en_a: org2 port map(i_A => s_RS1_fwd_EX, i_B => s_RS1_fwd_EXMEM,
                               o_F => s_RS1_en_a);
  gate_RS1_en:   org2 port map(i_A => s_RS1_en_a,   i_B => s_RS1_fwd_MEM,
                               o_F => s_RS1_fwd_en);
  gate_RS2_en_a: org2 port map(i_A => s_RS2_fwd_EX, i_B => s_RS2_fwd_EXMEM,
                               o_F => s_RS2_en_a);
  gate_RS2_en:   org2 port map(i_A => s_RS2_en_a,   i_B => s_RS2_fwd_MEM,
                               o_F => s_RS2_fwd_en);

  ---------------------------------------------------------------------------
  -- FORWARD SOURCE ENCODING
  -- Priority: EX (00) > EXMEM ALU (01) > MEM ByteOut (10)
  -- when/else encodes priority naturally top-to-bottom
  ---------------------------------------------------------------------------
  s_RS1_src <=
    "00" when s_RS1_fwd_EX    = '1' else
    "01" when s_RS1_fwd_EXMEM = '1' else
    "10";  -- fwd_MEM or don't-care (enable=0)

  s_RS2_src <=
    "00" when s_RS2_fwd_EX    = '1' else
    "01" when s_RS2_fwd_EXMEM = '1' else
    "10";

  -- Assemble forwarding output vectors: {enable, src[1:0]}
  o_FWD_RS1 <= s_RS1_fwd_en & s_RS1_src;
  o_FWD_RS2 <= s_RS2_fwd_en & s_RS2_src;

  ---------------------------------------------------------------------------
  -- SQUASH OUTPUT VECTOR
  -- Load stall  -> squash ID/EX only:        bit2 = s_load_stall
  -- Branch/jump -> squash IF/ID and ID/EX:   bit3 = i_BranchJump, bit2 = i_BranchJump
  -- Both can assert simultaneously; OR for ID/EX squash
  -- bit3=IF/ID, bit2=ID/EX, bit1=EX/MEM, bit0=MEM/WB
  ---------------------------------------------------------------------------
  gate_squash_IDEX: org2 port map(i_A => i_BranchJump, i_B => s_load_stall,
                                  o_F => s_squash_IDEX);

  o_Squash <= i_BranchJump & s_squash_IDEX & "00";

end structure;
