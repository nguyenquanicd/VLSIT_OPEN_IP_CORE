# Generates the section 6.2 port table rows for the USB 2.0 controller specification.
# Columns: Port | Direction | Width | Meaning | Clock domain | Signal type | Reset/idle | Timing | Configurations
rows = []

def add(port, d, w, meaning, clk, typ, rst, timing, cfg):
    rows.append((port, d, w, meaning, clk, typ, rst, timing, cfg))

CP, CB = "CLK-PHY", "CLK-BUS"
ALL = "All wrappers"
UT = "UTMI+ wrappers"
UL = "ULPI wrappers"
AM = "AXI-master wrappers"
AS = "AXI-slave wrappers"

# clocks and resets
add("i_clk_phy", "Input", "1", "Interface clock from the PHY; clocks the protocol engines, the FIFO RAM and the PHY interface", "clock source", "clock", "running after PHY reset", "rising edge", ALL)
add("i_clk_bus", "Input", "1", "System bus clock; clocks APB, AXI, DMA and the CSR", "clock source", "clock", "running", "rising edge", ALL)
add("i_rst_n_phy", "Input", "1", "Active-low reset of CLK-PHY domain; asserted asynchronously, released synchronously inside the IP", "asynchronous", "reset", "asserted at power-up", "release synchronized by m_usb2_rst", ALL)
add("i_rst_n_bus", "Input", "1", "Active-low reset of CLK-BUS domain; asserted asynchronously, released synchronously inside the IP", "asynchronous", "reset", "asserted at power-up", "release synchronized by m_usb2_rst", ALL)
add("o_phy_rst_n", "Output", "1", "Active-low reset request to the PHY, driven from a CSR field and from i_rst_n_bus", CB, "level", "0 (asserted)", "changes only on rising i_clk_bus", ALL)

# APB
add("i_apb_paddr", "Input", "16", "APB byte address of the CSR access", CB, "data (valid while i_apb_psel is 1)", "don't care", "sampled in the SETUP and ACCESS phases", ALL)
add("i_apb_pwdata", "Input", "32", "APB write data", CB, "data (valid while i_apb_psel and i_apb_pwrite are 1)", "don't care", "sampled in the ACCESS phase", ALL)
add("i_apb_pwrite", "Input", "1", "APB direction, 1 = write", CB, "level", "0", "sampled in the SETUP phase", ALL)
add("i_apb_penable", "Input", "1", "APB enable, marks the ACCESS phase", CB, "level", "0", "sampled each CLK-BUS edge", ALL)
add("i_apb_psel", "Input", "1", "APB select of this slave", CB, "level", "0", "sampled each CLK-BUS edge", ALL)
add("i_apb_pstrb", "Input", "4", "APB write byte strobes; all four must be 1", CB, "data (valid with i_apb_pwrite)", "don't care", "sampled in the ACCESS phase", ALL)
add("i_apb_pprot", "Input", "3", "APB protection attributes; only bit 1 is used", CB, "data (valid while i_apb_psel is 1)", "don't care", "sampled in the SETUP phase", ALL)
add("o_apb_pready", "Output", "1", "APB ready of this slave", CB, "level", "0", "registered output of the CSR", ALL)
add("o_apb_pslverr", "Output", "1", "APB slave error, see section 11.4", CB, "level", "0", "registered output of the CSR", ALL)
add("o_apb_prdata", "Output", "32", "APB read data", CB, "data (valid when o_apb_pready is 1 for a read)", "0", "registered output of the CSR", ALL)
add("i_protect_en", "Input", "1", "Enables the PPROT[1] non-secure check of the CSR", "static", "static", "constant after reset", "tie-off or integration constant", ALL)
add("i_slverr_en", "Input", "1", "Enables PSLVERR responses of the CSR", "static", "static", "constant after reset", "tie-off or integration constant", ALL)

# port power (host roles)
add("i_ovrcur_n", "Input", "1", "Active-low over-current flag from the external VBUS power switch; filtered for 16 CLK-BUS cycles and synchronized inside the IP", "asynchronous (synchronized to CLK-BUS)", "level", "1 (no over-current)", "sampled by the synchronizer of CDC-006; tie to 1 when no switch flag exists", ALL)
add("o_vbus_pwr_en", "Output", "1", "Enable of the external VBUS power switch; 1 when u2_hport.vbus_drv is 1 and no over-current is latched", CB, "level", "0 (power off)", "changes on rising i_clk_bus; goes low within 2 cycles after the filtered over-current", ALL)

# DFT
add("i_dft_test_en", "Input", "1", "Test mode enable: overrides the resets in `m_usb2_rst` and bypasses the FIFO RAM macro", "static", "static", "0", "constant during test mode", ALL)
add("i_dft_scan_en", "Input", "1", "Scan shift enable, also the test enable of every clock gate", "static", "level", "0", "asserted by the scan controller during shift", ALL)

# interrupt
add("o_int_usb", "Output", "1", "Interrupt request, high while an enabled and unmasked interrupt status bit is set", CB, "level", "0", "registered in CLK-BUS; cleared by software via the CSR", ALL)

# UTMI+
u = UT
add("o_utmi_dataout", "Output", "16", "Transmit data from the link to the PHY (DataOut); bits [15:8] are used only when PARA_USB2_UTMI_W = 16", CP, "data (valid while o_utmi_txvalid is 1)", "0", "launched on rising i_clk_phy", u)
add("i_utmi_datain", "Input", "16", "Receive data from the PHY (DataIn); bits [15:8] are used only when PARA_USB2_UTMI_W = 16", CP, "data (valid while i_utmi_rxvalid is 1)", "don't care", "sampled on rising i_clk_phy", u)
add("o_utmi_txvalid", "Output", "1", "Transmit data valid, low byte (TXValid)", CP, "level", "0", "held until i_utmi_txready accepts each byte", u)
add("o_utmi_txvalidh", "Output", "1", "Transmit data valid, high byte (TXValidH), 16-bit mode only", CP, "level", "0", "held until i_utmi_txready accepts each word", u)
add("i_utmi_txready", "Input", "1", "PHY accepts the transmit data (TXReady); asserted for every transmitted byte including chirp data", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_rxvalid", "Input", "1", "Receive data valid, low byte (RXValid)", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_rxvalidh", "Input", "1", "Receive data valid, high byte (RXValidH), 16-bit mode only", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_rxactive", "Input", "1", "Receive in progress (RXActive), high from SYNC detection until end of packet", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_rxerror", "Input", "1", "Receive error (RXError), for example a bit-stuff error", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_linestate", "Input", "2", "Line state of D+ and D- (LineState), after the PHY filtering of UTMI+ Table 1", CP, "data (always valid)", "don't care", "sampled on rising i_clk_phy", u)
add("o_utmi_opmode", "Output", "2", "Operational mode (OpMode): normal, non-driving, disable bit stuffing and NRZI, or no SYNC and EOP", CP, "data (static between packets)", "00", "stable before o_utmi_txvalid rises", u)
add("o_utmi_xcvrsel", "Output", "2", "Transceiver select (XcvrSelect): high-speed, full-speed, low-speed or preamble mode", CP, "data (static between packets)", "full-speed", "changed only while the bus is idle", u)
add("o_utmi_termsel", "Output", "1", "Termination select (TermSelect): full-speed pull-up or high-speed termination", CP, "level", "full-speed", "changed only while the bus is idle", u)
add("o_utmi_suspend_n", "Output", "1", "Active-low suspend request to the PHY (SuspendM, UTMI+ name)", CP, "level", "1 (active)", "changed by the suspend controller", u)
add("o_utmi_databus16_8", "Output", "1", "Selects 16-bit (1) or 8-bit (0) data interface (DataBus16_8)", CP, "static", "PARA_USB2_UTMI_W = 16", "constant after reset", u)
add("o_utmi_bitstuff_en", "Output", "1", "Transmit bit-stuffing enable for the low byte (TxBitstuffEnable)", CP, "level", "1", "stable during a packet", u)
add("o_utmi_bitstuff_en_h", "Output", "1", "Transmit bit-stuffing enable for the high byte (TxBitstuffEnableH)", CP, "level", "1", "stable during a packet", u)
add("o_utmi_dppulldown", "Output", "1", "Connects the 15 kohm pull-down to D+ (DpPulldown); 1 in host role", CP, "static", "0", "not toggled during normal operation", u)
add("o_utmi_dmpulldown", "Output", "1", "Connects the 15 kohm pull-down to D- (DmPulldown); 1 in host role", CP, "static", "0", "not toggled during normal operation", u)
add("i_utmi_hostdisc", "Input", "1", "Host disconnect indication (HostDisconnect), valid when both pull-downs are enabled", CP, "level", "1", "sampled on rising i_clk_phy", u)
add("o_utmi_drvvbus", "Output", "1", "Drive 5 V on VBUS (DrvVbus), host role", CP, "level", "0", "driven from a CSR field", u)
add("o_utmi_chrgvbus", "Output", "1", "Charge VBUS through a resistor (ChrgVbus), at least 30 ms", CP, "level", "0", "driven from a CSR field", u)
add("o_utmi_dischrgvbus", "Output", "1", "Discharge VBUS through a resistor (DischrgVbus), at least 50 ms", CP, "level", "0", "driven from a CSR field", u)
add("o_utmi_idpullup", "Output", "1", "Enables sampling of the ID pin (IdPullup)", CP, "level", "1", "driven from a CSR field", u)
add("i_utmi_iddig", "Input", "1", "ID pin state: 0 = mini-A plug, 1 = mini-B plug (IdDig); valid within 50 ms of o_utmi_idpullup = 1", CP, "level", "1", "sampled by the role controller", u)
add("i_utmi_avalid", "Input", "1", "A-peripheral session valid (AValid)", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_bvalid", "Input", "1", "B-peripheral session valid (BValid)", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_vbusvalid", "Input", "1", "VBUS above the operating threshold (VbusValid)", CP, "level", "0", "sampled on rising i_clk_phy", u)
add("i_utmi_sessend", "Input", "1", "VBUS below the B-device session end threshold (SessEnd)", CP, "level", "1", "sampled on rising i_clk_phy", u)

# ULPI
l = UL
add("i_ulpi_dir", "Input", "1", "Data bus direction from the PHY: high while the PHY drives i_ulpi_data", CP, "level", "1", "sampled on rising i_clk_phy", l)
add("i_ulpi_nxt", "Input", "1", "PHY next-byte indication for transmit and receive data", CP, "level", "0", "sampled on rising i_clk_phy", l)
add("o_ulpi_stp", "Output", "1", "Link stop of the transmit packet or register write; in ULPI low power mode it is driven by the always-on `m_usb2_ulpilp` and is asserted asynchronously to wake the PHY (REF-007 section 3.9.3)", "CLK-PHY (CLK-BUS in low power mode)", "pulse (1 cycle); level in low power mode", "1 until the first TX CMD", "launched on rising i_clk_phy; asynchronous release in low power mode", l)
add("i_ulpi_data", "Input", "8", "ULPI data bus value driven by the PHY (RX CMD and receive data)", CP, "data (valid while i_ulpi_dir is 1)", "don't care", "sampled on rising i_clk_phy", l)
add("o_ulpi_data", "Output", "8", "ULPI data bus value driven by the link (TX CMD and transmit data)", CP, "data (valid while o_ulpi_data_oe is 1)", "0", "launched on rising i_clk_phy", l)
add("o_ulpi_data_oe", "Output", "1", "Output enable of o_ulpi_data; 0 whenever i_ulpi_dir is 1", CP, "level", "0", "pad wrapper drives io_ulpi_data from it", l)

# AXI master
axi_dw = "PARA_USB2_AXI_DATA_W"
def axi_master():
    m = AM
    add("o_axim_awid", "Output", "PARA_USB2_AXI_ID_W", "Write address ID", CB, "data (valid with o_axim_awvalid)", "0", "stable until o_axim_awready", m)
    add("o_axim_awaddr", "Output", "PARA_USB2_AXI_ADDR_W", "Write burst start address", CB, "data (valid with o_axim_awvalid)", "0", "stable until o_axim_awready", m)
    add("o_axim_awlen", "Output", "8", "Write burst length minus one; at most 15", CB, "data (valid with o_axim_awvalid)", "0", "stable until o_axim_awready", m)
    add("o_axim_awsize", "Output", "3", "Write beat size, equal to the bus width", CB, "data (valid with o_axim_awvalid)", "0", "stable until o_axim_awready", m)
    add("o_axim_awburst", "Output", "2", "Write burst type; INCR only", CB, "data (valid with o_axim_awvalid)", "01", "stable until o_axim_awready", m)
    add("o_axim_awcache", "Output", "4", "Write cache attributes from a CSR field", CB, "data (valid with o_axim_awvalid)", "0", "stable until o_axim_awready", m)
    add("o_axim_awprot", "Output", "3", "Write protection attributes from a CSR field", CB, "data (valid with o_axim_awvalid)", "0", "stable until o_axim_awready", m)
    add("o_axim_awvalid", "Output", "1", "Write address valid", CB, "level", "0", "held until o_axim_awready", m)
    add("i_axim_awready", "Input", "1", "Write address ready from the interconnect", CB, "level", "0", "sampled each CLK-BUS edge", m)
    add("o_axim_wdata", "Output", axi_dw, "Write data", CB, "data (valid with o_axim_wvalid)", "0", "stable until i_axim_wready", m)
    add("o_axim_wstrb", "Output", "PARA_USB2_AXI_DATA_W/8", "Write byte strobes", CB, "data (valid with o_axim_wvalid)", "0", "stable until i_axim_wready", m)
    add("o_axim_wlast", "Output", "1", "Last beat of the write burst", CB, "level (valid with o_axim_wvalid)", "0", "stable until i_axim_wready", m)
    add("o_axim_wvalid", "Output", "1", "Write data valid", CB, "level", "0", "held until i_axim_wready", m)
    add("i_axim_wready", "Input", "1", "Write data ready from the interconnect", CB, "level", "0", "sampled each CLK-BUS edge", m)
    add("i_axim_bid", "Input", "PARA_USB2_AXI_ID_W", "Write response ID", CB, "data (valid with i_axim_bvalid)", "don't care", "sampled when both bvalid and bready are 1", m)
    add("i_axim_bresp", "Input", "2", "Write response code; 10 and 11 are errors", CB, "data (valid with i_axim_bvalid)", "don't care", "sampled when both bvalid and bready are 1", m)
    add("i_axim_bvalid", "Input", "1", "Write response valid", CB, "level", "0", "sampled each CLK-BUS edge", m)
    add("o_axim_bready", "Output", "1", "Write response ready", CB, "level", "0", "high while a write response is expected", m)
    add("o_axim_arid", "Output", "PARA_USB2_AXI_ID_W", "Read address ID", CB, "data (valid with o_axim_arvalid)", "0", "stable until i_axim_arready", m)
    add("o_axim_araddr", "Output", "PARA_USB2_AXI_ADDR_W", "Read burst start address", CB, "data (valid with o_axim_arvalid)", "0", "stable until i_axim_arready", m)
    add("o_axim_arlen", "Output", "8", "Read burst length minus one; at most 15", CB, "data (valid with o_axim_arvalid)", "0", "stable until i_axim_arready", m)
    add("o_axim_arsize", "Output", "3", "Read beat size, equal to the bus width", CB, "data (valid with o_axim_arvalid)", "0", "stable until i_axim_arready", m)
    add("o_axim_arburst", "Output", "2", "Read burst type; INCR only", CB, "data (valid with o_axim_arvalid)", "01", "stable until i_axim_arready", m)
    add("o_axim_arcache", "Output", "4", "Read cache attributes from a CSR field", CB, "data (valid with o_axim_arvalid)", "0", "stable until i_axim_arready", m)
    add("o_axim_arprot", "Output", "3", "Read protection attributes from a CSR field", CB, "data (valid with o_axim_arvalid)", "0", "stable until i_axim_arready", m)
    add("o_axim_arvalid", "Output", "1", "Read address valid", CB, "level", "0", "held until i_axim_arready", m)
    add("i_axim_arready", "Input", "1", "Read address ready from the interconnect", CB, "level", "0", "sampled each CLK-BUS edge", m)
    add("i_axim_rid", "Input", "PARA_USB2_AXI_ID_W", "Read data ID", CB, "data (valid with i_axim_rvalid)", "don't care", "sampled when both rvalid and rready are 1", m)
    add("i_axim_rdata", "Input", axi_dw, "Read data", CB, "data (valid with i_axim_rvalid)", "don't care", "sampled when both rvalid and rready are 1", m)
    add("i_axim_rresp", "Input", "2", "Read response code; 10 and 11 are errors", CB, "data (valid with i_axim_rvalid)", "don't care", "sampled when both rvalid and rready are 1", m)
    add("i_axim_rlast", "Input", "1", "Last beat of the read burst", CB, "level (valid with i_axim_rvalid)", "don't care", "sampled when both rvalid and rready are 1", m)
    add("i_axim_rvalid", "Input", "1", "Read data valid", CB, "level", "0", "sampled each CLK-BUS edge", m)
    add("o_axim_rready", "Output", "1", "Read data ready", CB, "level", "0", "high while a read burst is outstanding and space exists", m)

def axi_slave():
    s = AS
    add("i_axis_awid", "Input", "PARA_USB2_AXI_ID_W", "Write address ID", CB, "data (valid with i_axis_awvalid)", "don't care", "sampled when awvalid and awready are 1", s)
    add("i_axis_awaddr", "Input", "PARA_USB2_AXI_ADDR_W", "Write address into the FIFO access window", CB, "data (valid with i_axis_awvalid)", "don't care", "sampled when awvalid and awready are 1", s)
    add("i_axis_awlen", "Input", "8", "Write burst length minus one; at most 15", CB, "data (valid with i_axis_awvalid)", "don't care", "sampled when awvalid and awready are 1", s)
    add("i_axis_awsize", "Input", "3", "Write beat size", CB, "data (valid with i_axis_awvalid)", "don't care", "sampled when awvalid and awready are 1", s)
    add("i_axis_awburst", "Input", "2", "Write burst type; FIXED and INCR accepted", CB, "data (valid with i_axis_awvalid)", "don't care", "sampled when awvalid and awready are 1", s)
    add("i_axis_awvalid", "Input", "1", "Write address valid", CB, "level", "0", "sampled each CLK-BUS edge", s)
    add("o_axis_awready", "Output", "1", "Write address ready", CB, "level", "0", "registered", s)
    add("i_axis_wdata", "Input", axi_dw, "Write data into a FIFO", CB, "data (valid with i_axis_wvalid)", "don't care", "sampled when wvalid and wready are 1", s)
    add("i_axis_wstrb", "Input", "PARA_USB2_AXI_DATA_W/8", "Write byte strobes", CB, "data (valid with i_axis_wvalid)", "don't care", "sampled when wvalid and wready are 1", s)
    add("i_axis_wlast", "Input", "1", "Last beat of the write burst", CB, "level (valid with i_axis_wvalid)", "don't care", "sampled when wvalid and wready are 1", s)
    add("i_axis_wvalid", "Input", "1", "Write data valid", CB, "level", "0", "sampled each CLK-BUS edge", s)
    add("o_axis_wready", "Output", "1", "Write data ready; low while the target FIFO is full", CB, "level", "0", "registered", s)
    add("o_axis_bid", "Output", "PARA_USB2_AXI_ID_W", "Write response ID", CB, "data (valid with o_axis_bvalid)", "0", "held until i_axis_bready", s)
    add("o_axis_bresp", "Output", "2", "Write response code", CB, "data (valid with o_axis_bvalid)", "0", "held until i_axis_bready", s)
    add("o_axis_bvalid", "Output", "1", "Write response valid", CB, "level", "0", "held until i_axis_bready", s)
    add("i_axis_bready", "Input", "1", "Write response ready", CB, "level", "0", "sampled each CLK-BUS edge", s)
    add("i_axis_arid", "Input", "PARA_USB2_AXI_ID_W", "Read address ID", CB, "data (valid with i_axis_arvalid)", "don't care", "sampled when arvalid and arready are 1", s)
    add("i_axis_araddr", "Input", "PARA_USB2_AXI_ADDR_W", "Read address into the FIFO access window", CB, "data (valid with i_axis_arvalid)", "don't care", "sampled when arvalid and arready are 1", s)
    add("i_axis_arlen", "Input", "8", "Read burst length minus one; at most 15", CB, "data (valid with i_axis_arvalid)", "don't care", "sampled when arvalid and arready are 1", s)
    add("i_axis_arsize", "Input", "3", "Read beat size", CB, "data (valid with i_axis_arvalid)", "don't care", "sampled when arvalid and arready are 1", s)
    add("i_axis_arburst", "Input", "2", "Read burst type; FIXED and INCR accepted", CB, "data (valid with i_axis_arvalid)", "don't care", "sampled when arvalid and arready are 1", s)
    add("i_axis_arvalid", "Input", "1", "Read address valid", CB, "level", "0", "sampled each CLK-BUS edge", s)
    add("o_axis_arready", "Output", "1", "Read address ready", CB, "level", "0", "registered", s)
    add("o_axis_rid", "Output", "PARA_USB2_AXI_ID_W", "Read data ID", CB, "data (valid with o_axis_rvalid)", "0", "held until i_axis_rready", s)
    add("o_axis_rdata", "Output", axi_dw, "Read data from a FIFO", CB, "data (valid with o_axis_rvalid)", "0", "held until i_axis_rready", s)
    add("o_axis_rresp", "Output", "2", "Read response code", CB, "data (valid with o_axis_rvalid)", "0", "held until i_axis_rready", s)
    add("o_axis_rlast", "Output", "1", "Last beat of the read burst", CB, "level (valid with o_axis_rvalid)", "0", "held until i_axis_rready", s)
    add("o_axis_rvalid", "Output", "1", "Read data valid", CB, "level", "0", "held until i_axis_rready", s)
    add("i_axis_rready", "Input", "1", "Read data ready", CB, "level", "0", "sampled each CLK-BUS edge", s)
    add("o_dma_req", "Output", "PARA_USB2_NUM_DMA_CH", "DMA request per channel, high while the mapped FIFO holds enough data to read or enough space to write", CB, "level", "0", "rises and falls only on rising i_clk_bus; stays high until the DMA controller finishes the burst", s)
    add("i_dma_ack", "Input", "PARA_USB2_NUM_DMA_CH", "DMA burst-complete acknowledge per channel from the external DMA controller", CB, "pulse (1 cycle)", "0", "sampled each CLK-BUS edge; one pulse per completed burst", s)

axi_master()
axi_slave()

def table():
    out = ["| Port | Direction | Width | Meaning (function) | Clock domain | Signal type | Reset / idle value | Timing / sampling | Configurations |",
           "|---|---|---:|---|---|---|---|---|---|"]
    for r in rows:
        out.append("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % r)
    return "\n".join(out)

if __name__ == "__main__":
    print(table())
