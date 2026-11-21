import re
p = '../rtl/m_usb2_dma.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


# address composition through 64-bit vectors
rep("  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_hi_ext;\n  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_r_base;\n",
    "  logic [63:0]                                w_r_base64;\n  logic [63:0]                                w_t_base64;\n  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_r_base;\n")
rep("  assign w_hi_ext = {{PARA_USB2_AXI_ADDR_W{1'b0}}, i_dma_hi, 32'd0} >> 32;\n", "")
rep("""  assign w_r_base      = {w_hi_ext[PARA_USB2_AXI_ADDR_W-1:32],
                          (i_role_host ? i_hc_dma[w_r_tag_head[3:0]] : i_epo_dma[w_r_tag_head[3:0]])};""",
    """  assign w_r_base64    = {i_dma_hi, (i_role_host ? i_hc_dma[w_r_tag_head[3:0]] : i_epo_dma[w_r_tag_head[3:0]])};
  assign w_r_base      = w_r_base64[PARA_USB2_AXI_ADDR_W-1:0];
  assign w_t_base64    = {i_dma_hi, w_pick_addr};""")
rep("        reg_t_addr <= {w_hi_ext[PARA_USB2_AXI_ADDR_W-1:32], w_pick_addr};", "        reg_t_addr <= w_t_base64[PARA_USB2_AXI_ADDR_W-1:0];")
# burst length outputs from the combinational calculation
rep("  assign o_axim_awlen   = reg_r_nb[7:0] - 8'd1;", "  assign o_axim_awlen   = w_r_nb_calc[7:0] - 8'd1;")
rep("  assign o_axim_arlen   = reg_t_nb[7:0] - 8'd1;", "  assign o_axim_arlen   = w_t_nb_calc[7:0] - 8'd1;")
s = re.sub(r"  logic \[8:0\]\s+reg_t_nb;\n", "", s)
rep("      reg_t_nb   <= 9'd0;\n", "")
rep("      if (reg_fsm_tx_current_state == ENUM_ST_T_AR)\n        reg_t_nb <= w_t_nb_calc;\n", "")
s = re.sub(r"  logic \[16:0\]\s+reg_r_rows;\n", "", s)
rep("      reg_r_rows    <= 17'd0;\n", "")
rep("        reg_r_rows    <= w_r_rows_head;\n", "")
rep("""      if ((reg_fsm_rx_current_state == ENUM_ST_R_AW) & ~i_axim_awready)
        reg_r_nb <= w_r_nb_calc;
""", "")
open(p, 'w').write(s)
print('ok')
