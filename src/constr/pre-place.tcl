# For interplay of VIO with PCIe Tandem config.
# Add the Tcl file in the tcl.pre* field of the Place Design section in the Implementation settings
# set master_cfg_site [get_sites -of_objects [get_slrs -filter {IS_MASTER==true}] -filter {NAME =~ CONFIG_SITE_*}]
# set bscan_cells [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ CONFIGURATION.BSCAN.* } ]
# set_property HD.TANDEM 1 $master_cfg_site
# add_cells_to_pblock [get_pblocks -of_objects [get_sites $master_cfg_site]] $master_cfg_site

set_property HD.TANDEM_IP_PBLOCK Stage1_Main [get_cells dbg_hub/inst/BSCANID.u_xsdbm_id/SWITCH_N_EXT_BSCAN.bscan_inst/SERIES7_BSCAN.bscan_inst]
add_cells_to_pblock [get_pblocks -of_object [get_sites CONFIG_SITE_X0Y0]] [get_cells dbg_hub/inst/BSCANID.u_xsdbm_id/SWITCH_N_EXT_BSCAN.bscan_inst/SERIES7_BSCAN.bscan_inst]