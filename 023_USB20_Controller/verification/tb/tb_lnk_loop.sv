`timescale 1ns/1ps
// Scratch test: transmitter -> receiver loop of the link, 8-bit or 16-bit lanes (parameter W).
module tb_lnk_loop;
  parameter int W = 8;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  // tx side
  logic        tx_req;
  logic [2:0]  tx_kind;
  logic [3:0]  tx_pid;
  logic [18:0] tx_fld;
  logic [11:0] tx_len;
  logic [15:0] src_dat;
  logic        src_vld;
  logic        src_pop;
  logic        tx_busy, tx_done, tx_fail;
  logic [15:0] tx_data;
  logic [1:0]  tx_valid;
  logic        tx_ready;
  // rx side
  logic        tok_vld, tok_ext, spl_vld, hs_vld, dat_sop, dat_end, dat_ok;
  logic [3:0]  tok_pid, hs_pid, dat_pid;
  logic [10:0] tok_fld;
  logic [18:0] spl_fld;
  logic [1:0]  dat_n;
  logic [15:0] dat_b;
  logic [11:0] dat_len;
  logic        err_pid, err_crc, err_stuf, err_bab, rx_busy, pkt_end;

  m_usb2_lnktx #(.PARA_USB2_UTMI_W(W)) u_tx (
    .i_clk_phy(clk), .i_rst_n_core(rst_n),
    .i_tx_req(tx_req), .i_tx_kind(tx_kind), .i_tx_pid(tx_pid), .i_tx_fld(tx_fld), .i_tx_len(tx_len),
    .i_src_dat(src_dat), .i_src_vld(src_vld), .o_src_pop(src_pop),
    .o_tx_busy(tx_busy), .o_tx_done(tx_done), .o_tx_fail(tx_fail),
    .o_tx_data(tx_data), .o_tx_valid(tx_valid), .i_tx_ready(tx_ready), .i_tx_abort(1'b0));

  // receiver sees the tx stream; rx_active follows tx_valid
  m_usb2_lnkrx #(.PARA_USB2_UTMI_W(W)) u_rx (
    .i_clk_phy(clk), .i_rst_n_core(rst_n),
    .i_rx_data(tx_data), .i_rx_valid(tx_valid & {2{tx_ready}}), .i_rx_active(tx_valid[0]), .i_rx_err(1'b0),
    .o_tok_vld(tok_vld), .o_tok_ext(tok_ext), .o_tok_pid(tok_pid), .o_tok_fld(tok_fld),
    .o_spl_vld(spl_vld), .o_spl_fld(spl_fld), .o_hs_vld(hs_vld), .o_hs_pid(hs_pid),
    .o_dat_sop(dat_sop), .o_dat_pid(dat_pid), .o_dat_n(dat_n), .o_dat_b(dat_b), .o_dat_end(dat_end),
    .o_dat_ok(dat_ok), .o_dat_len(dat_len), .o_err_pid(err_pid), .o_err_crc(err_crc),
    .o_err_stuf(err_stuf), .o_err_babble(err_bab), .o_rx_busy(rx_busy), .o_pkt_end(pkt_end));

  // payload source model
  byte unsigned pay [0:2047];
  int sp;
  assign src_dat = {pay[sp+1], pay[sp]};
  assign src_vld = 1'b1;
  always_ff @(posedge clk) begin
    if (!rst_n) sp <= 0;
    else if (src_pop) sp <= sp + (W==16 ? 2 : 1);
  end

  // ready: random stalls
  int seed = 1;
  always_ff @(posedge clk) tx_ready <= (W==16 || 1) ? (($urandom % 4) != 0) : 1'b1;

  // capture of received payload
  byte unsigned got [0:2047];
  int gn;
  logic [11:0] got_len; logic got_ok, got_end_seen;
  always_ff @(posedge clk) begin
    if (dat_sop) gn <= 0;
    if (dat_n >= 1) begin got[gn] <= dat_b[7:0]; end
    if (dat_n == 2) begin got[gn+1] <= dat_b[15:8]; end
    if (dat_n != 0) gn <= gn + dat_n;
    if (dat_end) begin got_len <= dat_len; got_ok <= dat_ok; got_end_seen <= 1'b1; end
  end

  int lens [9] = '{0,1,2,3,5,8,17,64,100};
  int errors = 0, checks = 0;
  task automatic chk(input bit c, input string msg);
    checks++;
    if (!c) begin errors++; $display("FAIL: %s", msg); end
  endtask

  task automatic send(input logic [2:0] kind, input logic [3:0] pid, input logic [18:0] fld, input int len);
    @(posedge clk);
    sp = 0; tx_req <= 1'b1; tx_kind <= kind; tx_pid <= pid; tx_fld <= fld; tx_len <= len;
    @(posedge clk); tx_req <= 1'b0;
    wait (tx_done);
    repeat (6) @(posedge clk);
  endtask

  // event monitors for token/hs
  int ntok, nspl, nhs, nerr;
  logic [3:0] last_tok_pid; logic [10:0] last_tok_fld; logic [18:0] last_spl_fld; logic [3:0] last_hs_pid;
  always_ff @(posedge clk) begin
    if (tok_vld) begin ntok <= ntok + 1; last_tok_pid <= tok_pid; last_tok_fld <= tok_fld; end
    if (spl_vld) begin nspl <= nspl + 1; last_spl_fld <= spl_fld; end
    if (hs_vld)  begin nhs  <= nhs + 1;  last_hs_pid <= hs_pid; end
    if (err_pid | err_crc | err_stuf | err_bab) nerr <= nerr + 1;
  end

  initial begin
    tx_req = 0; tx_kind = 0; tx_pid = 0; tx_fld = 0; tx_len = 0; ntok = 0; nspl = 0; nhs = 0; nerr = 0; gn = 0;
    got_end_seen = 0;
    for (int i = 0; i < 2048; i++) pay[i] = i * 7 + 3;
    repeat (4) @(posedge clk); rst_n = 1; repeat (3) @(posedge clk);
    // handshake
    send(0, 4'h2, 0, 0);
    chk(nhs == 1 && last_hs_pid == 4'h2, "ACK handshake");
    send(0, 4'hA, 0, 0);
    chk(nhs == 2 && last_hs_pid == 4'hA, "NAK handshake");
    // token OUT addr 0x55 ep 0xA
    send(1, 4'h1, {8'h0, 4'hA, 7'h55} , 0);
    chk(ntok == 1 && last_tok_pid == 4'h1 && last_tok_fld == {4'hA, 7'h55}, "OUT token");
    send(1, 4'h5, 11'h5A7, 0);
    chk(ntok == 2 && last_tok_pid == 4'h5 && last_tok_fld == 11'h5A7, "SOF token");
    // split token
    send(2, 4'h8, 19'h4A5B3, 0);
    chk(nspl == 1 && last_spl_fld == 19'h4A5B3, "SPLIT token");
    // data packets of several lengths
    for (int k = 0; k < 9; k++) begin
      int L;
      L = lens[k];
      got_end_seen = 0;
      send(3, 4'h3, 0, L);
      chk(got_end_seen && got_ok && got_len == L, $sformatf("DATA len %0d ok=%0b got_len=%0d", L, got_ok, got_len));
      for (int i = 0; i < L; i++) chk(got[i] == pay[i], $sformatf("payload byte %0d len %0d got %02x exp %02x", i, L, got[i], pay[i]));
    end
    chk(nerr == 0, $sformatf("no errors (%0d)", nerr));
    $display("TB_LNK_LOOP W=%0d checks=%0d errors=%0d", W, checks, errors);
    $finish;
  end
  int dbg = 0;
  always @(posedge clk) if (dbg < 60 && (tx_valid != 0 || tx_done || tx_req || dat_n != 0 || dat_sop || dat_end) && ntok == 2 && nspl == 1 && nhs == 2) begin dbg++; $display("%t dn=%0d db=%04x sop=%b end=%b req=%b st=%0d valid=%b data=%04x ready=%b done=%b busy=%b", $time, dat_n, dat_b, dat_sop, dat_end, tx_req, u_tx.reg_fsm_tx_current_state, tx_valid, tx_data, tx_ready, tx_done, tx_busy); end
  initial begin #2000000; $display("TIMEOUT"); $finish; end
endmodule
