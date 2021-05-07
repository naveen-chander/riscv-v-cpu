----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.01.2021 01:02:53
-- Design Name: 
-- Module Name: alu - Behavioral
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
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity alu is
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
end alu;

architecture Behavioral of alu is
signal y_temp   : std_logic_vector(width downto 0);
signal op1_int, op2_int, op3_int : signed(width downto 0);
signal temp : signed(width downto 0);
signal sum  : signed(width downto 0);
signal diff : signed(width downto 0);
signal prod : signed(width+width-1 downto 0);
signal prod_h : signed(width-1 downto 0);
signal prod_h_sext : signed(width downto 0);
signal mac  : signed(width downto 0);
signal msac : signed(width downto 0);

signal max_positive :signed(width-1 downto 0);
signal min_negative :signed(width-1 downto 0);

begin
op1_int <= op1(width-1)&op1;
op2_int <= op2(width-1)&op2;
op3_int <= op3(width-1)&op3;
max_positive <= x"7F" when WIDTH=8 else
                x"7FFF" when WIDTH=16 else
                x"7FFFFFFF" ;
  
min_negative <= x"80" when WIDTH=8 else
                x"8000" when WIDTH=16 else
                x"80000000" ;

--------------------------------------------

--------------------------------------------
--- Multiply 
prod <= ( (op1) * (op2));
prod_h <= prod(55 downto 24);	-- for 
--prod_h <= prod(31 downto 0);	-- for non fixed point integer ops
mac  <= op3_int + ('0'&prod_h);
msac <= op3_int - ('0'&prod_h);
-- Adder
sum  <=  op1_int + op2_int + 1 when cin = '1' else
		 op1_int + op2_int;
diff <= op1_int - op2_int;
--------------------------------------------
-- Mux to choose between Multiply and Add
process(prod,sum,diff, mac, msac, funct,op1_int,op2_int,prod_h)
begin
	case funct is		
		when "001"	=> temp <= prod(width downto 0);
		when "010"	=> temp <= '0'&prod_h;
		when "011"	=> temp <= mac;
		when "100"	=> temp <= msac;
		when "101"  => --ReLu Function  
			if op2_int > 0 then
				temp <= op2_int;
			else
				temp <= (others=>'0');
			end if;
		when "110"  => temp <= signed(shift_left(unsigned(op1_int), to_integer(unsigned(op2_int(4 downto 0)))));
		when "111"  => temp <= signed(shift_right(unsigned(op1_int), to_integer(unsigned(op2_int(4 downto 0)))));
		when others	=> temp <= sum;	
	end case;
end process;
--------------------------------------------
process(temp,max_positive,min_negative)
begin
--    if temp > (2**(WIDTH-1)-1) then
    if temp > max_positive then
        overflow    <='1';
        underflow   <='0';
--    elsif temp < -(2**(WIDTH-1)) then
    elsif temp < min_negative then
        overflow    <='0';
        underflow   <='1';   
    else
        overflow<='0';
        underflow<='0';
    end if;
end process;

    y_temp      <= std_logic_vector((temp));
    cout   <= y_temp(width);
    y <= signed(y_temp(WIDTH-1 downto 0));
    
end Behavioral;
