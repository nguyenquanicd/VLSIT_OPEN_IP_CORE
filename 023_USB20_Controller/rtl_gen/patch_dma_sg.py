import re
p = '../rtl/m_usb2_dma.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:100])
    s = s.replace(a, b)


# ---------------------------------------------------------------- header, parameter, port
rep(" *                (DEC-010). Buffer addresses must be aligned to the row size. Scatter-gather\n"
    " *                descriptors are not implemented.\n",
    " *                (DEC-010). Buffer addresses must be aligned to the row size. Scatter-gather\n"
    " *                (build option PARA_USB2_SG_EN, DEC-013): the address field of the CSR points\n"
    " *                to a list of 8-byte descriptors, one per packet {buffer address, length and\n"
    " *                flags}; the engine reads the descriptor, moves the packet, writes the done\n"
    " *                flag and the length back and moves the pointer to the next descriptor.\n")
rep("  parameter logic [31:0] PARA_USB2_NHC = 8,\n",
    "  parameter logic [31:0] PARA_USB2_NHC = 8,\n"
    "  // Parameter Description: 1 builds the scatter-gather descriptor engine (DEC-013).\n"
    "  // Parameter values: 0 or 1; default is 0.\n"
    "  // Parameter unit: none\n"
    "  parameter logic [31:0] PARA_USB2_SG_EN = 0,\n")
rep("  localparam logic [31:0] LPARA_ONE       = 1\n) (",
    "  localparam logic [31:0] LPARA_ONE       = 1,\n"
    "  localparam logic [31:0] LPARA_DESC_OFF  = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd0 : 32'd4,\n"
    "  localparam logic [31:0] LPARA_DESC_ARL  = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd0 : 32'd1\n) (")
rep("  input  wire                               i_fl_tx,\n",
    "  input  wire                               i_fl_tx,\n"
    "  input  wire                               i_sg_mode,\n")

# ---------------------------------------------------------------- state enums
rep("  typedef enum logic [2:0] {\n    ENUM_ST_R_IDLE = 3'd0,\n    ENUM_ST_R_AW   = 3'd1,\n    ENUM_ST_R_W    = 3'd2,\n"
    "    ENUM_ST_R_B    = 3'd3,\n    ENUM_ST_R_UPD  = 3'd4,\n    ENUM_ST_R_POP  = 3'd5\n",
    "  typedef enum logic [3:0] {\n    ENUM_ST_R_IDLE = 4'd0,\n    ENUM_ST_R_AW   = 4'd1,\n    ENUM_ST_R_W    = 4'd2,\n"
    "    ENUM_ST_R_B    = 4'd3,\n    ENUM_ST_R_UPD  = 4'd4,\n    ENUM_ST_R_POP  = 4'd5,\n"
    "    ENUM_ST_R_DAR  = 4'd6,\n    ENUM_ST_R_DRD  = 4'd7,\n    ENUM_ST_R_WBA  = 4'd8,\n"
    "    ENUM_ST_R_WBW  = 4'd9,\n    ENUM_ST_R_WBB  = 4'd10\n")
rep("  typedef enum logic [2:0] {\n    ENUM_ST_T_IDLE = 3'd0,\n    ENUM_ST_T_CRED = 3'd1,\n    ENUM_ST_T_AR   = 3'd2,\n"
    "    ENUM_ST_T_R    = 3'd3,\n    ENUM_ST_T_CM   = 3'd4,\n    ENUM_ST_T_UPD  = 3'd5\n",
    "  typedef enum logic [3:0] {\n    ENUM_ST_T_IDLE = 4'd0,\n    ENUM_ST_T_CRED = 4'd1,\n    ENUM_ST_T_AR   = 4'd2,\n"
    "    ENUM_ST_T_R    = 4'd3,\n    ENUM_ST_T_CM   = 4'd4,\n    ENUM_ST_T_UPD  = 4'd5,\n"
    "    ENUM_ST_T_DAR  = 4'd6,\n    ENUM_ST_T_DRD  = 4'd7,\n    ENUM_ST_T_WBA  = 4'd8,\n"
    "    ENUM_ST_T_WBW  = 4'd9,\n    ENUM_ST_T_WBB  = 4'd10\n")

# ---------------------------------------------------------------- declarations
decl = [
    ("logic", "w_sg"), ("logic [31:0]", "reg_r_dp"), ("logic [31:0]", "reg_t_dp"),
    ("logic [31:0]", "reg_d_w0"), ("logic", "reg_d_beat"), ("logic", "reg_r_ovf"),
    ("logic", "reg_t_dv"), ("logic [10:0]", "reg_t_dlen"), ("logic [10:0]", "w_t_cap"),
    ("logic [63:0]", "w_rdata64"), ("logic [31:0]", "w_d_w0"), ("logic [31:0]", "w_d_w1"),
    ("logic [63:0]", "w_d_addr64"), ("logic", "w_desc_rd"), ("logic", "w_desc_last"),
    ("logic", "w_d_ovf"), ("logic", "w_rx_dph"), ("logic", "w_tx_dph"),
    ("logic", "w_rx_dph_rd"), ("logic", "w_tx_dph_rd"),
    ("logic", "w_rx_wb"), ("logic", "w_tx_wb"), ("logic", "w_rx_ar_busy"),
    ("logic", "w_tx_ar_busy"), ("logic", "w_rx_aw_busy"), ("logic", "w_tx_aw_busy"),
    ("logic", "w_tx_pre_ar"), ("logic", "w_tx_pre_wb"), ("logic", "w_rx_gate"),
    ("logic", "w_wb_a"), ("logic", "w_wb_w"), ("logic", "w_wb_b"), ("logic", "w_dar"),
    ("logic", "w_t_rbeat"), ("logic [31:0]", "w_wb_dp"), ("logic [31:0]", "w_wb_w1"),
    ("logic [31:0]", "w_dar_dp"), ("logic [63:0]", "w_wb_a64"), ("logic [63:0]", "w_wb_d64"),
    ("logic [63:0]", "w_dar64"), ("logic [7:0]", "w_wb_s8"),
]
txt = ""
for t, n in decl:
    txt += "  " + t.ljust(44) + n + ";\n"
rep("  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_r_addr_nxt;\n",
    "  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_r_addr_nxt;\n" + txt)

# ---------------------------------------------------------------- AXI write channels
a = s.index("  // AXI write channels follow the state of the receive drain.\n")
endm = "  assign o_axim_bready  = (reg_fsm_rx_current_state == ENUM_ST_R_B);\n"
b = s.index(endm) + len(endm)
new_w = """  // Scatter-gather mode: the build option and the CSR bit (change the bit only while idle). The two
  // engines share the AXI channels only for the descriptors: the receive drain reads a descriptor
  // on the read channels and writes it back on the write channels, the transmit fill the same. An
  // engine starts a packet only when the other one does not hold the channels; the transmit fill
  // has the priority when both start in the same cycle, and a write-back of the transmit fill
  // waits in its own state until the receive drain has finished its packet.
  assign w_sg         = (PARA_USB2_SG_EN != 32'd0) & i_sg_mode;
  assign w_rx_dph_rd  = (reg_fsm_rx_current_state == ENUM_ST_R_DRD);
  assign w_tx_dph_rd  = (reg_fsm_tx_current_state == ENUM_ST_T_DRD);
  assign w_rx_dph     = (reg_fsm_rx_current_state == ENUM_ST_R_DAR) | w_rx_dph_rd;
  assign w_tx_dph     = (reg_fsm_tx_current_state == ENUM_ST_T_DAR) | w_tx_dph_rd;
  assign w_rx_wb      = (reg_fsm_rx_current_state == ENUM_ST_R_WBA) | (reg_fsm_rx_current_state == ENUM_ST_R_WBW) |
                        (reg_fsm_rx_current_state == ENUM_ST_R_WBB);
  assign w_tx_wb      = (reg_fsm_tx_current_state == ENUM_ST_T_WBA) | (reg_fsm_tx_current_state == ENUM_ST_T_WBW) |
                        (reg_fsm_tx_current_state == ENUM_ST_T_WBB);
  assign w_rx_ar_busy = w_rx_dph;
  assign w_tx_ar_busy = (reg_fsm_tx_current_state == ENUM_ST_T_AR) | (reg_fsm_tx_current_state == ENUM_ST_T_R) |
                        w_tx_dph;
  assign w_rx_aw_busy = w_rx_dph | w_rx_wb | (reg_fsm_rx_current_state == ENUM_ST_R_AW) |
                        (reg_fsm_rx_current_state == ENUM_ST_R_W) | (reg_fsm_rx_current_state == ENUM_ST_R_B);
  assign w_tx_aw_busy = w_tx_wb;
  assign w_tx_pre_ar  = (w_fsm_tx_nxt_state == ENUM_ST_T_AR) | (w_fsm_tx_nxt_state == ENUM_ST_T_DAR);
  assign w_tx_pre_wb  = (w_fsm_tx_nxt_state == ENUM_ST_T_WBA);
  assign w_rx_gate    = ~w_tx_ar_busy & ~w_tx_pre_ar & ~w_tx_aw_busy & ~w_tx_pre_wb;

  // Descriptor read: word 0 is the buffer address, word 1 {done, overflow, ..., length}.
  assign w_rdata64   = 64'(i_axim_rdata);
  assign w_d_w0      = (PARA_USB2_AXI_DATA_W == 32'd64) ? w_rdata64[31:0] : reg_d_w0;
  assign w_d_w1      = (PARA_USB2_AXI_DATA_W == 32'd64) ? w_rdata64[63:32] : w_rdata64[31:0];
  assign w_d_addr64  = {i_dma_hi, w_d_w0};
  assign w_desc_rd   = (w_rx_dph_rd | w_tx_dph_rd) & i_axim_rvalid;
  assign w_desc_last = w_desc_rd & i_axim_rlast;
  assign w_d_ovf     = (w_d_w1[18:0] < {7'd0, reg_r_len});
  assign w_dar       = (reg_fsm_rx_current_state == ENUM_ST_R_DAR) | (reg_fsm_tx_current_state == ENUM_ST_T_DAR);
  assign w_dar_dp    = (reg_fsm_rx_current_state == ENUM_ST_R_DAR) ? reg_r_dp : reg_t_dp;
  assign w_dar64     = {i_dma_hi, w_dar_dp};

  // Descriptor write-back: the done flag and the length, one beat on the lane of word 1.
  assign w_wb_a      = (reg_fsm_rx_current_state == ENUM_ST_R_WBA) |
                       ((reg_fsm_tx_current_state == ENUM_ST_T_WBA) & ~w_rx_aw_busy);
  assign w_wb_w      = (reg_fsm_rx_current_state == ENUM_ST_R_WBW) | (reg_fsm_tx_current_state == ENUM_ST_T_WBW);
  assign w_wb_b      = (reg_fsm_rx_current_state == ENUM_ST_R_WBB) | (reg_fsm_tx_current_state == ENUM_ST_T_WBB);
  assign w_wb_dp     = w_rx_wb ? reg_r_dp : reg_t_dp;
  assign w_wb_a64    = {i_dma_hi, w_wb_dp + LPARA_DESC_OFF};
  assign w_wb_w1     = w_rx_wb ? {1'b1, reg_r_ovf, 11'd0, 7'd0, reg_r_len} : {1'b1, 12'd0, 7'd0, reg_t_len};
  assign w_wb_d64    = (PARA_USB2_AXI_DATA_W == 32'd64) ? {w_wb_w1, 32'd0} : {32'd0, w_wb_w1};
  assign w_wb_s8     = (PARA_USB2_AXI_DATA_W == 32'd64) ? 8'hF0 : 8'h0F;

  // AXI write channels follow the state of the receive drain (and the write-backs).
  assign o_axim_awid    = '0;
  assign o_axim_awaddr  = w_wb_a ? w_wb_a64[PARA_USB2_AXI_ADDR_W-1:0] : reg_r_addr;
  assign o_axim_awlen   = w_wb_a ? 8'd0 : (w_r_nb_calc[7:0] - 8'd1);
  assign o_axim_awsize  = LPARA_BSH[2:0];
  assign o_axim_awburst = 2'b01;
  assign o_axim_awcache = i_dma_cfg[8:5];
  assign o_axim_awprot  = i_dma_cfg[11:9];
  assign o_axim_awvalid = (reg_fsm_rx_current_state == ENUM_ST_R_AW) | w_wb_a;
  assign o_axim_wdata   = w_wb_w ? w_wb_d64[PARA_USB2_AXI_DATA_W-1:0] : i_rs_data;
  assign o_axim_wstrb   = w_wb_w ? w_wb_s8[PARA_USB2_AXI_DATA_W/8-1:0] : w_wstrb;
  assign o_axim_wlast   = w_wb_w | (reg_r_beat == (reg_r_nb - 9'd1));
  assign o_axim_wvalid  = ((reg_fsm_rx_current_state == ENUM_ST_R_W) & i_rs_vld) | w_wb_w;
  assign o_rs_pop       = (reg_fsm_rx_current_state == ENUM_ST_R_W) & i_rs_vld & i_axim_wready;
  assign o_axim_bready  = (reg_fsm_rx_current_state == ENUM_ST_R_B) | w_wb_b;
"""
s = s[:a] + new_w + s[b:]

# ---------------------------------------------------------------- RX next state
rep("""      ENUM_ST_R_IDLE: begin
        if ((reg_evq_cnt != '0) & i_dma_en & i_core_en)
          w_fsm_rx_nxt_state = (w_r_rows_head == 17'd0) ? ENUM_ST_R_POP : ENUM_ST_R_AW;
      end
""", """      ENUM_ST_R_IDLE: begin
        casez ({((reg_evq_cnt != '0) & i_dma_en & i_core_en), (w_r_rows_head == 17'd0), w_sg, w_rx_gate})
          4'b11??: w_fsm_rx_nxt_state = ENUM_ST_R_POP;
          4'b1011: w_fsm_rx_nxt_state = ENUM_ST_R_DAR;
          4'b100?: w_fsm_rx_nxt_state = ENUM_ST_R_AW;
          default: w_fsm_rx_nxt_state = ENUM_ST_R_IDLE;
        endcase
      end
      ENUM_ST_R_DAR: begin
        if (i_axim_arready)
          w_fsm_rx_nxt_state = ENUM_ST_R_DRD;
      end
      ENUM_ST_R_DRD: begin
        if (w_desc_last)
          w_fsm_rx_nxt_state = w_d_ovf ? ENUM_ST_R_WBA : ENUM_ST_R_AW;
      end
      ENUM_ST_R_WBA: begin
        if (i_axim_awready)
          w_fsm_rx_nxt_state = ENUM_ST_R_WBW;
      end
      ENUM_ST_R_WBW: begin
        if (i_axim_wready)
          w_fsm_rx_nxt_state = ENUM_ST_R_WBB;
      end
      ENUM_ST_R_WBB: begin
        if (i_axim_bvalid)
          w_fsm_rx_nxt_state = ENUM_ST_R_UPD;
      end
""")
rep("          w_fsm_rx_nxt_state = (reg_r_left == 17'd0) ? ENUM_ST_R_UPD : ENUM_ST_R_AW;",
    "          w_fsm_rx_nxt_state = (reg_r_left == 17'd0) ? (w_sg ? ENUM_ST_R_WBA : ENUM_ST_R_UPD) : ENUM_ST_R_AW;")

# ---------------------------------------------------------------- RX registers
rep("      reg_r_outst   <= 3'd0;\n    end else begin\n      if ((reg_fsm_rx_current_state == ENUM_ST_R_IDLE)",
    "      reg_r_outst   <= 3'd0;\n      reg_r_dp      <= 32'd0;\n      reg_r_ovf     <= 1'b0;\n    end else begin\n"
    "      if ((reg_fsm_rx_current_state == ENUM_ST_R_IDLE)")
rep("        reg_r_addr    <= w_r_base;\n        reg_r_outst   <= 3'd0;\n      end\n",
    "        reg_r_addr    <= w_r_base;\n        reg_r_outst   <= 3'd0;\n        reg_r_dp      <= w_r_base64[31:0];\n"
    "        reg_r_ovf     <= 1'b0;\n      end\n"
    "      if ((reg_fsm_rx_current_state == ENUM_ST_R_DRD) & w_desc_last) begin\n"
    "        reg_r_addr <= w_d_addr64[PARA_USB2_AXI_ADDR_W-1:0];\n"
    "        reg_r_ovf  <= w_d_ovf;\n"
    "        if (w_d_ovf) begin\n"
    "          reg_r_left    <= 17'd0;\n          reg_r_rq_left <= 17'd0;\n        end\n      end\n"
    "      if ((reg_fsm_rx_current_state == ENUM_ST_R_WBB) & i_axim_bvalid)\n"
    "        reg_r_dp <= reg_r_dp + 32'd8;\n")

# descriptor capture (own block)
rep("  // Event queue and credit counters:",
    """  // Descriptor beat capture: the first beat holds word 0 (the only beat on a 64-bit bus).
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_desc
    if (!i_rst_n_bus) begin
      reg_d_w0   <= 32'd0;
      reg_d_beat <= 1'b0;
    end else if (w_desc_rd) begin
      if (!reg_d_beat)
        reg_d_w0 <= i_axim_rdata[31:0];
      reg_d_beat <= ~i_axim_rlast & ~reg_d_beat;
    end
  end

  // Event queue and credit counters:""")

# RX read requests wait for the descriptor
rep("    end else if ((reg_fsm_rx_current_state != ENUM_ST_R_IDLE) & (reg_r_rq_left != 17'd0) &\n                 (reg_r_outst < LPARA_OUTST_MAX[2:0])) begin",
    "    end else if ((reg_fsm_rx_current_state != ENUM_ST_R_IDLE) & ~w_rx_dph & (reg_r_rq_left != 17'd0) &\n"
    "                 (reg_r_outst < LPARA_OUTST_MAX[2:0])) begin")

# ---------------------------------------------------------------- TX
rep("  assign w_t_len_calc  = (reg_t_rem > {8'd0, reg_t_mps}) ? {1'b0, reg_t_mps} : reg_t_rem[11:0];",
    "  assign w_t_cap       = w_sg ? reg_t_dlen : reg_t_mps;\n"
    "  assign w_t_len_calc  = (reg_t_rem > {8'd0, w_t_cap}) ? {1'b0, w_t_cap} : reg_t_rem[11:0];\n"
    "  assign w_t_rbeat     = (reg_fsm_tx_current_state == ENUM_ST_T_R) & w_grant_t & i_axim_rvalid;")
rep("""  assign o_axim_araddr  = reg_t_addr;
  assign o_axim_arlen   = w_t_nb_calc[7:0] - 8'd1;""",
    """  assign o_axim_araddr  = w_dar ? w_dar64[PARA_USB2_AXI_ADDR_W-1:0] : reg_t_addr;
  assign o_axim_arlen   = w_dar ? LPARA_DESC_ARL[7:0] : (w_t_nb_calc[7:0] - 8'd1);""")
rep("  assign o_axim_arvalid = (reg_fsm_tx_current_state == ENUM_ST_T_AR);\n  assign o_axim_rready  = (reg_fsm_tx_current_state == ENUM_ST_T_R) & w_grant_t;",
    "  assign o_axim_arvalid = (reg_fsm_tx_current_state == ENUM_ST_T_AR) | w_dar;\n"
    "  assign o_axim_rready  = ((reg_fsm_tx_current_state == ENUM_ST_T_R) & w_grant_t) | w_rx_dph_rd | w_tx_dph_rd;")
rep("""      ENUM_ST_T_CRED: begin
        if (reg_t_rem == 19'd0)
          w_fsm_tx_nxt_state = ENUM_ST_T_IDLE;
        else if (reg_credit[reg_t_q] >= w_t_rows_calc)
          w_fsm_tx_nxt_state = ENUM_ST_T_AR;
      end
""", """      ENUM_ST_T_CRED: begin
        casez ({(reg_t_rem == 19'd0), (w_sg & ~reg_t_dv), (reg_credit[reg_t_q] >= w_t_rows_calc), w_rx_ar_busy})
          4'b1???: w_fsm_tx_nxt_state = ENUM_ST_T_IDLE;
          4'b01?0: w_fsm_tx_nxt_state = ENUM_ST_T_DAR;
          4'b0010: w_fsm_tx_nxt_state = ENUM_ST_T_AR;
          default: w_fsm_tx_nxt_state = ENUM_ST_T_CRED;
        endcase
      end
      ENUM_ST_T_DAR: begin
        if (i_axim_arready)
          w_fsm_tx_nxt_state = ENUM_ST_T_DRD;
      end
      ENUM_ST_T_DRD: begin
        if (w_desc_last)
          w_fsm_tx_nxt_state = ENUM_ST_T_CRED;
      end
      ENUM_ST_T_WBA: begin
        if (i_axim_awready & ~w_rx_aw_busy)
          w_fsm_tx_nxt_state = ENUM_ST_T_WBW;
      end
      ENUM_ST_T_WBW: begin
        if (i_axim_wready)
          w_fsm_tx_nxt_state = ENUM_ST_T_WBB;
      end
      ENUM_ST_T_WBB: begin
        if (i_axim_bvalid)
          w_fsm_tx_nxt_state = ENUM_ST_T_UPD;
      end
""")
rep("        if (w_grant_t)\n          w_fsm_tx_nxt_state = ENUM_ST_T_UPD;",
    "        if (w_grant_t)\n          w_fsm_tx_nxt_state = w_sg ? ENUM_ST_T_WBA : ENUM_ST_T_UPD;")

# TX registers
rep("      reg_t_left <= 17'd0;\n    end else begin\n      for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin\n        reg_en_i_d[idx] <= i_epi_ctrl[idx][22];",
    "      reg_t_left <= 17'd0;\n      reg_t_dp   <= 32'd0;\n      reg_t_dv   <= 1'b0;\n      reg_t_dlen <= 11'd0;\n    end else begin\n"
    "      for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin\n        reg_en_i_d[idx] <= i_epi_ctrl[idx][22];")
rep("        reg_t_mps  <= w_pick_mps;\n        if (w_pick_host)",
    "        reg_t_mps  <= w_pick_mps;\n        reg_t_dp   <= w_pick_addr;\n        reg_t_dv   <= 1'b0;\n        if (w_pick_host)")
rep("      if (o_axim_rready & i_axim_rvalid) begin\n        reg_t_left <= reg_t_left - 17'd1;",
    "      if ((reg_fsm_tx_current_state == ENUM_ST_T_DRD) & w_desc_last) begin\n"
    "        reg_t_addr <= w_d_addr64[PARA_USB2_AXI_ADDR_W-1:0];\n"
    "        reg_t_dlen <= (w_d_w1[18:0] > {8'd0, reg_t_mps}) ? reg_t_mps : w_d_w1[10:0];\n"
    "        reg_t_dv   <= 1'b1;\n"
    "        if (w_d_w1[18:0] == 19'd0)\n          reg_t_rem <= 19'd0;\n      end\n"
    "      if ((reg_fsm_tx_current_state == ENUM_ST_T_WBB) & i_axim_bvalid)\n"
    "        reg_t_dp <= reg_t_dp + 32'd8;\n"
    "      if ((reg_fsm_tx_current_state == ENUM_ST_T_UPD) & ~w_rx_upd)\n        reg_t_dv <= 1'b0;\n"
    "      if (w_t_rbeat) begin\n        reg_t_left <= reg_t_left - 17'd1;")

# address load and error
rep("        reg_ld_addr <= w_r_addr_nxt[31:0];", "        reg_ld_addr <= w_sg ? reg_r_dp : w_r_addr_nxt[31:0];")
rep("        reg_ld_addr <= w_t_addr_nxt[31:0];", "        reg_ld_addr <= w_sg ? reg_t_dp : w_t_addr_nxt[31:0];")
rep("      reg_dma_err <= reg_axi_err;",
    "      reg_dma_err <= reg_axi_err | ((reg_fsm_rx_current_state == ENUM_ST_R_DRD) & w_desc_last & w_d_ovf);")
open(p, 'w').write(s)
print('ok')
