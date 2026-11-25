// f_csr.sv - formal harness for the generated CSR block m_vlsit_csr_dvp (t_dvp_control_formal: csr_event_priority).
// AI-generated candidate (R-117). Properties come from HDS DEC-034 (hardware event beats software event on an RWI field in the same cycle, events
// are separate per field) and from the sticky overflow rule of REQ-REG-001 / plan failure mode FM-009 (a W1C clear race is set-dominant).
// Assumptions: APB4 legality (fields stable from setup until completion), one reset at the start, constant protect/slverr enables.
module f_csr (
  input wire        clk,
  input wire        rst_n,
  input wire        psel,
  input wire        penable,
  input wire        pwrite,
  input wire [15:0] paddr,
  input wire [31:0] pwdata,
  input wire [3:0]  pstrb,
  input wire        protect_en,
  input wire        slverr_en,
  input wire        hw_flush_we,
  input wire        hw_flush_wd,
  input wire        hw_ovf_we,
  input wire        hw_ovf_wd,
  input wire        sts_full,
  input wire        sts_empty,
  input wire        sts_active,
  input wire [31:0] level,
  input wire [31:0] frames
);
  wire        pready, pslverr, pclk_mode, flush, capture_en, ovf;
  wire [31:0] prdata, wmark, timeout;

  m_vlsit_csr_dvp #(.PARA_ASYNCHRONOUS(32'd0)) dut (
    .i_clk_apb (clk), .i_rst_n_apb (rst_n), .i_clk_reg (clk), .i_rst_n_reg (rst_n),
    .i_apb_psel (psel), .i_apb_penable (penable), .i_apb_pwrite (pwrite), .i_apb_paddr (paddr), .i_apb_pwdata (pwdata),
    .i_apb_pstrb (pstrb), .i_apb_pprot (3'd0), .o_apb_pready (pready), .o_apb_pslverr (pslverr), .o_apb_prdata (prdata),
    .i_protect_en (protect_en), .i_slverr_en (slverr_en), .i_dvp_version_major (16'd1), .i_dvp_version_minor (16'd1),
    .o_dvp_ctrl_pclk_mode (pclk_mode), .o_dvp_ctrl_fifo_flush (flush), .i_hw_wdata_dvp_ctrl_fifo_flush (hw_flush_wd),
    .i_hw_we_dvp_ctrl_fifo_flush (hw_flush_we), .o_dvp_ctrl_capture_en (capture_en), .o_dvp_wmark_level (wmark),
    .o_dvp_timeout_cycles (timeout), .o_dvp_fifo_sts_ovf (ovf), .i_hw_wdata_dvp_fifo_sts_ovf (hw_ovf_wd),
    .i_hw_we_dvp_fifo_sts_ovf (hw_ovf_we), .i_dvp_fifo_sts_full (sts_full), .i_dvp_fifo_sts_empty (sts_empty),
    .i_dvp_fifo_sts_active (sts_active), .i_dvp_fifo_level_count (level), .i_dvp_frame_count_count (frames));

  reg past_valid = 1'b0;
  always @(posedge clk) past_valid <= 1'b1;

  // ---- assumptions
  initial assume (!rst_n);
  always @(posedge clk) begin
    if (past_valid && $past(rst_n)) assume (rst_n);
    if (!rst_n) assume (!psel);
    assume (!(penable && !psel));
    if (past_valid) begin
      assume (protect_en == $past(protect_en));
      assume (slverr_en == $past(slverr_en));
    end
    if (past_valid && rst_n && $past(rst_n)) begin
      if ($past(psel) && !$past(penable)) begin
        assume (psel && penable); assume (paddr == $past(paddr)); assume (pwrite == $past(pwrite));
        assume (pwdata == $past(pwdata)); assume (pstrb == $past(pstrb));
      end
      if ($past(psel) && $past(penable) && !$past(pready)) begin
        assume (psel && penable); assume (paddr == $past(paddr)); assume (pwrite == $past(pwrite));
        assume (pwdata == $past(pwdata)); assume (pstrb == $past(pstrb));
      end
      if ($past(psel) && $past(penable) && $past(pready)) assume (!penable);
    end
  end

  // APB write history: a write to a register shows in the register one or two cycles later
  reg [3:0] wr_ctrl = 4'd0, wr_sts = 4'd0, wr_other = 4'd0;
  wire wr_now = psel && pwrite;
  always @(posedge clk) begin
    wr_ctrl  <= {wr_ctrl[2:0],  wr_now && paddr == 16'h0004};
    wr_sts   <= {wr_sts[2:0],   wr_now && paddr == 16'h0010};
    wr_other <= {wr_other[2:0], wr_now && paddr != 16'h0004 && paddr != 16'h0010};
  end

  // ---- properties
  always @(posedge clk) if (past_valid && rst_n && $past(rst_n)) begin
    // hardware event beats the software event in the same cycle (DEC-034): a hardware load of 1 into the W1C overflow bit is never lost
    if ($past(hw_ovf_we) && $past(hw_ovf_wd)) assert (ovf);
    // hardware clear of the RWI flush request wins over any software write in the same cycle (DEC-034)
    if ($past(hw_flush_we) && !$past(hw_flush_wd)) assert (!flush);
    if ($past(hw_flush_we) && $past(hw_flush_wd)) assert (flush);
    // events of one field do not change another field: the overflow bit changes only with its own hardware event or a status write,
    // the flush request only with its own hardware event or a control write, and writes to other registers change neither
    if (ovf != $past(ovf)) assert ($past(hw_ovf_we) || wr_sts != 4'd0);
    if (flush != $past(flush)) assert ($past(hw_flush_we) || wr_ctrl != 4'd0);
    if (capture_en != $past(capture_en)) assert (wr_ctrl != 4'd0);
    if (pclk_mode != $past(pclk_mode)) assert (wr_ctrl != 4'd0);
    if (wmark != $past(wmark)) assert (wr_other != 4'd0);
    if (timeout != $past(timeout)) assert (wr_other != 4'd0);
  end

  // non-vacuity
  always @(posedge clk) if (past_valid && rst_n && $past(rst_n)) begin
    cover ($past(hw_ovf_we) && $past(hw_ovf_wd) && wr_sts != 4'd0 && ovf);                       // hardware set meets a status write
    cover ($past(hw_flush_we) && !$past(hw_flush_wd) && wr_ctrl != 4'd0 && !flush && $past(flush));  // hardware clear meets a control write
    cover (flush && !$past(flush));
    cover (ovf && !$past(ovf));
  end
endmodule
