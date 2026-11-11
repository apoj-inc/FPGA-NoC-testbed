#**************************************************************
# Create Clock
#**************************************************************
create_clock -period 10 -name PCIE_REFCLK_p [get_ports {PCIE_REFCLK_p}]

#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks


#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty


#**************************************************************
# Set False Path
#**************************************************************
set_false_path -from [get_ports {PCIE_PERST_n}]

set_false_path -from {u_avmm_dma_toplevel|clock_125_rstn_rr}
set_false_path -from [get_cells {u_avmm_dma_toplevel|u_avmm_dma_assembly|u_avmm_dma_csr|dma_resetn_o}]
set_false_path -from [get_clocks {*arriav_hd_altpe2_hip_top|coreclkout}] \
                -to [get_clocks {u_avmm_dma_toplevel|u_my_pcie|pll_0|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path -from [get_clocks {u_avmm_dma_toplevel|u_my_pcie|pll_0|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
                -to [get_clocks {*arriav_hd_altpe2_hip_top|coreclkout}]