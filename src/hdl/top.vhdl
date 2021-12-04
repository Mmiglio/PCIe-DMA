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
    pci_exp_txn : out std_logic_vector(7 downto 0)
  );
end top_kcu;

architecture arch of top_kcu is

  -- Registers
  constant reg_addr_width : natural := 4;
  signal read_reg         : slave_registers((2 ** reg_addr_width) - 1 downto 0);
  signal write_reg        : slave_registers((2 ** reg_addr_width) - 1 downto 0);

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

  component vio_0
  port (
    clk         : in std_logic;
    probe_in0   : in std_logic_vector(31 downto 0);
    probe_in1   : in std_logic_vector(31 downto 0)
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

  read_reg <= write_reg;

  ---------------------------
  -- Debug VIO
  ---------------------------
  vio_dbg : vio_0
  port map(
    clk => axi_clk,
    probe_in0 => read_reg(0),
    probe_in1 => read_reg(1)
  );

end architecture;