library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package datatypes is
  type slave_registers is array (natural range <>) of std_logic_vector(31 downto 0);
end datatypes;