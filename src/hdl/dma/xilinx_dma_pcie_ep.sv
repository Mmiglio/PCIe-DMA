//-----------------------------------------------------------------------------
//
// (c) Copyright 2012-2012 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
//
// Project    : The Xilinx PCI Express DMA
// File       : xilinx_dma_pcie_ep.sv
// Version    : $IpVersion
//-----------------------------------------------------------------------------
`timescale 1ps / 1ps

module xilinx_dma_pcie_ep #
  (
   parameter PL_LINK_CAP_MAX_LINK_WIDTH          = 8,            // 1- X1; 2 - X2; 4 - X4; 8 - X8
   parameter PL_SIM_FAST_LINK_TRAINING           = "FALSE",      // Simulation Speedup
   parameter PL_LINK_CAP_MAX_LINK_SPEED          = 4,             // 1- GEN1; 2 - GEN2; 4 - GEN3
   parameter C_DATA_WIDTH                        = 256 ,
   parameter EXT_PIPE_SIM                        = "FALSE",  // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
   parameter C_ROOT_PORT                         = "FALSE",      // PCIe block is in root port mode
   parameter C_DEVICE_NUMBER                     = 0             // Device number for Root Port configurations only
   )
   (
    output [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txp,
    output [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txn,
    input [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxp,
    input [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxn,




    input 					 sys_clk_p,
    input 					 sys_clk_n,
    input 					 sys_rst_n,

    // AXI Lite
    //-- AXI Master Write Address Channel
    output wire [31:0] m_axil_awaddr,
    output wire [2:0]  m_axil_awprot,
    output wire m_axil_awvalid,
    input  wire m_axil_awready,

    //-- AXI Master Write Data Channel
    output wire [31:0] m_axil_wdata,
    output wire [3:0]  m_axil_wstrb,
    output wire m_axil_wvalid,
    input wire m_axil_wready,
    //-- AXI Master Write Response Channel
    input wire m_axil_bvalid,
    output wire m_axil_bready,
    //-- AXI Master Read Address Channel
    output wire [31:0] m_axil_araddr,
    output wire [2:0]  m_axil_arprot,
    output wire m_axil_arvalid,
    input  wire m_axil_arready,
    //-- AXI Master Read Data Channel
    input wire [31:0] m_axil_rdata,
    input wire [1:0]  m_axil_rresp,
    input wire m_axil_rvalid,
    output wire m_axil_rready,
    input wire [1:0]  m_axil_bresp,

    // AXI Stream
    output                                        axi_clk,
    output                                        axi_rstn,
    output                                        pcie_lnk_up,
    input [(C_DATA_WIDTH -1) : 0]                 m_axis_c2h_tdata_0,
    output [(C_DATA_WIDTH -1) : 0]                m_axis_h2c_tdata_0,
    input                                         m_axis_c2h_tlast_0,
    output                                        m_axis_h2c_tlast_0,
    input                                         m_axis_c2h_tvalid_0,
    output                                        m_axis_h2c_tvalid_0,
    output                                        m_axis_c2h_tready_0,
    input                                         m_axis_h2c_tready_0,
    input [(C_DATA_WIDTH/8 -1) : 0]               m_axis_c2h_tkeep_0,
    output [(C_DATA_WIDTH/8 -1) : 0]              m_axis_h2c_tkeep_0

 );

   //-----------------------------------------------------------------------------------------------------------------------


   // Local Parameters derived from user selection
   localparam integer 				   USER_CLK_FREQ         = ((PL_LINK_CAP_MAX_LINK_SPEED == 3'h4) ? 5 : 4);
   localparam TCQ = 1;
   localparam C_S_AXI_ID_WIDTH = 4;
   localparam C_M_AXI_ID_WIDTH = 4;
   localparam C_S_AXI_DATA_WIDTH = C_DATA_WIDTH;
   localparam C_M_AXI_DATA_WIDTH = C_DATA_WIDTH;
   localparam C_S_AXI_ADDR_WIDTH = 64;
   localparam C_M_AXI_ADDR_WIDTH = 64;
   localparam C_NUM_USR_IRQ	 = 1;

   wire 					   user_lnk_up;

   //----------------------------------------------------------------------------------------------------------------//
   //  AXI Interface                                                                                                 //
   //----------------------------------------------------------------------------------------------------------------//

   wire 					   user_clk;
   wire 					   user_resetn;

  // Wires for Avery HOT/WARM and COLD RESET
   wire 					   avy_sys_rst_n_c;
   wire 					   avy_cfg_hot_reset_out;
   reg 						   avy_sys_rst_n_g;
   reg 						   avy_cfg_hot_reset_out_g;
   assign avy_sys_rst_n_c = avy_sys_rst_n_g;
   assign avy_cfg_hot_reset_out = avy_cfg_hot_reset_out_g;
   initial begin
      avy_sys_rst_n_g = 1;
      avy_cfg_hot_reset_out_g =0;
   end


  //----------------------------------------------------------------------------------------------------------------//
  //    System(SYS) Interface                                                                                       //
  //----------------------------------------------------------------------------------------------------------------//

    wire                                    sys_clk;
    wire                                    sys_clk_gt;
    wire                                    sys_rst_n_c;

  // User Clock LED Heartbeat
     reg [25:0] 			     user_clk_heartbeat;
     reg [((2*C_NUM_USR_IRQ)-1):0]		usr_irq_function_number=0;
     reg [C_NUM_USR_IRQ-1:0] 		     usr_irq_req = 0;
     wire [C_NUM_USR_IRQ-1:0] 		     usr_irq_ack;

      //-- AXI Master Write Address Channel
     wire [C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
     wire [C_M_AXI_ID_WIDTH-1:0] m_axi_awid;
     wire [2:0] 		 m_axi_awprot;
     wire [1:0] 		 m_axi_awburst;
     wire [2:0] 		 m_axi_awsize;
     wire [3:0] 		 m_axi_awcache;
     wire [7:0] 		 m_axi_awlen;
     wire 			 m_axi_awlock;
     wire 			 m_axi_awvalid;
     wire 			 m_axi_awready;

     //-- AXI Master Write Data Channel
     wire [C_M_AXI_DATA_WIDTH-1:0]     m_axi_wdata;
     wire [(C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb;
     wire 			       m_axi_wlast;
     wire 			       m_axi_wvalid;
     wire 			       m_axi_wready;
     //-- AXI Master Write Response Channel
     wire 			       m_axi_bvalid;
     wire 			       m_axi_bready;
     wire [C_M_AXI_ID_WIDTH-1 : 0]     m_axi_bid ;
     wire [1:0]                        m_axi_bresp ;

     //-- AXI Master Read Address Channel
     wire [C_M_AXI_ID_WIDTH-1 : 0]     m_axi_arid;
     wire [C_M_AXI_ADDR_WIDTH-1:0]     m_axi_araddr;
     wire [7:0]                        m_axi_arlen;
     wire [2:0]                        m_axi_arsize;
     wire [1:0]                        m_axi_arburst;
     wire [2:0] 		       m_axi_arprot;
     wire 			       m_axi_arvalid;
     wire 			       m_axi_arready;
     wire 			       m_axi_arlock;
     wire [3:0] 		       m_axi_arcache;

     //-- AXI Master Read Data Channel
     wire [C_M_AXI_ID_WIDTH-1 : 0]   m_axi_rid;
     wire [C_M_AXI_DATA_WIDTH-1:0]   m_axi_rdata;
     wire [1:0] 		     m_axi_rresp;
     wire 			     m_axi_rvalid;
     wire 			     m_axi_rready;

    wire [2:0]    msi_vector_width;
    wire          msi_enable;

  wire [5:0]                          cfg_ltssm_state;

  // Ref clock buffer
  IBUFDS_GTE3 # (.REFCLK_HROW_CK_SEL(2'b00)) refclk_ibuf (.O(sys_clk_gt), .ODIV2(sys_clk), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));
  // Reset buffer
  IBUF   sys_reset_n_ibuf (.O(sys_rst_n_c), .I(sys_rst_n));



  // Core Top Level Wrapper
  xdma_0 xdma_0_i
     (
      //---------------------------------------------------------------------------------------//
      //  PCI Express (pci_exp) Interface                                                      //
      //---------------------------------------------------------------------------------------//
      .sys_rst_n       ( sys_rst_n_c ),
      .sys_clk          ( sys_clk ),
      .sys_clk_gt      ( sys_clk_gt),

      // Tx
      .pci_exp_txn     ( pci_exp_txn ),
      .pci_exp_txp     ( pci_exp_txp ),

      // Rx
      .pci_exp_rxn     ( pci_exp_rxn ),
      .pci_exp_rxp     ( pci_exp_rxp ),



      // AXI streaming ports
      .s_axis_c2h_tdata_0   (m_axis_c2h_tdata_0),
      .s_axis_c2h_tlast_0   (m_axis_c2h_tlast_0),
      .s_axis_c2h_tvalid_0  (m_axis_c2h_tvalid_0),
      .s_axis_c2h_tready_0  (m_axis_c2h_tready_0),
      .s_axis_c2h_tkeep_0   (m_axis_c2h_tkeep_0),
      .m_axis_h2c_tdata_0   (m_axis_h2c_tdata_0),
      .m_axis_h2c_tlast_0   (m_axis_h2c_tlast_0),
      .m_axis_h2c_tvalid_0  (m_axis_h2c_tvalid_0),
      .m_axis_h2c_tready_0  (m_axis_h2c_tready_0),
      .m_axis_h2c_tkeep_0   (m_axis_h2c_tkeep_0),
      // LITE interface
      //-- AXI Master Write Address Channel
      .m_axil_awaddr    (m_axil_awaddr),
      .m_axil_awprot    (m_axil_awprot),
      .m_axil_awvalid   (m_axil_awvalid),
      .m_axil_awready   (m_axil_awready),
      //-- AXI Master Write Data Channel
      .m_axil_wdata     (m_axil_wdata),
      .m_axil_wstrb     (m_axil_wstrb),
      .m_axil_wvalid    (m_axil_wvalid),
      .m_axil_wready    (m_axil_wready),
      //-- AXI Master Write Response Channel
      .m_axil_bvalid    (m_axil_bvalid),
      .m_axil_bresp     (m_axil_bresp),
      .m_axil_bready    (m_axil_bready),
      //-- AXI Master Read Address Channel
      .m_axil_araddr    (m_axil_araddr),
      .m_axil_arprot    (m_axil_arprot),
      .m_axil_arvalid   (m_axil_arvalid),
      .m_axil_arready   (m_axil_arready),
      .m_axil_rdata     (m_axil_rdata),
      //-- AXI Master Read Data Channel
      .m_axil_rresp     (m_axil_rresp),
      .m_axil_rvalid    (m_axil_rvalid),
      .m_axil_rready    (m_axil_rready),




      .usr_irq_req       (usr_irq_req),
      .usr_irq_ack       (usr_irq_ack),
      .msi_enable        (msi_enable),
      .msi_vector_width  (msi_vector_width),


     //--------------------------------------------------------------------------------------//
     //  MCAP Design Switch signal                                                           //
     //   - This signal goes high once the tandem stage2 bitstream is loaded.                //
     //   - This signal may be asserted high by SW after the first PR or Tandem programming  //
     //     sequence has completed.                                                          //
     //   - After going high, this signal should not be written back to zero by SW.          //
     //--------------------------------------------------------------------------------------//
      .mcap_design_switch                        ( ),

     //--------------------------------------------------------------------------------------//
     //  Configuration Arbitration Signals                                                   //
     //    - These signals should be used to arbitrate for control of the underlying FPGA    //
     //      Configuration logic. Request, Grant, and Release signals should be connected in //
     //      the user design.                                                                //
     //    - cap_gnt must be tied to 1'b1 if the arbitration interface is not needed.        //
     //--------------------------------------------------------------------------------------//
      .cap_req                                   ( ),
      .cap_gnt                                   (1'b1),
      .cap_rel                                   (1'b0),

     //--------------------------------------------------------------------------------------//
     //  Startup Signals                                                                     //
     //    - The startup interface is exposed to the external user for connectifity to other //
     //      IPs                                                                             //
     //--------------------------------------------------------------------------------------//
      .startup_cfgclk                            ( ),
      .startup_cfgmclk                           ( ),
      .startup_di                                ( ),
      .startup_eos                               ( ),
      .startup_preq                              ( ),
      .startup_do                                (4'b0000),
      .startup_dts                               (4'b0000),
      .startup_fcsbo                             (1'b0),
      .startup_fcsbts                            (1'b0),
      .startup_gsr                               (1'b0),
      .startup_gts                               (1'b0),
      .startup_keyclearb                         (1'b1),
      .startup_pack                              (1'b0),
      .startup_usrcclko                          (1'b0),
      .startup_usrcclkts                         (1'b1),
      .startup_usrdoneo                          (1'b0),
      .startup_usrdonets                         (1'b1),

     // Config managemnet interface
      .cfg_mgmt_addr  ( 19'b0 ),
      .cfg_mgmt_write ( 1'b0 ),
      .cfg_mgmt_write_data ( 32'b0 ),
      .cfg_mgmt_byte_enable ( 4'b0 ),
      .cfg_mgmt_read  ( 1'b0 ),
      .cfg_mgmt_read_data (),
      .cfg_mgmt_read_write_done (),
      .cfg_mgmt_type1_cfg_reg_access ( 1'b0 ),

    //---------- Shared Logic Internal -------------------------
      .int_qpll1lock_out          (  ),
      .int_qpll1outrefclk_out     (  ),
      .int_qpll1outclk_out        (  ),



      //-- AXI Global
      .axi_aclk        ( user_clk ),
      .axi_aresetn     ( user_resetn ),
      .user_lnk_up     ( user_lnk_up )
    );

assign axi_clk = user_clk;
assign axi_rstn = user_resetn;
assign pcie_lnk_up = user_lnk_up;

endmodule
