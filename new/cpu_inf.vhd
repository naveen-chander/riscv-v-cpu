----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.04.2021 10:49:14
-- Design Name: 
-- Module Name: cpu_inf - Behavioral
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
library xil_defaultlib;
use xil_defaultlib.mypack.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
------------------------------------------------------------------
-- Memory Map
-- DMEM
-- 0x0004_0000 - 0x0004_3FFF    : DMEM_Bank0
-- 0x0004_4000 - 0x0004_7FFF    : DMEM_Bank1
-- 0x0004_8000 - 0x0004_BFFF    : DMEM_Bank2
-- 0x0004_C000 - 0x0004_FFFF    : DMEM_Bank3
-- 0x0005_0000 - 0x0005_3FFF    : DMEM_Bank4
-- 0x0005_4000 - 0x0005_7FFF    : DMEM_Bank5
-- 0x0005_8000 - 0x0005_BFFF    : DMEM_Bank6
-- 0x0005_C000 - 0x0005_FFFF    : DMEM_Bank7
-----------------------------------------------
-- VREG
-- 0x0008_0000 - 0x0008_007F    : VREG_Bank0
-- 0x0008_0000 - 0x0008_00FF    : VREG_Bank1
-- 0x0008_0000 - 0x0008_017F    : VREG_Bank2
-- 0x0008_0000 - 0x0008_01FF    : VREG_Bank3
-- 0x0008_0000 - 0x0008_027F    : VREG_Bank4
-- 0x0008_0000 - 0x0008_02FF    : VREG_Bank5
-- 0x0008_0000 - 0x0008_037F    : VREG_Bank6
-- 0x0008_0000 - 0x0008_03FF    : VREG_Bank7
-------------------------------------------------


entity cpu_inf is
    Port ( clk          : in STD_LOGIC;
           reset        : in STD_LOGIC;
           ADDR_IN      : in STD_LOGIC_VECTOR (31 downto 0);
           DMEM_DATA_RD : in op_array;
           VREG_DATA_RD : in op_array;
           WE_IN        : in STD_LOGIC;
           vs1          : out STD_LOGIC_VECTOR (4 downto 0);
           vd           : out STD_LOGIC_VECTOR (4 downto 0);
           mem_addr     : out STD_LOGIC_VECTOR (11 downto 0);
           DMEM_WE      : out done_array;
           VREG_WE      : out done_array;
           dout         : out STD_LOGIC_VECTOR (31 downto 0));
end cpu_inf;

architecture Behavioral of cpu_inf is
signal reg_bank_sel     : std_logic_vector(2 downto 0);
signal mem_bank_sel     : std_logic_vector(2 downto 0);
signal mem_bank_sel_reg : std_logic_vector(2 downto 0);

signal dmem_cs          : std_logic;        -- Active high Chip Select for Vector Data memory
signal dmem_cs_reg      : std_logic;        -- Delayed  Chip Select for Vector Data memory read
signal vreg_cs          : std_logic;        -- Active high Chip Select for Vector Registers  

signal vreg_dout        : std_logic_vector(31 downto 0);
signal vreg_dout_reg    : std_logic_vector(31 downto 0);
signal dmem_dout        : std_logic_vector(31 downto 0);

constant DMEM_START     : unsigned(31 downto 0):= x"00040000";
constant DMEM_END       : unsigned(31 downto 0):= x"0005FFFC";
constant VREG_START     : unsigned(31 downto 0):= x"00080000";
constant VREG_END       : unsigned(31 downto 0):= x"000803FC";

begin
reg_bank_sel    <= ADDR_IN(4 downto 2);
mem_bank_sel    <= ADDR_IN(4 downto 2);

dmem_cs <= '1' when ( (unsigned(ADDR_IN) >= DMEM_START) and (unsigned(ADDR_IN) <= DMEM_END) ) else
           '0';

vreg_cs <= '1' when ( (unsigned(ADDR_IN) >= VREG_START) and (unsigned(ADDR_IN) <= VREG_END) ) else
           '0';

------------ To Regiser /Memory Signals
vs1 <= ADDR_IN(9 downto 5);     -- 
vd  <= ADDR_IN(9 downto 5);
mem_addr <= ADDR_IN(16 downto 5);       -- Each 4 Bytes x 8 banks = 32 ; log(32)=5
-------------------------------------------------------
-- Dmem Write to all banks
DMEM_WE_gen: process(ADDR_IN, WE_IN, dmem_cs, mem_bank_sel)
begin
    if dmem_cs ='1' then
        case (mem_bank_sel) is
            when "000" => 
                for j in 0 to 7 loop
                    if j = 0 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop;
            --------------------------------
            when "001" => 
                for j in 0 to 7 loop
                    if j = 1 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop;
            --------------------------------
            when "010" => 
                for j in 0 to 7 loop
                    if j = 2 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop;  
            --------------------------------
            when "011" => 
                for j in 0 to 7 loop
                    if j = 3 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop;  
            --------------------------------
            when "100" => 
                for j in 0 to 7 loop
                    if j = 4 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop;  
            --------------------------------
            when "101" => 
                for j in 0 to 7 loop
                    if j = 5 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop; 
            --------------------------------
            when "110" => 
                for j in 0 to 7 loop
                    if j = 6 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop; 
            --------------------------------
            when "111" => 
                for j in 0 to 7 loop
                    if j = 7 then
                        DMEM_WE(j) <= WE_IN;
                    else
                        DMEM_WE(j) <= '0';
                    end if;
                end loop;    
            --------------------------------    
                -- Default Case
                when others =>
                    for j in 0 to 7 loop
                        DMEM_WE(j) <= '0';
                    end loop;
                -----------------
        end case;
    else        -- If DMEM not selected DO NOT Write 
        for i in 0 to 7 loop
            DMEM_WE(i) <= '0';
        end loop;
    end if;  
end process DMEM_WE_gen;
----------------------------------------------------------
----------------------------------------------------------
-- VREG Write 
VREG_WE_gen: process(ADDR_IN, WE_IN, vreg_cs,reg_bank_sel)
begin
    if vreg_cs ='1' then
        case (reg_bank_sel) is
            when "000" => 
                for j in 0 to 7 loop
                    if j = 0 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop;
            --------------------------------
            when "001" => 
                for j in 0 to 7 loop
                    if j = 1 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop;
            --------------------------------
            when "010" => 
                for j in 0 to 7 loop
                    if j = 2 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop;  
            --------------------------------
            when "011" => 
                for j in 0 to 7 loop
                    if j = 3 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop;  
            --------------------------------
            when "100" => 
                for j in 0 to 7 loop
                    if j = 4 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop;  
            --------------------------------
            when "101" => 
                for j in 0 to 7 loop
                    if j = 5 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop; 
            --------------------------------
            when "110" => 
                for j in 0 to 7 loop
                    if j = 6 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop; 
            --------------------------------
            when "111" => 
                for j in 0 to 7 loop
                    if j = 7 then
                        VREG_WE(j) <= WE_IN;
                    else
                        VREG_WE(j) <= '0';
                    end if;
                end loop;    
            --------------------------------    
                -- Default Case
                when others =>
                    for j in 0 to 7 loop
                        VREG_WE(j) <= '0';
                    end loop;
                -----------------
        end case;
    else        -- If DMEM not selected DO NOT Write 
        for i in 0 to 7 loop
            VREG_WE(i) <= '0';
        end loop;
    end if;  
end process VREG_WE_gen;
-----------------------------------------------------------
-- Delay the Memory Bank Selects (Bank Select and Chip Select) One Clock Cycle
-- So that it comes when DMEM_DATA is presented
MEM_BANK_SEL_REGISTER: process(clk,reset)
begin
    if reset = '1' then
        mem_bank_sel_reg <= (others=>'0');
        dmem_cs_reg      <= '0';
    elsif rising_edge(clk) then
        mem_bank_sel_reg <= mem_bank_sel;
        dmem_cs_reg      <= dmem_cs;
    end if;
    end process MEM_BANK_SEL_REGISTER;
------------------------------------------------------------
-- Data Memory Read Data Selector
DMEM_SELECTOR: process(DMEM_DATA_RD, mem_bank_sel_reg)
begin
    case mem_bank_sel_reg is
        when "000" => dmem_dout <= DMEM_DATA_RD(0); 
        when "001" => dmem_dout <= DMEM_DATA_RD(1); 
        when "010" => dmem_dout <= DMEM_DATA_RD(2); 
        when "011" => dmem_dout <= DMEM_DATA_RD(3); 
        when "100" => dmem_dout <= DMEM_DATA_RD(4); 
        when "101" => dmem_dout <= DMEM_DATA_RD(5); 
        when "110" => dmem_dout <= DMEM_DATA_RD(6); 
        when "111" => dmem_dout <= DMEM_DATA_RD(7); 
        when others=> dmem_dout <= DMEM_DATA_RD(7);
    end case;
end process DMEM_SELECTOR;
-----------------------------------------------------------
-- Data Memory Read Data Selector
VREG_SELECTOR: process(VREG_DATA_RD, reg_bank_sel)
begin
    case reg_bank_sel is
        when "000" => vreg_dout <= VREG_DATA_RD(0); 
        when "001" => vreg_dout <= VREG_DATA_RD(1); 
        when "010" => vreg_dout <= VREG_DATA_RD(2); 
        when "011" => vreg_dout <= VREG_DATA_RD(3); 
        when "100" => vreg_dout <= VREG_DATA_RD(4); 
        when "101" => vreg_dout <= VREG_DATA_RD(5); 
        when "110" => vreg_dout <= VREG_DATA_RD(6); 
        when "111" => vreg_dout <= VREG_DATA_RD(7); 
        when others=> vreg_dout <= VREG_DATA_RD(7);
    end case;
end process VREG_SELECTOR;
------------------------------------------------------------
-- Delay the Register Data by One Clock Cycle
-- So that it comes as the same delay as memory data
VREG_DOUT_REGISTER: process(clk,reset)
begin
    if reset = '1' then
        vreg_dout_reg <= (others=>'0');
    elsif rising_edge(clk) then
        vreg_dout_reg <= vreg_dout;
    end if;
    end process VREG_DOUT_REGISTER;
------------------------------------------------------------

------------------------------------------------------------
READ_DATA_SELECTOR: process(dmem_dout,vreg_dout_reg,dmem_cs_reg)
begin
    if dmem_cs_reg = '1' then
        dout <= dmem_dout;
    else
        dout <=vreg_dout_reg;
    end if;
end process READ_DATA_SELECTOR;
------------------------------------------------------------
end Behavioral;

