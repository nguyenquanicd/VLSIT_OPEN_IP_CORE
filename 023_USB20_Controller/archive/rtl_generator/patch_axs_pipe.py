"""Adds PARA_USB2_PIPE_AXS (register slice on the AXI4 slave read data channel) to m_usb2_axs.sv."""
p = '../rtl/m_usb2_axs.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)


rep("  parameter logic [31:0] PARA_USB2_NEP1 = 9,\n",
    "  parameter logic [31:0] PARA_USB2_NEP1 = 9,\n"
    "  // Parameter Description: register slice on the AXI read data channel (timing option).\n"
    "  // Parameter values: 0 or 1; default is 0.\n"
    "  // Parameter unit: none\n"
    "  parameter logic [31:0] PARA_USB2_PIPE_AXS = 0,\n")
rep("  logic [PARA_USB2_NUM_DMA_CH-1:0]            w_req_cond;\n",
    "  logic [PARA_USB2_NUM_DMA_CH-1:0]            w_req_cond;\n"
    "  logic                                       w_rb_vld;\n"
    "  logic                                       w_rb_rdy;\n"
    "  logic                                       w_rb_last;\n"
    "  logic [PARA_USB2_AXI_DATA_W-1:0]            w_rb_data;\n"
    "  logic                                       reg_ro_vld;\n"
    "  logic                                       reg_ro_last;\n"
    "  logic                                       reg_ro_err;\n"
    "  logic [PARA_USB2_AXI_ID_W-1:0]              reg_ro_id;\n"
    "  logic [PARA_USB2_AXI_DATA_W-1:0]            reg_ro_data;\n")
rep("""  assign o_axis_rid     = reg_rid;
  assign o_axis_rdata   = reg_r_err ? '0 : i_rs_data;
  assign o_axis_rresp   = reg_r_err ? 2'b10 : 2'b00;
  assign o_axis_rvalid  = (reg_fsm_rd_current_state == ENUM_ST_R_DATA) & (i_rs_vld | reg_r_err);
  assign o_axis_rlast   = (reg_r_beats == 8'd0);
  assign o_rs_pop       = o_axis_rvalid & i_axis_rready & ~reg_r_err;
""", """  // w_rb_* is the read beat before the optional register slice (PARA_USB2_PIPE_AXS): with the
  // slice the beat is taken when the output register is empty or is read in this cycle.
  assign w_rb_vld       = (reg_fsm_rd_current_state == ENUM_ST_R_DATA) & (i_rs_vld | reg_r_err);
  assign w_rb_last      = (reg_r_beats == 8'd0);
  assign w_rb_data      = reg_r_err ? '0 : i_rs_data;
  assign w_rb_rdy       = (PARA_USB2_PIPE_AXS != 32'd0) ? (~reg_ro_vld | i_axis_rready) : i_axis_rready;
  assign o_axis_rid     = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_id : reg_rid;
  assign o_axis_rdata   = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_data : w_rb_data;
  assign o_axis_rresp   = ((PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_err : reg_r_err) ? 2'b10 : 2'b00;
  assign o_axis_rvalid  = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_vld : w_rb_vld;
  assign o_axis_rlast   = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_last : w_rb_last;
  assign o_rs_pop       = w_rb_vld & w_rb_rdy & ~reg_r_err;

  // Output register of the read data channel; it holds a beat until the manager takes it.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_ro
    if (!i_rst_n_bus) begin
      reg_ro_vld  <= 1'b0;
      reg_ro_last <= 1'b0;
      reg_ro_err  <= 1'b0;
      reg_ro_id   <= '0;
      reg_ro_data <= '0;
    end else if (PARA_USB2_PIPE_AXS != 32'd0) begin
      if (w_rb_rdy) begin
        reg_ro_vld <= w_rb_vld;
        if (w_rb_vld) begin
          reg_ro_last <= w_rb_last;
          reg_ro_err  <= reg_r_err;
          reg_ro_id   <= reg_rid;
          reg_ro_data <= w_rb_data;
        end
      end
    end
  end
""")
rep("        if (o_axis_rvalid & i_axis_rready & o_axis_rlast)\n", "        if (w_rb_vld & w_rb_rdy & w_rb_last)\n")
rep("      if (o_axis_rvalid & i_axis_rready & reg_r_err)\n", "      if (w_rb_vld & w_rb_rdy & reg_r_err)\n")
open(p, 'w').write(s)
print('ok')
