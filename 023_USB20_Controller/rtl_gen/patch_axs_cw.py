"""Narrows the row counters and credits of m_usb2_axs.sv to the FIFO depth (LPARA_CW bits instead of 17)."""
import re
p = '../rtl/m_usb2_axs.sv'
s = open(p).read()


def rep(a, b, n=1):
    global s
    assert s.count(a) == n, (s.count(a), a[:70])
    s = s.replace(a, b)


rep("  // Parameter Description: register slice on the AXI read data channel (timing option).\n",
    "  // Parameter Description: rows of the FIFO RAM in 32-bit rows; sizes the row counters.\n"
    "  // Parameter values: 64 to 32768; default is 1024.\n"
    "  // Parameter unit: row\n"
    "  parameter logic [31:0] PARA_USB2_FIFO_DEPTH = 1024,\n"
    "  // Parameter Description: register slice on the AXI read data channel (timing option).\n")
rep("  localparam logic [31:0] LPARA_NQ        = PARA_USB2_NEP1 + 32'd3,\n",
    "  localparam logic [31:0] LPARA_NQ        = PARA_USB2_NEP1 + 32'd3,\n"
    "  localparam logic [31:0] LPARA_CW        = $clog2(PARA_USB2_FIFO_DEPTH >> ((PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd1 : 32'd0)) + 32'd1,\n")
for name in ('reg_credit', 'w_q_size'):
    rep("  logic [LPARA_NQ-1:0][16:0]                  %s;" % name, "  logic [LPARA_NQ-1:0][LPARA_CW-1:0]          %s;" % name)
for name in ('reg_r_left', 'reg_r_rq_left', 'reg_w_rows', 'w_head_rows'):
    rep("  logic [16:0]                                %s;" % name, "  logic [LPARA_CW-1:0]                        %s;" % name)
rep("  assign w_head_rows = ({5'd0, w_head_len} + LPARA_BYTES[16:0] - 17'd1) >> LPARA_BSH;",
    "  assign w_head_rows = (LPARA_CW)'(({5'd0, w_head_len} + LPARA_BYTES[16:0] - 17'd1) >> LPARA_BSH);")
rep("          reg_r_rq_left <= (i_axis_arlen >= w_head_rows[7:0]) ? w_head_rows : {9'd0, i_axis_arlen} + 17'd1;",
    "          reg_r_rq_left <= ({9'd0, i_axis_arlen} >= 17'(w_head_rows)) ? w_head_rows :\n"
    "                           (LPARA_CW)'({9'd0, i_axis_arlen} + 17'd1);")
rep("                              i_ev_val : 17'd0) -", "                              (LPARA_CW)'(i_ev_val) : '0) -")
rep("? 17'd1 : 17'd0);", "? (LPARA_CW)'(32'd1) : '0);")
s = s.replace("reg_w_rows <= 17'd0;", "reg_w_rows <= '0;")
s = s.replace("reg_w_rows <= reg_w_rows + 17'd1;", "reg_w_rows <= reg_w_rows + (LPARA_CW)'(32'd1);")
s = s.replace("reg_r_left    <= 17'd0;", "reg_r_left    <= '0;")
s = s.replace("reg_r_rq_left <= 17'd0;", "reg_r_rq_left <= '0;")
s = s.replace("reg_r_rq_left <= reg_r_rq_left - 17'd1;", "reg_r_rq_left <= reg_r_rq_left - (LPARA_CW)'(32'd1);")
s = s.replace("reg_r_left <= reg_r_left - 17'd1;", "reg_r_left <= reg_r_left - (LPARA_CW)'(32'd1);")
s = re.sub(r"\((reg_r_left|reg_r_rq_left) (==|!=) 17'd0\)", r"(\1 \2 '0)", s)
s = s.replace("+ 5'd1)] != 17'd0);", "+ 5'd1)] != '0);")
open(p, 'w').write(s)
print([l for l in s.split('\n') if "17'" in l or '[16:0]' in l])
