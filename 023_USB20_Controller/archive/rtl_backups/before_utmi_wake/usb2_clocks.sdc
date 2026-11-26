# usb2_clocks.sdc - clocks and exceptions of the USB 2.0 controller (specification section 17.1)
# Status: object names bound to the RTL on 2026-11-22 (review F-002; checked by sim/scripts/check_sdc_objects.py, which
# requires every pattern to match in all four wrappers). NOT yet run in an STA tool.

# CLK-PHY: 60 MHz (UTMI+ 8-bit and ULPI). Use 33.333 for UTMI+ 16-bit (30 MHz).
create_clock -name CLK_PHY -period 16.667 -waveform {0 8.333} [get_ports i_clk_phy]

# CLK-BUS: 200 MHz goal (REQ-PERF-001 needs 100 MHz or faster; 30 MHz is the minimum).
create_clock -name CLK_BUS -period 5.000 -waveform {0 2.500} [get_ports i_clk_bus]

# EXC-001: the two clocks are asynchronous. The crossings are the structures of section 7.2. A set_clock_groups
# -asynchronous would remove every path between the clocks from timing, including the Gray pointers that EXC-002 must
# bound (most STA tools ignore set_max_delay on paths cut by a clock group), so every crossing path is bounded instead to
# one period of the faster clock with the data path only (no clock skew or latency is credited).
set_max_delay -datapath_only 5.000 -from [get_clocks CLK_PHY] -to [get_clocks CLK_BUS]
set_max_delay -datapath_only 5.000 -from [get_clocks CLK_BUS] -to [get_clocks CLK_PHY]

# EXC-002: Gray pointers of the register command and update FIFOs and of the FIFO bus port (CDC-001, CDC-002, CDC-004).
# One period of the faster clock bounds the skew between the pointer bits.
# Launch registers: reg_wgray and reg_rgray of every m_vlsit_afifo_top (command and update FIFOs of u_xreg, the three FIFOs
# of u_cdc_fifo) and reg_pop_gray_phy of u_xreg; capture: the first stage of their synchronizers. Report the bit skew
# with the tool command for bus skew (e.g. set_bus_skew in PrimeTime) on the same objects.
set_max_delay -datapath_only 5.000 -from [get_cells -hierarchical *u_xreg/*/u_vlsit_afifo_wr/reg_wgray*] -to [get_cells -hierarchical *u_xreg/*/u_vlsit_afifo_rd/u_sync_wr_gray/*]
set_max_delay -datapath_only 5.000 -from [get_cells -hierarchical *u_xreg/*/u_vlsit_afifo_rd/reg_rgray*] -to [get_cells -hierarchical *u_xreg/*/u_vlsit_afifo_wr/u_sync_rd_gray/*]
set_max_delay -datapath_only 5.000 -from [get_cells -hierarchical *u_xreg/reg_pop_gray_phy*] -to [get_cells -hierarchical *u_xreg/u_sync_pop/*]
set_max_delay -datapath_only 5.000 -from [get_cells -hierarchical *u_cdc_fifo/*/u_vlsit_afifo_wr/reg_wgray*] -to [get_cells -hierarchical *u_cdc_fifo/*/u_vlsit_afifo_rd/u_sync_wr_gray/*]
set_max_delay -datapath_only 5.000 -from [get_cells -hierarchical *u_cdc_fifo/*/u_vlsit_afifo_rd/reg_rgray*] -to [get_cells -hierarchical *u_cdc_fifo/*/u_vlsit_afifo_wr/u_sync_rd_gray/*]

# EXC-003: static ports (constant after reset or constant in test mode).
set_false_path -from [get_ports {i_protect_en i_slverr_en i_dft_test_en}]

# EXC-004: asynchronous assertion of the resets; release is synchronized and timed.
set_false_path -from [get_ports {i_rst_n_phy i_rst_n_bus}] -to [get_pins -hierarchical *u_rst*/*]

# EXC-005 and CDC-006: asynchronous over-current flag to the synchronizer of m_usb2_ocp.
set_false_path -from [get_ports i_ovrcur_n] -to [get_cells -hierarchical *u_ocp*sync*]

# CDC-007: ULPI inputs in low power mode go to the two-flop synchronizers of m_usb2_ulpilp.
set_false_path -from [get_ports {i_ulpi_dir i_ulpi_data[3:0]}] -to [get_cells -hierarchical *u_ulpilp*sync*]
