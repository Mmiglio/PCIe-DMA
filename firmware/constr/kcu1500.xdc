create_clock -period 10.000 -name sys_clk [get_ports sysclk_in_p]
set_clock_groups -asynchronous -group [get_clocks sys_clk -include_generated_clocks]

set_false_path -from [get_ports sys_rst_n]

## Physical constraints
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

## #GTH Bank 224 PCIe lanes 7:4
set_property PACKAGE_PIN BF5 [get_ports {pci_exp_txp[7]}] ;# MGTHTXP0
set_property PACKAGE_PIN BC2 [get_ports {pci_exp_rxp[7]}] ;# MGTHRXP0
set_property PACKAGE_PIN BC1 [get_ports {pci_exp_rxn[7]}] ;# MGTHRXN0
set_property PACKAGE_PIN BF4 [get_ports {pci_exp_txn[7]}] ;# MGTHTXN0
set_property PACKAGE_PIN BD5 [get_ports {pci_exp_txp[6]}] ;# MGTHTXP1
set_property PACKAGE_PIN BA2 [get_ports {pci_exp_rxp[6]}] ;# MGTHRXP1
set_property PACKAGE_PIN BA1 [get_ports {pci_exp_rxn[6]}] ;# MGTHRXN1
set_property PACKAGE_PIN BD4 [get_ports {pci_exp_txn[6]}] ;# MGTHTXN1
set_property PACKAGE_PIN BB5 [get_ports {pci_exp_txp[5]}] ;# MGTHTXP2
set_property PACKAGE_PIN AW4 [get_ports {pci_exp_rxp[5]}] ;# MGTHRXP2
set_property PACKAGE_PIN AW3 [get_ports {pci_exp_rxn[5]}] ;# MGTHRXN2
set_property PACKAGE_PIN BB4 [get_ports {pci_exp_txn[5]}] ;# MGTHTXN2
set_property PACKAGE_PIN AV7 [get_ports {pci_exp_txp[4]}] ;# MGTHTXP3
set_property PACKAGE_PIN AV2 [get_ports {pci_exp_rxp[4]}] ;# MGTHRXP3
set_property PACKAGE_PIN AV1 [get_ports {pci_exp_rxn[4]}] ;# MGTHRXN3
set_property PACKAGE_PIN AV6 [get_ports {pci_exp_txn[4]}] ;# MGTHTXN3

#GTH Bank 225 PCIe lanes 3:0
set_property PACKAGE_PIN AU9 [get_ports {pci_exp_txp[3]}] ;# MGTHTXP0
set_property PACKAGE_PIN AU4 [get_ports {pci_exp_rxp[3]}] ;# MGTHRXP0
set_property PACKAGE_PIN AU3 [get_ports {pci_exp_rxn[3]}] ;# MGTHRXN0
set_property PACKAGE_PIN AU8 [get_ports {pci_exp_txn[3]}] ;# MGTHTXN0
set_property PACKAGE_PIN AT7 [get_ports {pci_exp_txp[2]}] ;# MGTHTXP1
set_property PACKAGE_PIN AT2 [get_ports {pci_exp_rxp[2]}] ;# MGTHRXP1
set_property PACKAGE_PIN AT1 [get_ports {pci_exp_rxn[2]}] ;# MGTHRXN1
set_property PACKAGE_PIN AT6 [get_ports {pci_exp_txn[2]}] ;# MGTHTXN1
set_property PACKAGE_PIN AR9 [get_ports {pci_exp_txp[1]}] ;# MGTHTXP2
set_property PACKAGE_PIN AR4 [get_ports {pci_exp_rxp[1]}] ;# MGTHRXP2
set_property PACKAGE_PIN AR3 [get_ports {pci_exp_rxn[1]}] ;# MGTHRXN2
set_property PACKAGE_PIN AR8 [get_ports {pci_exp_txn[1]}] ;# MGTHTXN2
set_property PACKAGE_PIN AP7 [get_ports {pci_exp_txp[0]}] ;# MGTHTXP3
set_property PACKAGE_PIN AP2 [get_ports {pci_exp_rxp[0]}] ;# MGTHRXP3
set_property PACKAGE_PIN AP1 [get_ports {pci_exp_rxn[0]}] ;# MGTHRXN3
set_property PACKAGE_PIN AP6 [get_ports {pci_exp_txn[0]}] ;# MGTHTXN3
set_property PACKAGE_PIN AT11 [get_ports sysclk_in_p] ;# MGTREFCLK0P
set_property PACKAGE_PIN AT10 [get_ports sysclk_in_n] ;# MGTREFCLK0N

#set_property LOC PCIE_3_1_X0Y0 [get_cells dma_engine_i/xdma_0_i/inst/pcie3_ip_i/U0/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst]
set_property PACKAGE_PIN AR26 [get_ports sys_rst_n] ;
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n] ;


set_property PACKAGE_PIN AN24     [get_ports "scl"]
set_property IOSTANDARD  LVCMOS18 [get_ports "scl"]
set_property PACKAGE_PIN AP24     [get_ports "sda"]
set_property IOSTANDARD  LVCMOS18 [get_ports "sda"]
set_property PACKAGE_PIN AL24     [get_ports "I2C_MAIN_RESET_B_LS"]
set_property IOSTANDARD  LVCMOS18 [get_ports "I2C_MAIN_RESET_B_LS"]
