// f_flush.sv - formal harness for the flush handshake of m_dvp_buffer fed by the real m_dvp_capture (t_dvp_control_formal: flush_state).
// AI-generated candidate (R-117). Properties come from HDS REQ-FUNC-010 and ERR-007: after a flush completes the selected FIFO is empty and
// stays empty until capture is enabled again, and a pending flush shows an empty, full, zero-occupancy FIFO to the APB side.
// Single-clock abstraction (clk_dvp = clk_apb), FIFO depth 2. The CSR/service contract that surrounds the buffer is modelled as assumptions:
//   - a flush request rises only while capture is disabled and no flush is pending, is held until the hardware done pulse and may then
//     stay high for any time (a software write can keep the CSR bit set): the buffer must keep issuing done until the request falls;
//   - capture is enabled only when no flush is pending; the mode changes only while capture is disabled, no flush is pending and
//     o_mode_change_safe was 1;
//   - gated mode: HREF pulses are at least four cycles apart and VSYNC changes only after three stable cycles (sensor contract);
//   - one reset at the start, no later reset.
// The sensor pins are free. No internal signal of the DUT is forced or read.
module f_flush (
  input wire        clk,
  input wire        rst_n,
  input wire [7:0]  dvp_data,
  input wire        dvp_vsync,
  input wire        dvp_href,
  input wire        cap,
  input wire        mode,
  input wire        req,
  input wire        rd_en
);
  wire        afifo_wr_en, valid_toggle, cont_active, cont_start, quiescent;
  wire [7:0]  afifo_wr_data, gated_data;
  wire [7:0]  rd_data;
  wire        empty, full, active, ovf, mode_safe, frame_start, busy, done;
  wire [31:0] occ;

  m_dvp_capture #(.PARA_DATA_W(32'd8), .PARA_SAMPLE_EDGE(32'd0), .PARA_VSYNC_ACTIVE(32'd1), .PARA_HREF_ACTIVE(32'd1)) u_cap (
    .i_clk_dvp (clk), .i_rst_n_dvp (rst_n), .i_rst_n_gated (rst_n),
    .i_dvp_data (dvp_data), .i_dvp_vsync (dvp_vsync), .i_dvp_href (dvp_href),
    .i_capture_en (cap), .i_pclk_mode (mode),
    .o_afifo_wr_en (afifo_wr_en), .o_afifo_wr_data (afifo_wr_data), .o_gated_data (gated_data), .o_valid_toggle (valid_toggle),
    .o_cont_frame_active (cont_active), .o_cont_frame_start (cont_start), .o_capture_quiescent (quiescent));

  m_dvp_buffer #(.PARA_FIFO_DEPTH(32'd2), .PARA_DATA_W(32'd8), .PARA_AFIFO_CELL_TYPE(32'd2), .PARA_AFIFO_MEM_USE_MACRO(32'd0), .PARA_VSYNC_ACTIVE(32'd1)) u_buf (
    .i_clk_apb (clk), .i_rst_n_apb (rst_n), .i_clk_dvp (clk), .i_rst_n_dvp (rst_n),
    .i_capture_en (cap), .i_pclk_mode (mode), .i_dvp_vsync (dvp_vsync),
    .i_cont_frame_active (cont_active), .i_cont_frame_start (cont_start),
    .i_afifo_wr_en (afifo_wr_en), .i_afifo_wr_data (afifo_wr_data), .i_pixel_toggle (valid_toggle), .i_gated_data (gated_data),
    .i_capture_quiescent (quiescent), .i_flush_req (req), .i_rd_en (rd_en),
    .o_rd_data (rd_data), .o_empty (empty), .o_full (full), .o_occupancy (occ), .o_active (active), .o_overflow_event (ovf),
    .o_mode_change_safe (mode_safe), .o_frame_start (frame_start), .o_flush_busy (busy), .o_flush_done (done));

  reg past_valid = 1'b0;
  always @(posedge clk) past_valid <= 1'b1;

  // ---- assumptions
  initial assume (!rst_n);
  reg [2:0] hr_hist = 3'd0;      // HREF of the three previous cycles
  reg [2:0] vs_hist = 3'd0;      // VSYNC stable-cycle history (1 = changed in that cycle)
  always @(posedge clk) begin
    hr_hist <= {hr_hist[1:0], dvp_href};
    vs_hist <= {vs_hist[1:0], past_valid && (dvp_vsync != $past(dvp_vsync))};
  end
  always @(posedge clk) begin
    if (past_valid && $past(rst_n)) assume (rst_n);
    if (!rst_n) begin assume (!cap); assume (!req); assume (!mode); end
    if (past_valid && rst_n && !$past(rst_n)) begin assume (!cap); assume (!req); assume (!mode); end   // the CSR resets to zero and changes only by an APB write
    if (past_valid && rst_n && $past(rst_n)) begin
      if (req && !$past(req)) begin assume (!$past(cap) && !cap); assume (!$past(busy)); end        // request only with capture off and no flush pending
      if ($past(req) && !$past(done)) assume (req);                                                  // held until the hardware done pulse
      if (cap && !$past(cap)) begin assume (!$past(req)); assume (!$past(busy)); end                 // capture enable is masked while a flush is pending
      if (mode != $past(mode)) begin                                                                 // mode change guard (REQ-FUNC-004)
        assume (!$past(cap) && !cap); assume (!$past(req) && !req); assume ($past(mode_safe)); assume (!$past(busy));
      end
      if (mode) begin                                                                                // gated-sensor contract
        if (dvp_href) assume (!hr_hist[0] && !hr_hist[1] && !hr_hist[2]);
        if (dvp_vsync != $past(dvp_vsync)) assume (!vs_hist[0] && !vs_hist[1] && !vs_hist[2]);
      end
    end
  end

  // ---- properties
  reg flushed = 1'b0;            // a flush has completed and capture has not been enabled again
  always @(posedge clk) begin
    if (!rst_n || cap) flushed <= 1'b0;
    else if (past_valid && $past(busy) && !busy) flushed <= 1'b1;
  end

  always @(posedge clk) if (past_valid && rst_n && $past(rst_n)) begin
    // a pending flush presents an empty, full, zero-occupancy FIFO and blocks reads (ERR-007)
    if (busy) begin assert (empty); assert (full); assert (occ == 32'd0); end
    // when the flush completes the selected FIFO is empty (a_flush_empty_at_done)
    if ($past(busy) && !busy) begin assert (empty); assert (!full); assert (occ == 32'd0); end
    // and it stays empty while capture stays disabled: no sample in flight survives the reset (a_flush_no_stale_sample)
    if (flushed && !cap) begin assert (empty); assert (occ == 32'd0); end
    // the hardware done pulse only occurs while a request is pending and capture is disabled
    if (done) begin assert (req); assert (!cap); end
  end

  // a request that stays set after a done pulse gets another done pulse two cycles later (a_flush_done_repeats)
  reg done_q = 1'b0, redo = 1'b0;
  always @(posedge clk) begin
    done_q <= rst_n && done;
    redo   <= rst_n && done_q && req;
  end
  always @(posedge clk) if (past_valid && rst_n && $past(rst_n)) begin
    if (redo) assert (done);
  end

  // non-vacuity (cg_formal_flush_cover): a flush completes in each mode after the FIFO held data, and a sample was in flight at the request
  reg had_data = 1'b0;
  always @(posedge clk) begin
    if (!rst_n || (past_valid && $past(busy) && !busy)) had_data <= 1'b0;
    else if (!empty) had_data <= 1'b1;
  end
  always @(posedge clk) if (past_valid && rst_n && $past(rst_n)) begin
    cover ($past(busy) && !busy && had_data && !mode);
    cover ($past(busy) && !busy && had_data && mode);
    cover (req && !$past(req) && (afifo_wr_en || $past(afifo_wr_en)) && !mode);
    cover (flushed && !cap && cap == 1'b0 && $past(flushed) && !mode);
    cover (redo && done);                                                                              // request kept high after done, done repeated
  end
endmodule
