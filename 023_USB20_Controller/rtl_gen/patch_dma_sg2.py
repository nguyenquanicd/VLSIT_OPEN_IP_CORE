p = '../rtl/m_usb2_dma.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:100])
    s = s.replace(a, b)


# descriptor layout of the specification section 9: len[15:0], software bits [23:16] (last, ioc),
# status [31:24]: done, err, short; hardware rewrites len with the bytes not transferred
rep("  logic [31:0]                                reg_d_w0;\n",
    "  logic [31:0]                                reg_d_w0;\n"
    "  logic [7:0]                                 reg_r_dctl;\n  logic [7:0]                                 reg_t_dctl;\n"
    "  logic [15:0]                                reg_r_dorg;\n  logic [15:0]                                reg_t_dorg;\n"
    "  logic [15:0]                                w_wb_notx;\n")
rep("  assign w_d_ovf     = (w_d_w1[18:0] < {7'd0, reg_r_len});",
    "  assign w_d_ovf     = (w_d_w1[15:0] < {4'd0, reg_r_len});")
rep("  assign w_wb_w1     = w_rx_wb ? {1'b1, reg_r_ovf, 11'd0, 7'd0, reg_r_len} : {1'b1, 12'd0, 7'd0, reg_t_len};",
    "  assign w_wb_notx   = w_rx_wb ? (reg_r_ovf ? reg_r_dorg : (reg_r_dorg - {4'd0, reg_r_len})) :\n"
    "                                 (reg_t_dorg - {4'd0, reg_t_len});\n"
    "  assign w_wb_w1     = w_rx_wb ? {5'd0, ((w_wb_notx != 16'd0) & ~reg_r_ovf), reg_r_ovf, 1'b1, reg_r_dctl, w_wb_notx} :\n"
    "                                 {5'd0, (w_wb_notx != 16'd0), 1'b0, 1'b1, reg_t_dctl, w_wb_notx};")
# RX capture
rep("        reg_r_ovf  <= w_d_ovf;\n",
    "        reg_r_ovf  <= w_d_ovf;\n        reg_r_dctl <= w_d_w1[23:16];\n        reg_r_dorg <= w_d_w1[15:0];\n")
rep("      reg_r_ovf     <= 1'b0;\n    end else begin\n",
    "      reg_r_ovf     <= 1'b0;\n      reg_r_dctl    <= 8'd0;\n      reg_r_dorg    <= 16'd0;\n    end else begin\n")
# TX capture
rep("        reg_t_dlen <= (w_d_w1[18:0] > {8'd0, reg_t_mps}) ? reg_t_mps : w_d_w1[10:0];\n",
    "        reg_t_dlen <= (w_d_w1[15:0] > {5'd0, reg_t_mps}) ? reg_t_mps : w_d_w1[10:0];\n"
    "        reg_t_dctl <= w_d_w1[23:16];\n        reg_t_dorg <= w_d_w1[15:0];\n")
rep("        if (w_d_w1[18:0] == 19'd0)\n          reg_t_rem <= 19'd0;\n",
    "        if (w_d_w1[15:0] == 16'd0)\n          reg_t_rem <= 19'd0;\n")
rep("      reg_t_dlen <= 11'd0;\n    end else begin\n",
    "      reg_t_dlen <= 11'd0;\n      reg_t_dctl <= 8'd0;\n      reg_t_dorg <= 16'd0;\n    end else begin\n")
open(p, 'w').write(s)
print('ok')
