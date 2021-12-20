library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.datatypes.all;

entity top_kcu is
  port (
    sysclk_in_p : in std_logic;
    sysclk_in_n : in std_logic;
    sys_rst_n   : in std_logic;

    pci_exp_rxp : in std_logic_vector(7 downto 0);
    pci_exp_rxn : in std_logic_vector(7 downto 0);
    pci_exp_txp : out std_logic_vector(7 downto 0);
    pci_exp_txn : out std_logic_vector(7 downto 0);

    sda                 : inout std_logic;
    scl                 : inout std_logic;
    I2C_MAIN_RESET_B_LS : out std_logic;
    SYSCLK_P            : in std_logic;
    SYSCLK_N            : in std_logic
  );
end top_kcu;

architecture arch of top_kcu is

  -- Registers
  constant reg_addr_width  : natural                                := 4 + 2 + 1; -- (2 bits for addressing + 1 doubling (*2))
  constant num_half_regs   : natural                                := 2 ** (reg_addr_width - 1 - 2);
  constant num_regs        : natural                                := 2 ** (reg_addr_width - 2);
  signal read_reg          : slave_registers(num_regs - 1 downto 0) := (others => (others => '0'));
  signal write_reg         : slave_registers(num_regs - 1 downto 0);
  signal write_reg_l       : slave_registers(num_regs - 1 downto 0);
  signal read_reg_i        : slave_registers(num_half_regs - 1 downto 0) := (others => (others => '0'));
  signal axi_clk, axi_rstn : std_logic;
  signal pcie_lnk_up       : std_logic := '0';

  -- AXI Lite
  signal m_axil_awaddr, m_axil_araddr   : std_logic_vector(31 downto 0);
  signal m_axil_awprot, m_axil_arprot   : std_logic_vector(2 downto 0);
  signal m_axil_awvalid, m_axil_awready : std_logic; -- Write address ready/valid
  signal m_axil_arvalid, m_axil_arready : std_logic;
  signal m_axil_wdata, m_axil_rdata     : std_logic_vector(31 downto 0);
  signal m_axil_wstrb                   : std_logic_vector(3 downto 0);
  signal m_axil_wvalid, m_axil_wready   : std_logic; -- Write data valid/ready
  signal m_axil_rvalid, m_axil_rready   : std_logic;
  signal m_axil_bvalid, m_axil_bready   : std_logic; -- Write response valid/ready
  signal m_axil_rresp, m_axil_bresp     : std_logic_vector(1 downto 0);

  -- AXI stream
  signal m_axis_c2h_tdata_0, m_axis_h2c_tdata_0   : std_logic_vector(255 downto 0);
  signal m_axis_c2h_tlast_0, m_axis_h2c_tlast_0   : std_logic;
  signal m_axis_c2h_tvalid_0, m_axis_h2c_tvalid_0 : std_logic;
  signal m_axis_c2h_tready_0, m_axis_h2c_tready_0 : std_logic;
  signal m_axis_c2h_tkeep_0, m_axis_h2c_tkeep_0   : std_logic_vector(31 downto 0);

  -- Clock signals
  signal sysclk, clk_i2c : std_logic;

  -- I2C signals
  signal rst_i2c                  : std_logic := '0';
  signal str_wr, str_rd           : std_logic := '0';
  signal rst_freq                 : std_logic := '0';
  signal data_rd_reg, data_wr_reg : pll_registers;
  signal data_rd_sw               : std_logic_vector(7 downto 0) := (others => '0');

  -- Components
  component vio_0
    port (
      clk        : in std_logic;
      probe_in0  : in std_logic_vector(31 downto 0);
      probe_in1  : in std_logic_vector(31 downto 0);
      probe_in2  : in std_logic_vector(31 downto 0);
      probe_in3  : in std_logic_vector(31 downto 0);
      probe_in4  : in std_logic_vector(7 downto 0);
      probe_in5  : in std_logic_vector(7 downto 0);
      probe_in6  : in std_logic_vector(7 downto 0);
      probe_in7  : in std_logic_vector(7 downto 0);
      probe_in8  : in std_logic_vector(7 downto 0);
      probe_in9  : in std_logic_vector(7 downto 0);
      probe_in10 : in std_logic_vector(7 downto 0)
    );
  end component;

begin

  ---------------------------
  -- DMA engine
  ---------------------------
  dma_engine_i : entity work.xilinx_dma_pcie_ep
    generic map(
      PL_LINK_CAP_MAX_LINK_WIDTH => 8,
      PL_SIM_FAST_LINK_TRAINING  => false,
      PL_LINK_CAP_MAX_LINK_SPEED => 4,
      C_DATA_WIDTH               => 256,
      EXT_PIPE_SIM               => false,
      C_ROOT_PORT                => false,
      C_DEVICE_NUMBER            => 0)
    port map(
      pci_exp_txp => pci_exp_txp,
      pci_exp_txn => pci_exp_txn,
      pci_exp_rxp => pci_exp_rxp,
      pci_exp_rxn => pci_exp_rxn,
      sys_clk_p   => sysclk_in_p,
      sys_clk_n   => sysclk_in_n,
      sys_rst_n   => sys_rst_n,
      -- AXI Master Write Address Channel
      m_axil_awaddr  => m_axil_awaddr,
      m_axil_awprot  => m_axil_awprot,
      m_axil_awvalid => m_axil_awvalid,
      m_axil_awready => m_axil_awready,
      -- AXI Master Write Data Channel
      m_axil_wdata  => m_axil_wdata,
      m_axil_wstrb  => m_axil_wstrb,
      m_axil_wvalid => m_axil_wvalid,
      m_axil_wready => m_axil_wready,
      -- AXI Master Write Response Channel
      m_axil_bvalid => m_axil_bvalid,
      m_axil_bready => m_axil_bready,
      -- AXI Master Read Address Channel
      m_axil_araddr  => m_axil_araddr,
      m_axil_arprot  => m_axil_arprot,
      m_axil_arvalid => m_axil_arvalid,
      m_axil_arready => m_axil_arready,
      -- AXI Master Read Data Channel
      m_axil_rdata        => m_axil_rdata,
      m_axil_rresp        => m_axil_rresp,
      m_axil_rvalid       => m_axil_rvalid,
      m_axil_rready       => m_axil_rready,
      m_axil_bresp        => m_axil_bresp,
      axi_clk             => axi_clk,
      axi_rstn            => axi_rstn,
      pcie_lnk_up         => pcie_lnk_up,
      m_axis_c2h_tdata_0  => m_axis_c2h_tdata_0,
      m_axis_h2c_tdata_0  => m_axis_h2c_tdata_0,
      m_axis_c2h_tlast_0  => m_axis_c2h_tlast_0,
      m_axis_h2c_tlast_0  => m_axis_h2c_tlast_0,
      m_axis_c2h_tvalid_0 => m_axis_c2h_tvalid_0,
      m_axis_h2c_tvalid_0 => m_axis_h2c_tvalid_0,
      m_axis_c2h_tready_0 => m_axis_c2h_tready_0,
      m_axis_h2c_tready_0 => m_axis_h2c_tready_0,
      m_axis_c2h_tkeep_0  => m_axis_c2h_tkeep_0,
      m_axis_h2c_tkeep_0  => m_axis_h2c_tkeep_0);

  -- Loopback
  m_axis_c2h_tdata_0  <= m_axis_h2c_tdata_0;
  m_axis_c2h_tlast_0  <= m_axis_h2c_tlast_0;
  m_axis_c2h_tvalid_0 <= m_axis_h2c_tvalid_0;
  m_axis_h2c_tready_0 <= m_axis_c2h_tready_0;
  m_axis_c2h_tkeep_0  <= m_axis_h2c_tkeep_0;

  ---------------------------
  -- AXI4-lite registers bank
  ---------------------------
  axi_register_interface : entity work.axi_lite_registers
    generic map(
      C_S_AXI_DATA_WIDTH => 32,
      C_S_AXI_ADDR_WIDTH => reg_addr_width
    )
    port map(
      -- register interface
      S_RD_REG => read_reg,
      S_WR_REG => write_reg,
      -- axi interface
      S_AXI_ACLK    => axi_clk,
      S_AXI_ARESETN => axi_rstn,
      S_AXI_ARADDR  => m_axil_araddr(reg_addr_width - 1 downto 0),
      S_AXI_ARPROT  => m_axil_arprot,
      S_AXI_ARREADY => m_axil_arready,
      S_AXI_ARVALID => m_axil_arvalid,
      S_AXI_AWADDR  => m_axil_awaddr(reg_addr_width - 1 downto 0),
      S_AXI_AWPROT  => m_axil_awprot,
      S_AXI_AWREADY => m_axil_awready,
      S_AXI_AWVALID => m_axil_awvalid,
      S_AXI_BREADY  => m_axil_bready,
      S_AXI_BRESP   => m_axil_bresp,
      S_AXI_BVALID  => m_axil_bvalid,
      S_AXI_RDATA   => m_axil_rdata,
      S_AXI_RREADY  => m_axil_rready,
      S_AXI_RRESP   => m_axil_rresp,
      S_AXI_RVALID  => m_axil_rvalid,
      S_AXI_WDATA   => m_axil_wdata,
      S_AXI_WREADY  => m_axil_wready,
      S_AXI_WSTRB   => m_axil_wstrb,
      S_AXI_WVALID  => m_axil_wvalid
    );

  ---------------------------
  -- Create clocks
  ---------------------------
  clk_gen : entity work.clock_gen
    port map(
      sysclk_in_p => SYSCLK_P,
      sysclk_in_n => SYSCLK_N,
      sysclk      => sysclk,
      clk_i2c     => clk_i2c
    );

  ---------------------------
  -- I2C to set pll
  ---------------------------
  i2c_i : entity work.i2c_driver port map (
    clk         => clk_i2c,
    reset       => rst_i2c,
    str_wr      => str_wr,
    str_rd      => str_rd,
    rst_freq    => rst_freq,
    data_rd_sw  => data_rd_sw,
    data_rd_reg => data_rd_reg,
    data_wr_reg => data_wr_reg,
    sda         => sda,
    scl         => scl
    );
  I2C_MAIN_RESET_B_LS <= '1';

  ---------------------------
  -- Registers
  ---------------------------
  latch_wr_reg : process (write_reg)
  begin
    write_reg_l <= write_reg;
  end process latch_wr_reg;

  -- connect first half of read regs with write regs
  read_reg(num_half_regs - 1 downto 0)        <= write_reg(num_half_regs - 1 downto 0);
  read_reg(num_regs - 1 downto num_half_regs) <= read_reg_i(num_half_regs - 1 downto 0);

  decode_reg : process (write_reg_l) is
  begin
    rst_freq <= write_reg_l(0)(0); --reset default values 
    str_wr   <= write_reg_l(0)(1); --enable write
    str_rd   <= write_reg_l(0)(2); --enable read

    -- write registers
    data_wr_reg(0) <= write_reg_l(1)(7 downto 0);  --reg7
    data_wr_reg(1) <= write_reg_l(1)(15 downto 8); --reg8
    data_wr_reg(2) <= write_reg_l(1)(23 downto 16);--reg9
    data_wr_reg(3) <= write_reg_l(1)(31 downto 24);--reg10

    data_wr_reg(4) <= write_reg_l(2)(7 downto 0);  --reg11
    data_wr_reg(5) <= write_reg_l(2)(15 downto 8); --reg12

    -- read registers
    -- in read_reg(num_regs-1 downto num_half_regs)
    read_reg_i(0)(7 downto 0)   <= data_rd_reg(0); --reg7
    read_reg_i(0)(15 downto 8)  <= data_rd_reg(1); --reg8
    read_reg_i(0)(23 downto 16) <= data_rd_reg(2); --reg9
    read_reg_i(0)(31 downto 24) <= data_rd_reg(3); --reg10

    read_reg_i(1)(7 downto 0)   <= data_rd_reg(4); --reg11
    read_reg_i(1)(15 downto 8)  <= data_rd_reg(5); --reg12
    read_reg_i(1)(23 downto 16) <= data_rd_sw;

  end process decode_reg;

  vio_dbg : vio_0
  port map(
    clk        => axi_clk,
    probe_in0  => read_reg(0),
    probe_in1  => read_reg(1),
    probe_in2  => write_reg(0),
    probe_in3  => write_reg(1),
    probe_in4  => data_rd_reg(0),
    probe_in5  => data_rd_reg(1),
    probe_in6  => data_rd_reg(2),
    probe_in7  => data_rd_reg(3),
    probe_in8  => data_rd_reg(4),
    probe_in9  => data_rd_reg(5),
    probe_in10 => data_rd_sw
  );

end architecture;