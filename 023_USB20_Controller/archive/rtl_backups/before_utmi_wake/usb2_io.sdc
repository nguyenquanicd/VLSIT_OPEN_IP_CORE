# usb2_io.sdc - interface timing budgets of the USB 2.0 controller (specification section 17.1.2)
# Status: pre-RTL contract. Values marked ASSUMED are assumptions to be replaced (ASM-027, TBD-007).

# Interface budgets as variables: the integrator replaces them with the numbers of the PHY macro datasheet (TBD-007) and the
# load switch (TBD-012 is a parameter of the RTL, PARA_USB2_OC_FILT).
set utmi_in_max   8.333
set utmi_out_max  8.333
set ulpi_in_setup 6.0
set ulpi_out_max  9.0
set bus_in_max    2.0
set bus_out_max   2.0
set clk_phy_period 16.667

# ---- UTMI+ (CLK_PHY, 16.667 ns at 60 MHz): ASSUMED 50 % of the period each way until the PHY macro datasheet exists.
set utmi_in  [get_ports {i_utmi_datain[*] i_utmi_rxvalid i_utmi_rxvalidh i_utmi_rxactive i_utmi_rxerror i_utmi_linestate[*] i_utmi_txready i_utmi_hostdisc i_utmi_iddig i_utmi_avalid i_utmi_bvalid i_utmi_vbusvalid i_utmi_sessend}]
set utmi_out [get_ports {o_utmi_dataout[*] o_utmi_txvalid o_utmi_txvalidh o_utmi_opmode[*] o_utmi_xcvrsel[*] o_utmi_termsel o_utmi_suspend_n o_utmi_databus16_8 o_utmi_bitstuff_en o_utmi_bitstuff_en_h o_utmi_dppulldown o_utmi_dmpulldown o_utmi_drvvbus o_utmi_chrgvbus o_utmi_dischrgvbus o_utmi_idpullup}]
set_input_delay  -clock CLK_PHY -max $utmi_in_max $utmi_in
set_input_delay  -clock CLK_PHY -min 0.000 $utmi_in
set_output_delay -clock CLK_PHY -max $utmi_out_max $utmi_out
set_output_delay -clock CLK_PHY -min 0.000 $utmi_out

# ---- ULPI (CLK_PHY, PHY output clock mode). Numbers read from REF-007 Table 5 (partly garbled in the converted copy;
# verify with the official copy, ASM-027): input setup 6.0 ns, input hold 0.0 ns, output delay 9.0 ns maximum.
set ulpi_in  [get_ports {i_ulpi_dir i_ulpi_nxt i_ulpi_data[*]}]
set ulpi_out [get_ports {o_ulpi_stp o_ulpi_data[*] o_ulpi_data_oe}]
set_input_delay  -clock CLK_PHY -max [expr $clk_phy_period - $ulpi_in_setup] $ulpi_in
set_input_delay  -clock CLK_PHY -min 0.0 $ulpi_in
set_output_delay -clock CLK_PHY -max [expr $clk_phy_period - $ulpi_out_max] $ulpi_out
set_output_delay -clock CLK_PHY -min 0.0 $ulpi_out

# ---- APB4, interrupt, AXI4 and DMA handshake (CLK_BUS, 5.000 ns): 40 % of the period each way (section 17.1.2).
set bus_in  [get_ports {i_apb_* i_axim_* i_axis_* i_dma_ack}]
set bus_out [get_ports {o_apb_* o_axim_* o_axis_* o_dma_req o_int_usb o_vbus_pwr_en o_phy_rst_n}]
set_input_delay  -clock CLK_BUS -max $bus_in_max $bus_in
set_input_delay  -clock CLK_BUS -min 0.000 $bus_in
set_output_delay -clock CLK_BUS -max $bus_out_max $bus_out
set_output_delay -clock CLK_BUS -min 0.000 $bus_out
