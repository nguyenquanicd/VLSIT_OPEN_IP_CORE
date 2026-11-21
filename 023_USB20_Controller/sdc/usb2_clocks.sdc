# usb2_clocks.sdc - clocks and exceptions of the USB 2.0 controller (specification section 17.1)
# Status: pre-RTL contract. Object names inside the IP (u_xreg, u_ocp) are bound when the RTL exists;
# the clock periods and the exception list are the contract of the specification.

# CLK-PHY: 60 MHz (UTMI+ 8-bit and ULPI). Use 33.333 for UTMI+ 16-bit (30 MHz).
create_clock -name CLK_PHY -period 16.667 -waveform {0 8.333} [get_ports i_clk_phy]

# CLK-BUS: 200 MHz goal (REQ-PERF-001 needs 100 MHz or faster; 30 MHz is the minimum).
create_clock -name CLK_BUS -period 5.000 -waveform {0 2.500} [get_ports i_clk_bus]

# EXC-001: the two clocks are asynchronous. The crossings are the structures of section 7.2.
set_clock_groups -asynchronous -group [get_clocks CLK_PHY] -group [get_clocks CLK_BUS]

# EXC-002: Gray pointers of the register command and update FIFOs and of the FIFO bus port (CDC-001, CDC-002, CDC-004).
# One period of the faster clock bounds the skew between the pointer bits.
set_max_delay -datapath_only 5.000 -from [get_cells -hierarchical *u_xreg*gray_ptr*] -to [get_cells -hierarchical *u_xreg*gray_sync*]
set_max_delay -datapath_only 5.000 -from [get_cells -hierarchical *u_cdc_fifo*gray_ptr*] -to [get_cells -hierarchical *u_cdc_fifo*gray_sync*]

# EXC-003: static ports (constant after reset or constant in test mode).
set_false_path -from [get_ports {i_protect_en i_slverr_en i_dft_test_en}]

# EXC-004: asynchronous assertion of the resets; release is synchronized and timed.
set_false_path -from [get_ports {i_rst_n_phy i_rst_n_bus}] -to [get_pins -hierarchical *u_rst*/*]

# EXC-005 and CDC-006: asynchronous over-current flag to the synchronizer of m_usb2_ocp.
set_false_path -from [get_ports i_ovrcur_n] -to [get_cells -hierarchical *u_ocp*sync*]

# CDC-007: ULPI inputs in low power mode go to the two-flop synchronizers of m_usb2_ulpilp.
set_false_path -from [get_ports {i_ulpi_dir i_ulpi_data[3:0]}] -to [get_cells -hierarchical *u_ulpilp*sync*]
