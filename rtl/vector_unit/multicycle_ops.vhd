----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.04.2021 03:37:50
-- Design Name: 
-- Module Name: top - Behavioral
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity multicycle_ops is
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
end multicycle_ops;

architecture Behavioral of multicycle_ops is
COMPONENT div_gen_0
  PORT (
    aclk 					: IN STD_LOGIC;
	aclken 					: IN STD_LOGIC;
    s_axis_divisor_tvalid 	: IN STD_LOGIC;
    s_axis_divisor_tready 	: OUT STD_LOGIC;
    s_axis_divisor_tdata 	: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_dividend_tvalid 	: IN STD_LOGIC;
    s_axis_dividend_tready 	: OUT STD_LOGIC;
    s_axis_dividend_tdata 	: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tvalid 		: OUT STD_LOGIC;
    m_axis_dout_tuser 		: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    m_axis_dout_tdata 		: OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
  
END COMPONENT;

signal count 					: std_logic_vector(5 downto 0);
signal s_axis_divisor_tvalid_s 	: STD_LOGIC;
signal s_axis_divisor_tready_s 	: STD_LOGIC;
signal s_axis_divisor_tdata_s 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
signal s_axis_dividend_tvalid_s	: STD_LOGIC;
signal s_axis_dividend_tready_s	: STD_LOGIC;
signal s_axis_dividend_tdata_s 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
signal m_axis_dout_tvalid_s 	: STD_LOGIC;
signal m_axis_dout_tuser_s 		: STD_LOGIC_VECTOR(0 DOWNTO 0);
signal m_axis_dout_tdata_s 		: STD_LOGIC_VECTOR(63 DOWNTO 0);


begin
divider_ip: div_gen_0 port map(
	aclk 					=> 	clk 						,
	aclken					=>	start						,
	s_axis_divisor_tvalid 	=> 	s_axis_divisor_tvalid_s 	,
	s_axis_divisor_tready 	=> 	s_axis_divisor_tready_s 	,
	s_axis_divisor_tdata 	=> 	s_axis_divisor_tdata_s 		,
	s_axis_dividend_tvalid 	=> 	s_axis_dividend_tvalid_s 	,
	s_axis_dividend_tready 	=> 	s_axis_dividend_tready_s 	,
	s_axis_dividend_tdata 	=> 	s_axis_dividend_tdata_s 	,
	m_axis_dout_tvalid 		=> 	m_axis_dout_tvalid_s 		,
	m_axis_dout_tuser 		=> 	m_axis_dout_tuser_s 		,
	m_axis_dout_tdata 		=> 	m_axis_dout_tdata_s 		
	);

counter: process(clk,reset)
begin
	if reset = '1' then
		count <= (others=>'0');
	elsif rising_edge(clk) then
		if m_axis_dout_tvalid_s = '1' then
			count <= (others=>'0');		-- Need to reset after every division op
		elsif start = '1' then
			count <= count + 1;
		else
			count <= (others=>'0');		-- For all instructions other than DIVIDE 
		end if;
	end if;
end process counter;


axi_inferface: process(clk,reset)
begin
	if reset = '1' then
		s_axis_divisor_tvalid_s  <= '0';
		s_axis_divisor_tdata_s   <= (others=>'0');
		s_axis_dividend_tvalid_s <= '0';
		s_axis_dividend_tdata_s  <= (others=>'0');
		quotient 			   	 <= (others=>'0');
		remainder 			   	 <= (others=>'0');
		divbyzero 			   	 <= '0';
	elsif rising_edge(clk) then
		if count = "000001"  then
			s_axis_divisor_tvalid_s  <= '1';
			s_axis_divisor_tdata_s   <= (op2);
			s_axis_dividend_tvalid_s <= '1';
			s_axis_dividend_tdata_s  <= (op1);
		else
			s_axis_divisor_tvalid_s  <= '0';
			s_axis_dividend_tvalid_s  <=  '0';				
		end if;
	-- Output 
		if m_axis_dout_tvalid_s = '1' then
			remainder  <= m_axis_dout_tdata_s(31 downto  0);
			quotient <= m_axis_dout_tdata_s(63 downto 32);
			divbyzero <= m_axis_dout_tuser_s(0);
		end if;
	end if;
end process axi_inferface;
BUSY  <= (not m_axis_dout_tvalid_s) and start; -- Will be HIGH Only for One Clock Cycle when the output is valid
end Behavioral;
