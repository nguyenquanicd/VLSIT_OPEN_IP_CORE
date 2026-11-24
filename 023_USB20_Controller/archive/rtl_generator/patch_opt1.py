import re
p = '../rtl/m_usb2_spd.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:70])
    s = s.replace(a, b)


rep("  localparam logic [31:0] LPARA_SH        = $clog2(PARA_USB2_TSCALE),",
    "  // Parameter Description: 1 registers the PHY mode outputs (transceiver select, termination, operation\n"
    "  // mode, suspend, pull-downs); the outputs change one cycle later (timing option, DEC-025).\n"
    "  // Parameter values: 0 or 1; default is 0.\n"
    "  // Parameter unit: none\n"
    "  parameter logic [31:0] PARA_USB2_PIPE_MODE = 0,\n"
    "  // Parameter Description: OpMode that the host drives for the SE0 of a port reset (TBD-015: confirm with\n"
    "  // the PHY datasheet).\n"
    "  // Parameter values: 0 to 3; default is 3.\n"
    "  // Parameter unit: none\n"
    "  parameter logic [31:0] PARA_USB2_RST_OPMODE = 3,\n"
    "  localparam logic [31:0] LPARA_SH        = $clog2(PARA_USB2_TSCALE),")
# restructure the mode block
a = s.index("  // Mode controls: device and host settings by state, the PHY power controls from the CSR.")
b = s.index("  // Outputs.\n  assign o_drv_vbus")
blk = s[a:b]
for n in ('xcvr_sel', 'term_sel', 'op_mode', 'suspend_n', 'dp_pd', 'dm_pd', 'id_pullup'):
    blk = re.sub(r'\bo_' + n + r'\b', 'w_' + n, blk)
blk = blk.replace("          o_op_mode  = 2'b11;", "")  # placeholder never matches
blk = blk.replace("          w_op_mode  = 2'b11;", "          w_op_mode  = PARA_USB2_RST_OPMODE[1:0];")
assert "PARA_USB2_RST_OPMODE[1:0]" in blk
blk += """  // Optional register stage on the mode outputs (PARA_USB2_PIPE_MODE).
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_mode
    if (!i_rst_n_core) begin
      reg_xcvr_sel  <= 2'b01;
      reg_term_sel  <= 1'b0;
      reg_op_mode   <= 2'b00;
      reg_suspend_n <= 1'b1;
      reg_dp_pd     <= 1'b0;
      reg_dm_pd     <= 1'b0;
      reg_id_pullup <= 1'b0;
    end else begin
      reg_xcvr_sel  <= w_xcvr_sel;
      reg_term_sel  <= w_term_sel;
      reg_op_mode   <= w_op_mode;
      reg_suspend_n <= w_suspend_n;
      reg_dp_pd     <= w_dp_pd;
      reg_dm_pd     <= w_dm_pd;
      reg_id_pullup <= w_id_pullup;
    end
  end

  assign o_xcvr_sel  = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_xcvr_sel : w_xcvr_sel;
  assign o_term_sel  = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_term_sel : w_term_sel;
  assign o_op_mode   = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_op_mode : w_op_mode;
  assign o_suspend_n = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_suspend_n : w_suspend_n;
  assign o_dp_pd     = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_dp_pd : w_dp_pd;
  assign o_dm_pd     = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_dm_pd : w_dm_pd;
  assign o_id_pullup = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_id_pullup : w_id_pullup;

"""
s = s[:a] + blk + s[b:]
decl = ("  logic [1:0]              w_xcvr_sel;\n  logic                    w_term_sel;\n  logic [1:0]              w_op_mode;\n"
        "  logic                    w_suspend_n;\n  logic                    w_dp_pd;\n  logic                    w_dm_pd;\n"
        "  logic                    w_id_pullup;\n  logic [1:0]              reg_xcvr_sel;\n  logic                    reg_term_sel;\n"
        "  logic [1:0]              reg_op_mode;\n  logic                    reg_suspend_n;\n  logic                    reg_dp_pd;\n"
        "  logic                    reg_dm_pd;\n  logic                    reg_id_pullup;\n")
rep("  // Stream to the PHY for chirp, resume K and the test J and K", decl + "\n  // Stream to the PHY for chirp, resume K and the test J and K")
open(p, 'w').write(s)

# core generator: parameters and instance
g = open('gen_core.py').read()
a = "    ('PARA_USB2_PIPE_XREG', 0,"
assert g.count(a) == 1
g = g.replace(a, "    ('PARA_USB2_PIPE_MODE', 0, 'register stage on the PHY mode outputs of the speed engine', '0 or 1; default is 0', 'none'),\n"
                 "    ('PARA_USB2_RST_OPMODE', 3, 'OpMode driven by the host for the SE0 of a port reset (TBD-015)', '0 to 3; default is 3', 'none'),\n" + a)
open('gen_core.py', 'w').write(g)
c = open('core_body2.py').read()
a = "    e('    .PARA_USB2_UTMI_W  (PARA_USB2_UTMI_W)')\n    e('  ) u_spd (')"
assert c.count(a) == 1
c = c.replace(a, "    e('    .PARA_USB2_UTMI_W  (PARA_USB2_UTMI_W),')\n    e('    .PARA_USB2_PIPE_MODE (PARA_USB2_PIPE_MODE),')\n    e('    .PARA_USB2_RST_OPMODE (PARA_USB2_RST_OPMODE)')\n    e('  ) u_spd (')")
open('core_body2.py', 'w').write(c)
print('ok')
