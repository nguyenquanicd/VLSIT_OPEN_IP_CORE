// f_apb_data.sv - formal harness for m_dvp_apb_data (t_dvp_control_formal: apb_pop_safety, timeout_counter).
// AI-generated candidate (R-117). Properties come from HDS REQ-IF-002/005 and decision Q-ENV-1 (an empty read completes with PSLVERR at
// access cycle N; N = 0 and N = 1 complete in cycle 1). Assumptions are APB4 legality only plus a bound N <= 6 on the 32-bit timeout.
module f_apb_data (
  input wire        clk,
  input wire        rst_n,
  input wire        psel,
  input wire        penable,
  input wire        pwrite,
  input wire        aligned,
  input wire [31:0] timeout,
  input wire [7:0]  data,
  input wire        empty
);
  wire        rd_en, pready, pslverr;
  wire [31:0] prdata;

  m_dvp_apb_data #(.PARA_DATA_W(32'd8)) dut (
    .i_clk_apb (clk), .i_rst_n_apb (rst_n), .i_psel (psel), .i_penable (penable), .i_pwrite (pwrite),
    .i_fifo_aligned (aligned), .i_timeout_cycles (timeout), .i_fifo_data (data), .i_fifo_empty (empty),
    .o_fifo_rd_en (rd_en), .o_pready (pready), .o_prdata (prdata), .o_pslverr (pslverr));

  reg past_valid = 1'b0;
  always @(posedge clk) past_valid <= 1'b1;

  // ---- assumptions: one reset at the start, then legal APB4 requests with stable fields until completion
  initial assume (!rst_n);
  always @(posedge clk) begin
    if (past_valid && $past(rst_n)) assume (rst_n);
    if (!rst_n) assume (!psel);
    assume (timeout <= 32'd6);
    assume (!(penable && !psel));
    if (past_valid && rst_n && $past(rst_n)) begin
      if ($past(psel) && !$past(penable)) begin                                          // setup is followed by access with the same fields
        assume (psel && penable);
        assume (pwrite == $past(pwrite));
        assume (aligned == $past(aligned));
        assume (timeout == $past(timeout));
      end
      if ($past(psel) && $past(penable) && !$past(pready)) begin                          // wait state: everything stable
        assume (psel && penable);
        assume (pwrite == $past(pwrite));
        assume (aligned == $past(aligned));
        assume (timeout == $past(timeout));
      end
      if ($past(psel) && $past(penable) && $past(pready)) assume (!penable);              // completion ends the access phase
    end
  end

  // access-cycle counter: access cycle 1 is the first cycle with PENABLE high
  reg [7:0] cyc = 8'd0;          // access cycles completed before this cycle
  reg       empty_held = 1'b1;   // FIFO empty in every earlier access cycle of this transfer
  reg       popped = 1'b0;
  always @(posedge clk) begin
    if (!rst_n || !psel || !penable) begin
      cyc <= 8'd0; empty_held <= 1'b1; popped <= 1'b0;
    end else begin
      if (cyc != 8'hFF) cyc <= cyc + 8'd1;
      if (!empty) empty_held <= 1'b0;
      if (rd_en) popped <= 1'b1;
    end
  end
  wire [7:0] cyc_now   = (psel && penable) ? (cyc + 8'd1) : 8'd0;   // access cycle number of this cycle
  wire       empty_now = empty_held && empty;                         // empty in all access cycles up to and including this one
  wire [7:0] target    = (timeout <= 32'd1) ? 8'd1 : timeout[7:0];

  always @(posedge clk) if (rst_n) begin
    // pop safety: one pop, only on a successful aligned read of an available sample (a_formal_pop_exactly_once)
    if (rd_en) begin
      assert (psel && penable && !pwrite && aligned && !empty && pready && !pslverr);
      assert (!popped);
      assert (prdata == {24'd0, data});
    end
    if (pslverr) assert (!rd_en);
    if (psel && penable && pwrite) assert (pready && pslverr && !rd_en);        // writes to the endpoint error and never pop
    if (psel && penable && !aligned) assert (pready && pslverr && !rd_en);       // misaligned accesses error and never pop
    // exact empty-read timeout (a_formal_timeout_exact)
    if (psel && penable && !pwrite && aligned && empty_now) begin
      if (cyc_now < target) assert (!pready);
      if (cyc_now == target) assert (pready && pslverr && !rd_en);
    end
    // a sample present in the first access cycle completes at once with success and one pop
    if (psel && penable && !pwrite && aligned && !empty && cyc_now == 8'd1) assert (pready && !pslverr && rd_en);
  end

  // non-vacuity (cg_formal_pop_cover, cg_formal_timeout_cover)
  always @(posedge clk) if (rst_n) begin
    cover (rd_en);
    cover (psel && penable && pready && pslverr && !pwrite && aligned && empty_now && timeout == 32'd3 && cyc_now == 8'd3);
    cover (psel && penable && pready && pslverr && !pwrite && aligned && empty_now && timeout == 32'd0 && cyc_now == 8'd1);
  end
endmodule
