`timescale 1ns/1ps
module tb_core;
  parameter DW = 64; parameter QN = 4; parameter RC = 1; parameter CN = 1; parameter PA = 1;
  parameter string PFX = "enc64"; parameter AADL = 12; parameter MSGL = 114; parameter DIR = 0;
  parameter NIN = 17; parameter NOUT = 17; parameter KD = 1; parameter EXP_TAGERR = 0; parameter HOLD = 1;
  parameter CG = 1; parameter PUSHDLY = 1; parameter MSGMAX = 1280; parameter OUTFULL = 0;
  logic clk = 0; logic rst_n = 0;
  always #5 clk = ~clk;
  logic en, start, dir, abort, dma_en, tail; logic [3:0] slot; logic [15:0] aad_len, msg_len;
  logic [8:0] wm_wr, wm_rd; logic [31:0] n0, n1, n2, salt, ctr_lo, ctr_hi;
  wire hw_we_start, hw_we_abort, hw_we_ctr_lo, hw_we_ctr_hi; wire [31:0] hw_ctr_lo, hw_ctr_hi;
  wire ev_done, ev_tag_err, ev_len_err, ev_axi_err, ev_ctr_err, ev_key_err, sts_busy, sts_ctr_vld;
  wire key_req; wire [3:0] key_slot; logic [255:0] key_data; logic key_vld, key_err_in;
  wire in_rd_en, out_wr_en, f_in_req, f_out_req, out_gate;
  wire [DW-1:0] out_wr_data; logic [DW-1:0] in_data; logic in_empty;
  logic f_in_done, f_out_done; logic out_full;
  wire [8:0] dwm_wr, dwm_rd; wire dtail, den; wire [16:0] dbeats_wr, dbeats_rd; wire dact;
  m_chacha_core #(.PARA_QR_NUM(QN), .PARA_RND_CYC(RC), .PARA_CORE_NUM(CN), .PARA_POLY_ARCH(PA), .PARA_AXI_DW(DW),
    .PARA_FIFO_IN_DEPTH(16), .PARA_FIFO_OUT_DEPTH(256), .PARA_MSG_MAX_B(MSGMAX), .PARA_HOLD_EN(HOLD), .PARA_NONCE_HW(0),
    .PARA_NONCE_CHK(1), .PARA_CG_EN(CG)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_dft_test_en(1'b0),
    .i_cha_ctrl_en(en), .i_cha_ctrl_start(start), .i_cha_ctrl_dir(dir), .i_cha_ctrl_abort(abort), .i_cha_ctrl_dma_en(dma_en),
    .i_cha_ctrl_tail_mode(tail), .i_cha_ctrl_key_slot(slot), .i_cha_len_aad_len(aad_len), .i_cha_len_msg_len(msg_len),
    .i_cha_wm_wm_wr(wm_wr), .i_cha_wm_wm_rd(wm_rd), .i_cha_nonce0_nonce_w(n0), .i_cha_nonce1_nonce_w(n1), .i_cha_nonce2_nonce_w(n2),
    .i_cha_salt_salt(salt), .i_cha_ctr_lo_ctr(ctr_lo), .i_cha_ctr_hi_ctr(ctr_hi),
    .o_hw_we_start(hw_we_start), .o_hw_we_abort(hw_we_abort), .o_hw_ctr_lo(hw_ctr_lo), .o_hw_we_ctr_lo(hw_we_ctr_lo),
    .o_hw_ctr_hi(hw_ctr_hi), .o_hw_we_ctr_hi(hw_we_ctr_hi), .o_ev_done(ev_done), .o_ev_tag_err(ev_tag_err),
    .o_ev_len_err(ev_len_err), .o_ev_axi_err(ev_axi_err), .o_ev_ctr_err(ev_ctr_err), .o_ev_key_err(ev_key_err),
    .o_sts_busy(sts_busy), .o_sts_ctr_vld(sts_ctr_vld), .i_axi_err_evt(1'b0), .i_axi_rstd_evt(1'b0),
    .o_key_req(key_req), .o_key_slot(key_slot), .i_key_data(key_data), .i_key_vld(key_vld), .i_key_err(key_err_in),
    .o_in_rd_en(in_rd_en), .i_in_data(in_data), .i_in_empty(in_empty), .o_out_wr_en(out_wr_en), .o_out_wr_data(out_wr_data),
    .i_out_full(out_full), .o_flush_in_req(f_in_req), .o_flush_out_req(f_out_req), .i_flush_in_done(f_in_done),
    .i_flush_out_done(f_out_done), .o_out_gate(out_gate), .o_dma_wm_wr(dwm_wr), .o_dma_wm_rd(dwm_rd), .o_dma_tail_mode(dtail),
    .o_dma_en(den), .o_dma_beats_wr(dbeats_wr), .o_dma_beats_rd(dbeats_rd), .o_dma_msg_act(dact));
  // key store model
  integer kcnt = 0;
  always @(posedge clk) begin
    if (key_req && !key_vld && !key_err_in) begin kcnt <= kcnt + 1; if (kcnt + 1 >= KD) key_vld <= 1; end
    if (!key_req) begin key_vld <= 0; kcnt <= 0; end
  end
  initial begin key_err_in = 0; key_vld = 0; end
  // input fifo model
  logic [DW-1:0] inmem [0:1023]; integer inwp = 0, inrp = 0;
  logic [DW-1:0] expout [0:1023]; logic [DW-1:0] outmem [0:1023]; integer outwp = 0;
  always @(*) begin in_empty = (inrp == inwp); in_data = inmem[inrp]; end
  always @(posedge clk) begin
    if (in_rd_en && inrp != inwp) inrp <= inrp + 1;
    if (out_wr_en && !out_full) begin outmem[outwp] <= out_wr_data; outwp <= outwp + 1; end
  end
  initial out_full = OUTFULL;
  // flush model
  integer fcnt_in = 0, fcnt_out = 0; logic fl_in = 0, fl_out = 0;
  always @(posedge clk) begin
    f_in_done <= 0; f_out_done <= 0;
    if (f_in_req) begin fl_in <= 1; fcnt_in <= 0; end
    if (f_out_req) begin fl_out <= 1; fcnt_out <= 0; end
    if (fl_in) begin fcnt_in <= fcnt_in + 1; if (fcnt_in == 5) begin fl_in <= 0; f_in_done <= 1; inrp <= inwp; end end
    if (fl_out) begin fcnt_out <= fcnt_out + 1; if (fcnt_out == 5) begin fl_out <= 0; f_out_done <= 1; outwp <= 0; end end
  end
  // CSR start model
  always @(posedge clk) if (hw_we_start) start <= 0;
  integer cyc = 0; always @(posedge clk) cyc <= cyc + 1;
  integer t_start, t_done; integer errs = 0; integer done_cnt = 0, terr_cnt = 0;
  always @(posedge clk) begin if (ev_done) begin done_cnt <= done_cnt + 1; t_done <= cyc; end if (ev_tag_err) begin terr_cnt <= terr_cnt + 1; t_done <= cyc; end
    if (ev_len_err | ev_ctr_err | ev_key_err | ev_axi_err) $display("unexpected event len%b ctr%b key%b axi%b", ev_len_err, ev_ctr_err, ev_key_err, ev_axi_err); end
  logic [DW-1:0] inhex [0:1023];
  logic [255:0] keyv [0:0]; logic [95:0] noncev [0:0];
  integer idx;
  initial begin
    $readmemh({PFX,"_in.hex"}, inhex);
    $readmemh({PFX,"_out.hex"}, expout);
    $readmemh("key.hex", keyv); $readmemh("nonce.hex", noncev);
    key_data = keyv[0];
    en = 1; start = 0; dir = DIR; abort = 0; dma_en = 0; tail = 0; slot = 3; aad_len = AADL; msg_len = MSGL;
    wm_wr = 1; wm_rd = 1; n0 = noncev[0][31:0]; n1 = noncev[0][63:32]; n2 = noncev[0][95:64]; salt = 0; ctr_lo = 0; ctr_hi = 0;
    #33 rst_n = 1;
    repeat (3) @(posedge clk);
    #1 start = 1; t_start = cyc;
    // push the input beats after the start, one per PUSHDLY cycles
    for (idx = 0; idx < NIN; idx++) begin
      repeat (PUSHDLY) @(posedge clk);
      #1 inmem[inwp] = inhex[idx]; inwp = inwp + 1;
    end
    // wait for the end of the message
    idx = 0;
    while ((done_cnt + terr_cnt) == 0 && idx < 20000) begin @(posedge clk); idx++; end
    repeat (40) @(posedge clk);
    if (EXP_TAGERR) begin
      if (terr_cnt != 1 || done_cnt != 0) begin errs++; $display("EXPECTED tag_err: done=%0d tag_err=%0d", done_cnt, terr_cnt); end
      if (HOLD && outwp != 0) begin errs++; $display("hold mode: output not flushed, %0d beats left", outwp); end
    end else begin
      if (done_cnt != 1 || terr_cnt != 0) begin errs++; $display("EXPECTED done: done=%0d tag_err=%0d", done_cnt, terr_cnt); end
      if (outwp != NOUT) begin errs++; $display("output beats %0d expected %0d", outwp, NOUT); end
      for (idx = 0; idx < NOUT; idx++) if (idx < outwp && outmem[idx] !== expout[idx]) begin errs++; $display("beat %0d got %h exp %h", idx, outmem[idx], expout[idx]); end
      if (!out_gate) begin errs++; $display("gate low after done"); end
    end
    if (sts_busy) begin errs++; $display("busy still high"); end
    $display("RESULT %s DW=%0d Q=%0d R=%0d N=%0d PA=%0d cycles=%0d errors=%0d", PFX, DW, QN, RC, CN, PA, t_done - t_start, errs);
    $finish;
  end
endmodule
