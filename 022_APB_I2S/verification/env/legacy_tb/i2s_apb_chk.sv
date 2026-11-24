`timescale 1ns/1ps
// APB4 protocol and register-access assertions of the APB I2S IP (verification only).
// Sources: IHI0024D (REF-002) clauses named in each assertion, VLSIT_APB_I2S_HDS.md sections 6.3,
// 11.4 and requirements REQ-IF-001..REQ-IF-006, REQ-SEC-001. Clocked checks: a check samples the
// values before the flip-flops update. A check that never fires fails the run (R-025).
module i2s_apb_chk #(
  parameter int N = 24
) (
  input logic        clk,
  input logic        rst_n,
  input logic        psel,
  input logic        penable,
  input logic        pwrite,
  input logic [15:0] paddr,
  input logic [31:0] pwdata,
  input logic [3:0]  pstrb,
  input logic [2:0]  pprot,
  input logic        pready,
  input logic        pslverr,
  input logic [31:0] prdata,
  input logic        protect_en,
  input logic        slverr_en
);
  int hit [0:N];
  int bad [0:N];
  string nm [0:N];

  initial begin
    for (int i = 0; i <= N; i++) begin hit[i] = 0; bad[i] = 0; nm[i] = ""; end
    nm[1]  = "APB-01 PENABLE only with PSEL (IHI0024D 3.1.1, setup then access)";
    nm[2]  = "APB-02 setup phase lasts one cycle (IHI0024D 3.1.1)";
    nm[3]  = "APB-03 PENABLE low in the first cycle of a transfer (IHI0024D 3.1.1)";
    nm[4]  = "APB-04 PSEL and PENABLE held until PREADY (IHI0024D 3.1.2)";
    nm[5]  = "APB-05 PADDR stable until completion (IHI0024D 3.1.2)";
    nm[6]  = "APB-06 PWRITE stable until completion (IHI0024D 3.1.2)";
    nm[7]  = "APB-07 PWDATA stable until completion of a write (IHI0024D 3.1.2)";
    nm[8]  = "APB-08 PSTRB stable until completion of a write (IHI0024D 3.1.2, 3.2)";
    nm[9]  = "APB-09 PPROT stable until completion (IHI0024D 3.1.2, 3.5)";
    nm[10] = "APB-10 PREADY not X in the access phase (IHI0024D 3.1.2)";
    nm[11] = "APB-11 PSLVERR not X at completion (IHI0024D 3.4)";
    nm[12] = "APB-12 PRDATA not X at a read completion (IHI0024D 3.1.2)";
    nm[13] = "APB-13 normal access has one wait state (REQ-IF-002, 11.4)";
    nm[14] = "APB-14 partial strobe write gives PSLVERR (REQ-IF-003, IHI0024D 3.2)";
    nm[15] = "APB-15 misaligned address gives PSLVERR (REQ-IF-003, 11.4)";
    nm[16] = "APB-16 non-secure access gives PSLVERR when protected (REQ-SEC-001, IHI0024D 3.5)";
    nm[17] = "APB-17 legal access gives OKAY (REQ-IF-001, IHI0024D 3.4)";
    nm[18] = "APB-18 unmapped aligned address: OKAY and read 0 (REQ-IF-004)";
    nm[19] = "APB-19 (recommendation) PSLVERR low when not in the completion cycle (IHI0024D 3.4)";
    nm[20] = "APB-20 reset: PREADY, PSLVERR, PRDATA low (6.2 reset values, REQ-RESET-001)";
    nm[21] = "APB-21 transfer ends within 8 access cycles (bounded progress)";
    nm[22] = "APB-22 after a completion PENABLE is low (requester legality, IHI0024D 3.1.2)";
  end

  task automatic chk(input int id, input logic ante, input logic cons);
    begin
      if (ante === 1'b1) begin
        hit[id]++;
        if (cons !== 1'b1) begin
          bad[id]++;
          if (bad[id] <= 3) $display("ASSERT FAIL @%0t: %s [psel=%b penable=%b pready=%b pslverr=%b pwrite=%b paddr=%h pstrb=%h prdata=%h rst_n=%b]", $time, nm[id], psel, penable, pready, pslverr, pwrite, paddr, pstrb, prdata, rst_n);
        end
      end
    end
  endtask

  function automatic logic is_mapped(input logic [15:0] a);
    logic [9:0] x;
    begin
      x = a[9:0];
      is_mapped = (x <= 10'h01C) || (x >= 10'h100 && x <= 10'h120) || (x >= 10'h200 && x <= 10'h220);
    end
  endfunction

  logic        p_psel, p_pen, p_pwrite, p_pready;
  logic [15:0] p_paddr;
  logic [31:0] p_pwdata;
  logic [3:0]  p_pstrb;
  logic [2:0]  p_pprot;
  int          acc_cnt;
  logic        p_rst_n = 1'b1;
  int          rec19 = 0;     // cycles with PSLVERR high outside the completion cycle (recommendation only)
  logic        completion, in_xfer_prev, first_cycle;
  logic        aligned, prot_err, strb_err;

  assign completion = psel & penable & pready;
  assign aligned    = (paddr[1:0] == 2'b00);
  assign prot_err   = pprot[1] & protect_en;
  assign strb_err   = pwrite & (pstrb != 4'hF);

  always @(posedge clk) begin
    in_xfer_prev = p_psel & ~(p_pen & p_pready);
    first_cycle  = psel & ~p_psel;
    chk(1,  penable, psel);
    chk(2,  p_psel & ~p_pen, psel & penable);
    chk(3,  first_cycle | (psel & p_pen & p_pready), ~penable);
    chk(4,  p_psel & p_pen & ~p_pready, psel & penable);
    chk(5,  in_xfer_prev & psel, paddr == p_paddr);
    chk(6,  in_xfer_prev & psel, pwrite == p_pwrite);
    chk(7,  in_xfer_prev & psel & pwrite, pwdata == p_pwdata);
    chk(8,  in_xfer_prev & psel & pwrite, pstrb == p_pstrb);
    chk(9,  in_xfer_prev & psel, pprot == p_pprot);
    chk(10, psel & penable, !$isunknown(pready));
    chk(11, completion, !$isunknown(pslverr));
    chk(12, completion & ~pwrite & ~pslverr, !$isunknown(prdata));
    chk(13, completion & ~strb_err & aligned & ~prot_err, acc_cnt == 1);
    chk(14, completion & strb_err & slverr_en & aligned & ~prot_err, pslverr);
    chk(15, completion & ~aligned & slverr_en, pslverr);
    chk(16, completion & prot_err & slverr_en & aligned & ~strb_err, pslverr);
    chk(17, completion & aligned & ~strb_err & ~prot_err, ~pslverr);
    chk(18, completion & aligned & ~prot_err & ~strb_err & ~pwrite & ~is_mapped(paddr), (prdata == 0) & ~pslverr);
    if (pslverr === 1'b1 && !(psel & penable & pready)) rec19++;
    chk(19, 1'b1, 1'b1);
    chk(21, psel & penable, acc_cnt < 8);
    chk(22, p_psel & p_pen & p_pready, ~penable);
    // acc_cnt counts the access cycles without PREADY before the current cycle
    if (psel & penable & ~pready) acc_cnt = acc_cnt + 1; else acc_cnt = 0;
    p_psel = psel; p_pen = penable; p_pwrite = pwrite; p_pready = pready;
    p_paddr = paddr; p_pwdata = pwdata; p_pstrb = pstrb; p_pprot = pprot;
  end

  // reset check: outputs at their reset values while the reset is low
  always @(posedge clk) begin
    chk(20, ~rst_n & ~p_rst_n, (pready === 1'b0) & (pslverr === 1'b0) & (prdata === 32'h0));   // reset low for a full cycle
    p_rst_n = rst_n;
  end

  initial begin
    p_psel = 0; p_pen = 0; p_pwrite = 0; p_pready = 0; p_paddr = 0; p_pwdata = 0; p_pstrb = 0; p_pprot = 0;
    acc_cnt = 0;
  end

  task report(output int total, output int failed, output int never);
    begin
      total = 0; failed = 0; never = 0;
      for (int i = 1; i <= 22; i++) begin
        total++;
        if (bad[i] != 0) failed++;
        if (hit[i] == 0) never++;
        $display("  %-92s hits=%0d fails=%0d%s", nm[i], hit[i], bad[i], (i == 19) ? $sformatf(" recommendation-not-met-cycles=%0d", rec19) : "");
      end
    end
  endtask
endmodule
