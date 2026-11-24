// Formal harness of t_fml_ocp_irq_rst, property a_ocp_filter (REQ-FUNC-034, REQ-IF-010). AI-generated candidate (R-117).
// Expected behavior from the specification only: with oc_en = 1 the power enable drops within 2 CLK-BUS cycles after the
// over-current input has been low for FILT consecutive cycles (the input passes a 2-flop synchronizer first, CDC-006),
// the power-off state is held until software clears the ocur flag and rewrites vbus_drv (0 then 1), and the power enable
// is 1 only when vbus_drv is 1 (section 6.2, o_vbus_pwr_en).
module fml_ocp #(parameter int FILT = 4, parameter int EN = 1) (
  input logic clk, input logic rst_n, input logic ovrcur_n, input logic vbus_drv, input logic ocur_flag
);
  logic pwr_en, oc_evt, oc_act;
  m_usb2_ocp #(.PARA_USB2_OC_FILT(FILT)) dut (.i_clk_bus(clk), .i_rst_n_bus(rst_n), .i_ovrcur_n(ovrcur_n), .i_oc_en(EN != 0),
                                               .i_vbus_drv(vbus_drv), .i_ocur_flag(ocur_flag), .o_pwr_en(pwr_en), .o_oc_evt(oc_evt), .o_oc_act(oc_act));
  logic [7:0] low_cnt;       // consecutive cycles with the input low
  logic       tripped;       // an over-current event happened and software has not re-armed the port
  logic       evt_d, saw_clr, saw_drv0, drv_d, flag_d;
  wire        init;
  // Reset sequence fixed by the harness: reset low for two cycles, then high for the rest of the trace.
  logic [1:0] t;
  initial t = 2'd0;
  always @(posedge clk) begin if (t != 2'd3) t <= t + 2'd1; assume (rst_n == (t >= 2'd2)); end
  assign init = (t == 2'd3);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      low_cnt <= '0; tripped <= 1'b0; evt_d <= 1'b0; saw_clr <= 1'b0; saw_drv0 <= 1'b0; drv_d <= 1'b0; flag_d <= 1'b0;
    end else begin
      low_cnt <= ovrcur_n ? 8'd0 : ((low_cnt == 8'hFF) ? low_cnt : low_cnt + 8'd1);
      evt_d   <= oc_evt;
      drv_d   <= vbus_drv;
      flag_d  <= ocur_flag;
      if (oc_evt) begin tripped <= 1'b1; saw_clr <= 1'b0; saw_drv0 <= 1'b0; end
      else if (tripped) begin
        if (!evt_d && !ocur_flag) saw_clr <= 1'b1;
        if (!vbus_drv) saw_drv0 <= 1'b1;
        if (saw_clr && saw_drv0 && vbus_drv && !ocur_flag) tripped <= 1'b0;
      end
    end
  end
  always @(posedge clk) begin
    if (init && rst_n) begin
      // CSR behavior: the ocur flag is set by the event and stays until software clears it
      if (evt_d) assume (ocur_flag);
      // ... and it is a write-1-to-clear flag that only an event can set (section 11.3, u2_irq_raw.ocur)
      assume (!(ocur_flag && !flag_d && !evt_d));
      if (EN != 0) begin
        a_ocp_trip:  assert (!((low_cnt >= FILT + 4) && pwr_en));     // FILT + 2 synchronizer + 2 reaction cycles
        a_ocp_hold:  assert (!(tripped && pwr_en));
        c_ocp_trip:  cover (oc_evt);
        c_ocp_rearm: cover (!tripped && pwr_en && saw_clr);
      end else begin
        a_ocp_dis:   assert (!oc_evt && !tripped);
      end
      a_ocp_drv:   assert (!(pwr_en && !drv_d && !vbus_drv));         // no power while vbus_drv has been 0 for two cycles
    end
  end
endmodule
