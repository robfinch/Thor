----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/30/2015 07:06:35 PM
-- Design Name: 
-- Module Name: dpti_demo - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dpti_demo is
    Port ( 
           prog_clko    : in  STD_LOGIC;
           prog_rxen      : in  STD_LOGIC;
           prog_txen      : in  STD_LOGIC;
           prog_spien   : in  STD_LOGIC; --called jtagen on some platforms
           prog_rdn       : out  STD_LOGIC;
           prog_wrn       : out  STD_LOGIC;
           prog_oen       : out  STD_LOGIC;
           prog_siwun     : out STD_LOGIC;
           prog_d      : inout  STD_LOGIC_VECTOR (7 downto 0);
           sysclk : in std_logic;
    btnrst : in STD_LOGIC);
end dpti_demo;

architecture Behavioral of dpti_demo is

signal fifoEn : std_logic;

signal  usrFull  : std_logic;
signal  usrEmpty  : std_logic;
signal  usrData  : std_logic_vector(7 downto 0);

begin

fifoEn <= not(usrFull) and not(usrEmpty);

dpti_comp : entity work.dpti_ctrl
  port map
   (
    wr_clk => sysclk,
    wr_en => fifoEn,
    wr_full => usrFull,
    wr_afull => open,
    wr_err => open,
    wr_count => open,
    wr_di => usrData,
    
    rd_clk => sysclk,
    rd_en => fifoEn,
    rd_empty => usrEmpty,
    rd_aempty => open,
    rd_err => open,
    rd_count => open,
    rd_do => usrData,
    
    rst => btnrst,
    
    prog_clko => prog_clko,
    prog_rxen => prog_rxen,
    prog_txen => prog_txen,
    prog_spien => prog_spien,
    prog_rdn => prog_rdn,
    prog_wrn => prog_wrn,
    prog_oen => prog_oen,
    prog_siwun => prog_siwun,
    prog_d => prog_d
    );
    

end Behavioral;
