// tb_tasks.svh - check counters, APB4 requester model, buffer bus helpers, reset and wait tasks.
// Included inside module tb_dsig_p1.

  // ----------------------------------------------------------------------------------------
  // Check counters and test bookkeeping
  // ----------------------------------------------------------------------------------------
  integer n_chk;
  integer n_fail;
  integer n_test;
  integer n_test_fail;
  integer fail_at_start;
  reg [8*110-1:0] cur_test;
  reg [63:0] apb_mask;           // masks the requester-side APB assertions of a deliberate violation
  reg [63:0] core_mask;          // masks the core assertions while a test breaks their premise

  initial begin
    n_chk = 0; n_fail = 0; n_test = 0; n_test_fail = 0; fail_at_start = 0; apb_mask = 64'h0; core_mask = 64'h0;
  end

  // Statistics per check message: how many times each check ran and failed (review of vacuous checks)
  reg [8*96-1:0] cs_msg [0:767];
  integer        cs_exec [0:767];
  integer        cs_bad  [0:767];
  integer        cs_n;
  integer        cs_i;
  integer        cs_k;
  initial cs_n = 0;
  task cs_note;
    input [8*96-1:0] msg;
    input            ok;
    begin
      cs_k = -1;
      for (cs_i = 0; cs_i < cs_n; cs_i = cs_i + 1)
        if (cs_msg[cs_i] == msg) cs_k = cs_i;
      if (cs_k < 0 && cs_n < 768) begin
        cs_k = cs_n; cs_msg[cs_k] = msg; cs_exec[cs_k] = 0; cs_bad[cs_k] = 0; cs_n = cs_n + 1;
      end
      if (cs_k >= 0) begin
        cs_exec[cs_k] = cs_exec[cs_k] + 1;
        if (ok !== 1'b1) cs_bad[cs_k] = cs_bad[cs_k] + 1;
      end
    end
  endtask

  task ck;
    input         ok;
    input [8*96-1:0] msg;
    begin
      cs_note(msg, ok);
      n_chk = n_chk + 1;
      if (ok !== 1'b1) begin
        n_fail = n_fail + 1;
        $display("CHECK FAIL @%0t [%0s]: %0s", $time, cur_test, msg);
      end
    end
  endtask

  // Check whose outcome depends on a decision of the designer that the specification leaves open
  // (R-005, R-026): it is reported as OPEN-n and counts as a failed check until the decision is made
  integer n_open;
  initial n_open = 0;
  task ck_open;
    input integer id;
    input         ok;
    input [8*110-1:0] msg;
    begin
      cs_note(msg[8*96-1:0], ok);
      n_chk = n_chk + 1;
      if (ok !== 1'b1) begin
        n_fail = n_fail + 1;
        n_open = n_open + 1;
        $display("CHECK FAIL @%0t [%0s]: OPEN-%0d %0s", $time, cur_test, id, msg);
      end
    end
  endtask

  task ck32;
    input [8*96-1:0] msg;
    input [31:0] got;
    input [31:0] exp;
    begin
      cs_note(msg, (got === exp));
      n_chk = n_chk + 1;
      if (got !== exp) begin
        n_fail = n_fail + 1;
        $display("CHECK FAIL @%0t [%0s]: %0s got=0x%08h expected=0x%08h", $time, cur_test, msg, got, exp);
      end
    end
  endtask

  task test_begin;
    input [8*110-1:0] name;
    begin
      cur_test = name;
      fail_at_start = n_fail;
      n_test = n_test + 1;
      $display("TEST BEGIN: %0s", name);
    end
  endtask

  task test_end;
    begin
      if (n_fail == fail_at_start) $display("TEST PASS : %0s", cur_test);
      else begin
        n_test_fail = n_test_fail + 1;
        $display("TEST FAIL : %0s (%0d failed checks)", cur_test, n_fail - fail_at_start);
      end
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // Clock helpers
  // ----------------------------------------------------------------------------------------
  task cyc;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) @(posedge clk_core);
    end
  endtask

  task cyc_apb;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) @(posedge clk_apb);
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // APB4 requester model (IHI 0024D clause 3 and 4.1)
  // ----------------------------------------------------------------------------------------
  reg  apb_keep;          // leave PSEL high after the transfer for a back-to-back transfer
  reg  apb_bb;            // the previous transfer left PSEL high
  integer apb_wait_max;
  integer apb_last_wait;  // wait states of the last transfer

  initial begin
    apb_keep = 1'b0; apb_bb = 1'b0; apb_wait_max = 200; apb_last_wait = 0;
  end

  task apb_xfer;
    input         wr;
    input  [15:0] a;
    input  [31:0] d;
    input  [3:0]  s;
    input  [2:0]  p;
    input  integer idle_before;
    output [31:0] rd;
    output        err;
    integer wcnt;
    reg     fin;
    begin
      if (apb_bb) begin
        apb_bb = 1'b0;
      end else begin
        repeat (idle_before) @(posedge clk_apb);
        @(posedge clk_apb);
        #1;
      end
      apb_psel = 1'b1; apb_penable = 1'b0; apb_pwrite = wr; apb_paddr = a;
      apb_pwdata = d;  apb_pstrb = s;      apb_pprot = p;
      @(posedge clk_apb);
      #1;
      apb_penable = 1'b1;
      fin = 1'b0; wcnt = 0;
      rd = 32'hx; err = 1'bx;
      while (!fin) begin
        @(posedge clk_apb);
        if (apb_pready === 1'b1) begin
          rd = apb_prdata; err = apb_pslverr; fin = 1'b1;
        end else begin
          wcnt = wcnt + 1;
          if (wcnt > apb_wait_max) begin
            fin = 1'b1;
            n_fail = n_fail + 1;
            $display("CHECK FAIL @%0t [%0s]: APB transfer to 0x%03h has no PREADY after %0d cycles",
                     $time, cur_test, a, wcnt);
          end
        end
      end
      apb_last_wait = wcnt;
      #1;
      apb_penable = 1'b0;
      if (apb_keep) begin
        apb_bb = 1'b1;
      end else begin
        apb_psel = 1'b0; apb_pwrite = 1'b0; apb_paddr = 16'h0; apb_pwdata = 32'h0;
        apb_pstrb = 4'h0; apb_pprot = 3'b000;
      end
    end
  endtask

  // Whole-word accesses of a secure requester; an error response is a failed check
  task apb_w;
    input [15:0] a;
    input [31:0] d;
    reg [31:0] rd;
    reg        er;
    begin
      apb_xfer(1'b1, a, d, 4'hF, 3'b000, 0, rd, er);
      ck(er === 1'b0, "unexpected PSLVERR on a write");
    end
  endtask

  task apb_r;
    input  [15:0] a;
    output [31:0] d;
    reg           er;
    begin
      apb_xfer(1'b0, a, 32'h0, 4'h0, 3'b000, 0, d, er);
      ck(er === 1'b0, "unexpected PSLVERR on a read");
    end
  endtask

  task apb_expect;
    input [8*60-1:0] msg;
    input [15:0] a;
    input [31:0] exp;
    reg [31:0] d;
    begin
      apb_r(a, d);
      ck32(msg, d, exp);
    end
  endtask

  // Read-modify helpers
  task csr_field_check;
    input [8*60-1:0] msg;
    input [15:0] a;
    input integer lsb;
    input integer width;
    input [31:0] exp;
    reg [31:0] d;
    reg [31:0] m;
    begin
      apb_r(a, d);
      m = (width >= 32) ? 32'hFFFF_FFFF : ((32'h1 << width) - 1);
      ck32(msg, (d >> lsb) & m, exp & m);
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // Buffer bus helpers (stand-in for the AXI4 block, word address of 64 bits)
  // ----------------------------------------------------------------------------------------
  reg bus_rej_seen;

  task bus_write;
    input [6:0]  wa;
    input [63:0] d;
    input [7:0]  s;
    begin
      @(posedge clk_core);
      #1;
      bus_wr_en = 1'b1; bus_wr_addr = wa; bus_wr_data = d; bus_wr_strb = s;
      bus_rej_seen = 1'b0;
      @(posedge clk_core);
      if (bus_wr_rej === 1'b1) bus_rej_seen = 1'b1;
      #1;
      bus_wr_en = 1'b0; bus_wr_strb = 8'h00;
      @(posedge clk_core);
      if (bus_wr_rej === 1'b1) bus_rej_seen = 1'b1;
      @(posedge clk_core);
      if (bus_wr_rej === 1'b1) bus_rej_seen = 1'b1;
    end
  endtask

  task bus_read;
    input  [6:0]  ra;
    output [63:0] d;
    output        rej;
    integer k;
    reg     got;
    begin
      @(posedge clk_core);
      #1;
      bus_rd_en = 1'b1; bus_rd_addr = ra;
      rej = 1'b0; got = 1'b0; d = 64'hx;
      @(posedge clk_core);
      if (bus_rd_rej === 1'b1) rej = 1'b1;
      if (bus_rd_valid === 1'b1) begin d = bus_rd_data; got = 1'b1; end
      #1;
      bus_rd_en = 1'b0;
      for (k = 0; k < 6; k = k + 1) begin
        if (!got) begin
          @(posedge clk_core);
          if (bus_rd_rej === 1'b1) rej = 1'b1;
          if (bus_rd_valid === 1'b1) begin d = bus_rd_data; got = 1'b1; end
        end
      end
      if (!got && !rej) begin
        n_fail = n_fail + 1;
        $display("CHECK FAIL @%0t [%0s]: bus read of word %0d returned neither valid nor reject",
                 $time, cur_test, ra);
      end
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // Reset
  // ----------------------------------------------------------------------------------------
  task do_reset;
    input integer n;
    begin
      rst_n_core = 1'b0;
      rst_n_apb  = 1'b0;
      apb_psel = 1'b0; apb_penable = 1'b0; apb_pwrite = 1'b0; apb_paddr = 16'h0;
      apb_pwdata = 32'h0; apb_pstrb = 4'h0; apb_pprot = 3'b000; apb_bb = 1'b0;
      bus_wr_en = 1'b0; bus_rd_en = 1'b0; bus_wr_addr = 7'h0; bus_rd_addr = 7'h0;
      bus_wr_data = 64'h0; bus_wr_strb = 8'h0;
      repeat (n) @(posedge clk_core);
      #1;
      rst_n_core = 1'b1;
      if (P_CSR_ASYNC == 32'd0) begin
        // one clock: the register reset of the CSR is the APB reset, released together with the core reset
        rst_n_apb = 1'b1;
      end else begin
        repeat (n) @(posedge clk_apb);
        #1;
        rst_n_apb = 1'b1;
      end
      repeat (4) @(posedge clk_core);
      repeat (4) @(posedge clk_apb);
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // Operation helpers: program the registers, start, wait, read the result
  // ----------------------------------------------------------------------------------------
  task prog_alg_en;
    input [14:0] m;
    begin
      apb_w(A_ALG_EN, {17'h0, m});
    end
  endtask

  task prog_op;
    input [3:0] alg;
    input [1:0] op;
    input [1:0] form;
    input       hedged;
    input [1:0] nonce;
    input [2:0] hash;
    input [1:0] hybpol;
    begin
      apb_w(A_OP, {2'b0, hybpol, 1'b0, hash, 2'b0, nonce, 3'b0, hedged, 2'b0, form, 2'b0, op,
                   4'h0, alg});
    end
  endtask

  task prog_set;
    input [3:0] slh;
    input [4:0] lmstype;
    input [3:0] lmots;
    input [3:0] hsslvl;
    input [5:0] xmss;
    begin
      apb_w(A_SET, {2'b0, xmss, hsslvl, lmots, 3'b0, lmstype, 4'h0, slh});
    end
  endtask

  task prog_len;
    input [31:0] len_msg;
    input [7:0]  len_ctx;
    input [16:0] off_msg;
    input [16:0] off_sig;
    input [16:0] off_pk;
    input [16:0] off_res;
    begin
      apb_w(A_LEN_MSG, len_msg);
      apb_w(A_LEN_CTX, {24'h0, len_ctx});
      apb_w(A_OFF_MSG, {15'h0, off_msg});
      apb_w(A_OFF_SIG, {15'h0, off_sig});
      apb_w(A_OFF_PK,  {15'h0, off_pk});
      apb_w(A_OFF_RES, {15'h0, off_res});
    end
  endtask

  // Clear every sticky flag and the result flags: a clean start for a new operation
  task clear_flags;
    begin
      apb_w(A_ERR,     32'hFFFF_FFFF);
      apb_w(A_IRQ_RAW, 32'hFFFF_FFFF);
      apb_w(A_ALARM,   32'hFFFF_FFFF);
    end
  endtask

  task cmd_clr;
    reg [31:0] r;
    integer i;
    reg stop;
    begin
      apb_w(A_CMD, 32'h4);
      cyc(4);
      stop = 1'b0; i = 0;
      while (!stop) begin
        apb_r(A_STS, r);
        if (r[0] == 1'b0) stop = 1'b1;
        i = i + 1;
        if (i > 200) stop = 1'b1;
      end
      cyc(4);
    end
  endtask

  task cmd_start;
    begin
      apb_w(A_CMD, 32'h1);
    end
  endtask

  task cmd_abort;
    begin
      apb_w(A_CMD, 32'h2);
    end
  endtask

  // Wait until the operation reports done or error and is idle again (bounded)
  reg wait_timeout;
  integer wait_tail;     // clocks waited after the operation is idle again
  initial wait_tail = 60;
  task wait_op_done;
    integer i;
    reg [31:0] r;
    reg        stop;
    begin
      wait_timeout = 1'b0;
      stop = 1'b0; i = 0;
      while (!stop) begin
        apb_r(A_IRQ_RAW, r);
        if (r[1:0] != 2'b00) stop = 1'b1;
        i = i + 1;
        if (i > 600) begin stop = 1'b1; wait_timeout = 1'b1; end
      end
      stop = 1'b0; i = 0;
      while (!stop) begin
        apb_r(A_STS, r);
        if (r[0] == 1'b0) stop = 1'b1;
        i = i + 1;
        if (i > 600) begin stop = 1'b1; wait_timeout = 1'b1; end
      end
      cyc(wait_tail);
    end
  endtask
