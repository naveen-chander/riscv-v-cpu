----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.02.2021 09:57:20
-- Design Name: 
-- Module Name: mypack - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
package mypack is

type i_rec is record
	start   : std_logic;
	vs1     : std_logic_vector(4 downto 0);
	vs2     : std_logic_vector(4 downto 0);
	vd      : std_logic_vector(4 downto 0);
	RS1     : std_logic_vector(31 downto 0);
	RS2     : std_logic_vector(31 downto 0);
	uimm5   : std_logic_vector(4 downto 0);
	funct   : std_logic_vector(3 downto 0);
	permute : std_logic_vector(1 downto 0);
	mask_en : std_logic;
	ALUSrc  : std_logic_vector(1 downto 0);
	dmr     : std_logic;
	dmw     : std_logic;
	reg_we  : std_logic;
	mem_reg : std_logic;
	mode_lsu: std_logic_vector(1 downto 0);
end record i_rec;

type alu_output is record    	 
    y         : signed(31 downto 0);    	 
    cout 	  : std_logic;
    overflow  : std_logic;
    underflow : std_logic;
end record alu_output;
    
  
type vrf_bank_t is record
    vs1       : std_logic_vector(4 downto 0);    	 
    vs2 	  : std_logic_vector(4 downto 0);
    vd  	  : std_logic_vector(4 downto 0);
    we        : std_logic;
    DATA_WR   : std_logic_vector(31 downto 0);
end record vrf_bank_t;
    
constant i_rec_init : i_rec := 
(
    start   => '0',
    vs1     => (others=>'0'),
    vs2     => (others=>'0'),
    vd      => (others=>'0'),
    RS1     => (others=>'0'),
    RS2     => (others=>'0'),
	uimm5	=> (others=>'0'),
    funct   => (others=>'0'),
    permute => (others=>'0'),
    mask_en => '0',
    ALUSrc  => (others=>'0'),
	dmr     => '0',
	dmw     => '0',
	reg_we  => '0',
	mem_reg => '0',
	mode_lsu=> (others=>'0')
 );
 
 constant alu_output_init : alu_output :=
 (
 y => (others=>'0'),
 cout => '0',
 overflow => '0',
 underflow => '0'
 );
 
 type array_i_rec is array(0 to 7) of i_rec;
 type ALU_output_array is array(0 to 7) of alu_output;
 type vrf_bank_t_array is array(0 to 7) of vrf_bank_t;
 type ALU_y_signed  is array(0 to 7) of signed(31 downto 0);
type count_array is array(0 to 7) of std_logic_vector(5 downto 0);
type done_array is array(0 to 7) of std_logic;
type op_array is array(0 to 7) of std_logic_vector(31 downto 0);
type dmem_addr_array is array(0 to 7) of std_logic_vector(11 downto 0);
type reg_array is array (31 downto 0) of std_logic_vector(31 downto 0);
--------------------------------------------------------------------
---  COmponent Definitions ---------------------
--------------------------------------------------------------------
component alu is
generic(width : integer :=32);
    Port ( op1 : in signed (width-1 downto 0);
           op2 : in signed (width-1 downto 0);
           op3 : in signed (width-1 downto 0);
		   funct: in std_logic_vector(2 downto 0); -- '0' => ADD ; '1' => Multiply
           cin  : in STD_LOGIC;
           y    : out signed(width-1 downto 0);
           cout : out std_logic;
           overflow : out std_logic;
           underflow : out std_logic
           );
end component;
-----------------------------------------------------------------
component multicycle_ops is
generic(width : integer :=32);
    Port ( 
		clk 		: in  STD_LOGIC;
        reset		: in  STD_LOGIC;
		op1 		: in  STD_LOGIC_VECTOR (WIDTH-1 downto 0);
        op2 		: in  STD_LOGIC_VECTOR (WIDTH-1 downto 0);
        quotient 	: out STD_LOGIC_VECTOR (31 downto 0);
        remainder 	: out STD_LOGIC_VECTOR (31 downto 0);
		BUSY		: out STD_LOGIC;
        divbyzero 	: out STD_LOGIC;
        start 		: in  STD_LOGIC
		);
end component;
-----------------------------------------------------------------
component count_gen is
port(
	clk 			: in  STD_LOGIC;
    reset 			: in  STD_LOGIC;
	start			: in  STD_LOGIC;
	illegal			: in  STD_LOGIC;
	ENABLE			: in  STD_LOGIC;
	vl				: in  STD_LOGIC_VECTOR(8 DOWNTO 0);
	count			: out STD_LOGIC_VECTOR(5 DOWNTO 0);
	DONE			: out STD_LOGIC
);
end component;
-----------------------------------------------
component vrf_bank is
generic(width : integer :=32);
    Port (  clk 		: in  STD_LOGIC;
            reset 		: in  STD_LOGIC;
			bankID      : in  integer range 0 to 7;	-- To specify initialization pattern	
			wr_count	: in  STD_LOGIC_VECTOR(5  downto 0);	-- To calculate vreg_offset for write
			rd_count	: in  STD_LOGIC_VECTOR(5  downto 0);	-- To calculate vreg_offset for read
			shift_count : in  STD_LOGIC_VECTOR(5  downto 0);    -- To calculate vreg_offset for read
			DONE		: in  STD_LOGIC;
			vl			: in  STD_LOGIC_VECTOR(8  downto 0);
			vd			: in  STD_LOGIC_VECTOR(4  downto 0);
			vs1			: in  STD_LOGIC_VECTOR(4  downto 0);
			vs2			: in  STD_LOGIC_VECTOR(4  downto 0);
			vs3			: in  STD_LOGIC_VECTOR(4  downto 0);	-- vd from Instruction without delay
			vs4			: in  STD_LOGIC_VECTOR(4  downto 0);	-- vs2 from Instruction for Vector Permutations
			DATA_WR		: in  STD_LOGIC_VECTOR(31 downto 0);
			WE			: in  STD_LOGIC;
			v0_DATA		: out STD_LOGIC_VECTOR(width -1 downto 0);
			DATA_RD1	: out STD_LOGIC_VECTOR(31 downto 0);	--vs1 Data
			DATA_RD2	: out STD_LOGIC_VECTOR(31 downto 0);	-- vs2 Data
			DATA_RD3	: out STD_LOGIC_VECTOR(31 downto 0);		--vd Data
			DATA_RD4	: out STD_LOGIC_VECTOR(31 downto 0)		--vd Data
			);
end component;
-----------------------------------------------
component lsu is
port(
	RS1				: in  STD_LOGIC_VECTOR(31 DOWNTO 0);		-- Scalar Reg Store Data
	RS2				: in  STD_LOGIC_VECTOR(31 DOWNTO 0);		-- ScalarReg Store Addr/Dataend lsu;
	MODE    		: in  STD_LOGIC_VECTOR(1 DOWNTO 0);
	count   		: in  STD_LOGIC_VECTOR(5 downto 0);
	V_OFFSET		: in  STD_LOGIC_VECTOR(31 DOWNTO 0);
	y_prev  		: in  STD_LOGIC_VECTOR(31 downto 0);
	y       		: out STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
end component;
-----------------------------------------------
-- Memory Components
COMPONENT DMEM_0
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------
COMPONENT DMEM_1
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

----------------------------------------------
COMPONENT DMEM_2
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------
COMPONENT DMEM_3
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------
COMPONENT DMEM_4
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------
COMPONENT DMEM_5
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------
COMPONENT DMEM_6
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------
COMPONENT DMEM_7
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

component stall_gen is
    Port ( 
    clk         	: in STD_LOGIC;
    reset       	: in STD_LOGIC;
    stall_in    	: in STD_LOGIC;
    stall_out   	: out STD_LOGIC);
end component;
-----------------------------------------------
component dmem_xbar is
generic(DMEM_ADDR_WIDTH : integer :=10);
	port(
		WR_ADDR 	: in  op_array;
		RD_ADDR 	: in  op_array;
		DIN			: in  op_array;
		DATA_RD_IN	: in  op_array;
		WE          : in  done_array;
		RE          : in  done_array;
		PortA_ADDR  : out DMEM_addr_array;
		PortA_WE    : out done_array;
		PortA_DIN   : out op_array;
		DATA_RD_OUT : out op_array     
		);
end component;
-----------------------------------------------
-----------------------------------------------
-----------------------------------------------
-----------------------------------------------
 end package mypack; 
