----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Company: DESE, IISc
-- Engineer: V Naveen Chander
-- 
-- Create Date: 26.04.2021 10:21:16
-- Design Name: 
-- Module Name: Xoutreg
-- Project Name: riscv_v_cpu
-- Target Devices: VC707 Board
-- Tool Versions: Vivado 2020.1/2
-- Description: Scalar Registers in Vector Execution Unit
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
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
library xil_defaultlib;
use xil_defaultlib.mypack.all;

entity Xoutreg is
    Port  ( 
	    clk 		: in  STD_LOGIC;
        reset 		: in  STD_LOGIC;	-- Asynchronous RESET
        WDATA       : in  alu_y_signed;
        RDATA       : out op_array;
        WE          : in  done_array
		);
end Xoutreg;

-----------------------------------------------------------------
architecture Behavioral of Xoutreg is
------------------------------------------------------------------
---------------------------------------------------------
------------		Xout reg 	--------------------------
-- Contains 8 registers - One register per lane
-- Each Register is meant to store scalar output of its
-- corresponding lane.
-- Read is asynchronous ; Write is Synchronous
-- These registers willl be eventually written to the XRF
-- upon compoeletion of the vector instruction.
-- --------------------------------------------------------
signal Xoutreg          :   op_array;		--Scalar Register in Each Vector Lane
begin
process(clk,reset)
begin
	-- Write Registers
	if reset = '1' then
		for i in 0 to 7 loop
			Xoutreg(i) <= (others=>'0');
		end loop;
	elsif rising_edge(clk) then
		for i in 0 to 7 loop
			if WE(i) = '1' then
				Xoutreg(i) <= std_logic_vector(WDATA(i));
			end if;
		end loop;
	end if;
	--- Xoutreg READ
	for i in 0 to 7 loop
		RDATA(i) <= Xoutreg(i);
	end loop;
end process;
end Behavioral;