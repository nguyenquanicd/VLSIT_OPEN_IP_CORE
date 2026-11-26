# m_vlsit_dsig_top.sdc - timing constraints of the digital signature IP (specification section 17.1).
# Owner of these lines: the IP (clocks, the relation of the two clocks, the CSR crossing). Owner of the values marked
# INTEGRATOR: the SoC (clock periods, latency and uncertainty, port delays, loads, drivers).
#
# Set DSIG_CSR_ASYNC to the value of PARA_CSR_ASYNC before sourcing this file (default 0: one clock).
# Not checked with a timing tool here (no STA tool in the verification environment); verification/env/misc/check_sdc.py
# checks that every port of m_vlsit_dsig_top is constrained and that the commands refer to existing ports.

if {![info exists DSIG_CSR_ASYNC]} { set DSIG_CSR_ASYNC 0 }
set T_CORE 10.0     ;# INTEGRATOR: CLK-CORE period in ns (100 MHz nominal, section 17.1.1)
set T_APB  20.0     ;# INTEGRATOR: CLK-APB period in ns in the asynchronous build

# ---------------------------------------------------------------------------------------------------------------- clocks
create_clock -name CLK_CORE -period $T_CORE [get_ports i_clk_core]
if {$DSIG_CSR_ASYNC == 1} {
  create_clock -name CLK_APB -period $T_APB [get_ports i_clk_apb]
  set APB_CLK CLK_APB
} else {
  # PARA_CSR_ASYNC 0: i_clk_apb is the same clock as i_clk_core (connected to the same source by the integrator)
  create_generated_clock -name CLK_APB -source [get_ports i_clk_core] -divide_by 1 [get_ports i_clk_apb]
  set APB_CLK CLK_APB
}

# ------------------------------------------------------------------------------------------- crossing of the CSR (async)
# EXC-001 / EXC-002 (section 17.1.3): the CSR handshake crosses with a toggle request and acknowledge through the library
# synchronizer cells, and the bundled address, write data and read data stay stable until the toggle is seen. The paths
# between the two clocks are bounded by one period of the faster clock without the clock skew (-datapath_only) instead of a
# clock group: with set_clock_groups -asynchronous the max_delay of the bundled data would be overridden (a false path wins
# over set_max_delay), so the bound of EXC-002 would be lost.
if {$DSIG_CSR_ASYNC == 1} {
  set T_FAST [expr {min($T_CORE, $T_APB)}]
  set_max_delay -datapath_only $T_FAST -from [get_clocks CLK_APB]  -to [get_clocks CLK_CORE]
  set_max_delay -datapath_only $T_FAST -from [get_clocks CLK_CORE] -to [get_clocks CLK_APB]
}

# ------------------------------------------------------------------------------------------------------ ports (17.1.2)
# ASM-013: the external delay is at most 50 percent of the period of the reference clock.
set IN_CORE  [expr {0.5 * $T_CORE}]
set OUT_CORE [expr {0.5 * $T_CORE}]
set T_APB_EFF [expr {$DSIG_CSR_ASYNC == 1 ? $T_APB : $T_CORE}]
set IN_APB   [expr {0.5 * $T_APB_EFF}]
set OUT_APB  [expr {0.5 * $T_APB_EFF}]

# APB4 (CLK-APB), and the static pins of the generated CSR (protection and error-response enables)
set_input_delay  $IN_APB  -clock $APB_CLK [get_ports {i_apb_psel i_apb_penable i_apb_pwrite i_apb_paddr* i_apb_pwdata* i_apb_pstrb* i_apb_pprot* i_protect_en i_slverr_en}]
set_output_delay $OUT_APB -clock $APB_CLK [get_ports {o_apb_pready o_apb_pslverr o_apb_prdata*}]

# AXI4 subordinate (CLK-CORE)
set_input_delay  $IN_CORE  -clock CLK_CORE [get_ports {i_axi_awvalid i_axi_awid* i_axi_awaddr* i_axi_awlen* i_axi_awsize* i_axi_awburst*}]
set_input_delay  $IN_CORE  -clock CLK_CORE [get_ports {i_axi_wvalid i_axi_wdata* i_axi_wstrb* i_axi_wlast i_axi_bready}]
set_input_delay  $IN_CORE  -clock CLK_CORE [get_ports {i_axi_arvalid i_axi_arid* i_axi_araddr* i_axi_arlen* i_axi_arsize* i_axi_arburst* i_axi_rready}]
set_output_delay $OUT_CORE -clock CLK_CORE [get_ports {o_axi_awready o_axi_wready o_axi_bvalid o_axi_bid* o_axi_bresp*}]
set_output_delay $OUT_CORE -clock CLK_CORE [get_ports {o_axi_arready o_axi_rvalid o_axi_rid* o_axi_rdata* o_axi_rresp* o_axi_rlast}]

# DMA, key and entropy ports (CLK-CORE)
set_input_delay  $IN_CORE  -clock CLK_CORE [get_ports {i_dma_in_ack i_dma_out_ack i_key_valid i_key_data* i_ent_valid i_ent_data*}]
set_output_delay $OUT_CORE -clock CLK_CORE [get_ports {o_dma_in_req o_dma_out_req o_key_req o_key_idx* o_ent_req}]

# Interrupt and alarm (CLK-CORE)
set_output_delay $OUT_CORE -clock CLK_CORE [get_ports {o_irq o_alarm}]

# Resets (section 7.3): asynchronous assertion, release synchronized to the own clock. They are timed against their clock
# (recovery and removal of the asynchronous-reset flip-flops), so no false path is set on them.
set_input_delay $IN_CORE -clock CLK_CORE [get_ports i_rst_n_core]
set_input_delay $IN_APB  -clock $APB_CLK [get_ports i_rst_n_apb]

# INTEGRATOR: set_clock_uncertainty, set_clock_latency, set_clock_transition, set_driving_cell, set_load, max transition,
# capacitance and fanout come from the technology library and the SoC (section 17.1.1 and 17.1.2).
