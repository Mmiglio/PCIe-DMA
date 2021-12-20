library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package datatypes is
  -- AXI lite registers
  type slave_registers is array (natural range <>) of std_logic_vector(31 downto 0);

  -- PLL registers
  type pll_registers is array (natural range 0 to 5) of std_logic_vector(7 downto 0);
end datatypes;