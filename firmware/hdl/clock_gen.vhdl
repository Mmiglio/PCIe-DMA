use ieee.numeric_std.all;
use work.numeric_std.all;

entity clock_gen is
  port (
    sysclk_in_p : in  std_logic;
    sysclk_in_n : in  std_logic;
    sysclk      : out std_logic;
    clk_i2c     : out std_logic
    );
end entity clock_gen;

architecture behavioural of clock_gen is
  signal sysclk_o : std_logic;

begin

  sysclk_inst : ibufds
    port map (
      I  => sysclk_in_p,
      IB => sysclk_in_n,
      O  => sysclk_o);

  bufg_i : ibufg
    port map (
      I => sysclk_o,
      O => sysclk);

  i2c_pll: entity work.clk_wix_i2c
    port map (
      clk_out1 => clk_i2c,
      reset    => '0',
      locked   => open,
      clk_in1  => sysclk);

end architecture behavioural;
