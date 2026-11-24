// f_ctrl.sv - formal harness for the control path of m_dvp_apb_service with its real FIFOs (depth 2), tied clocks
// (t_dvp_control_formal: mode_guard; single-clock abstraction, clk_dvp = clk_apb). AI-generated candidate (R-117). Properties come from HDS REQ-FUNC-004: the mode is accepted only
// while capture is disabled and a CTRL write cannot change the mode and enable capture at the same time. Assumptions: APB4 legality,
// reset at the start and no later reset (so no reset-recovery claim here). The flush handshake (REQ-FUNC-010) is not proven by this harness.
module f_ctrl (
  input wire        clk_apb,
  input wire        rst_n,
  input wire        dvp_vsync,
  input wire        afifo_wr_en,
  input wire [7:0]  afifo_wr_data,
  input wire        pixel_toggle,
  input wire [7:0]  gated_data,
  input wire        cont_frame_active,
  input wire        cont_frame_start,
  input wire        capture_quiescent,
  input wire [15:0] paddr,
  input wire        psel,
  input wire        penable,
  input wire        pwrite,
  input wire [31:0] pwdata,
  input wire [3:0]  pstrb,
  input wire        dma_ack
);
  // Single-clock abstraction: the sensor clock is tied to the APB clock, so no CDC behaviour is modelled by this harness.
  wire        clk_dvp = clk_apb;
  wire        pready, pslverr, capture_en, pclk_mode, dma_req;
  wire [31:0] prdata;

  m_dvp_apb_service #(
    .PARA_FIFO_DEPTH (32'd2), .PARA_DATA_W (32'd8), .PARA_VSYNC_ACTIVE (32'd1), .PARA_AFIFO_CELL_TYPE (32'd2),
    .PARA_AFIFO_MEM_USE_MACRO (32'd0), .PARA_FIFO_DATA_ADDR (32'h0000_0100)
  ) dut (
    .i_clk_apb (clk_apb), .i_rst_n_apb (rst_n), .i_clk_dvp (clk_dvp), .i_rst_n_dvp (rst_n),
    .i_dvp_vsync (dvp_vsync), .i_afifo_wr_en (afifo_wr_en), .i_afifo_wr_data (afifo_wr_data), .i_pixel_toggle (pixel_toggle),
    .i_gated_data (gated_data), .i_cont_frame_active (cont_frame_active), .i_cont_frame_start (cont_frame_start),
    .i_capture_quiescent (capture_quiescent), .i_paddr (paddr), .i_psel (psel), .i_penable (penable), .i_pwrite (pwrite),
    .i_pwdata (pwdata), .i_pstrb (pstrb), .i_pprot (3'd0), .i_dma_ack (dma_ack),
    .o_pready (pready), .o_prdata (prdata), .o_pslverr (pslverr), .o_capture_en (capture_en), .o_pclk_mode (pclk_mode), .o_dma_req (dma_req));

  reg past_valid = 1'b0;
  always @(posedge clk_apb) past_valid <= 1'b1;

  // ---- assumptions
  initial assume (!rst_n);
  always @(posedge clk_apb) begin
    if (past_valid && $past(rst_n)) assume (rst_n);
    if (!rst_n) assume (!psel);
    assume (!(penable && !psel));
    if (past_valid && rst_n && $past(rst_n)) begin
      if ($past(psel) && !$past(penable)) begin                                   // setup is followed by access with the same fields
        assume (psel && penable);
        assume (paddr == $past(paddr));
        assume (pwrite == $past(pwrite));
        assume (pwdata == $past(pwdata));
        assume (pstrb == $past(pstrb));
      end
      if ($past(psel) && $past(penable) && !$past(pready)) begin
        assume (psel && penable);
        assume (paddr == $past(paddr));
        assume (pwrite == $past(pwrite));
        assume (pwdata == $past(pwdata));
        assume (pstrb == $past(pstrb));
      end
      if ($past(psel) && $past(penable) && $past(pready)) assume (!penable);
    end
  end

  // last CTRL write seen in an access phase (full-word write to 0x0004); the CSR applies it before PREADY rises
  reg last_mode = 1'b0, last_cap = 1'b0, last_flush = 1'b0, seen_wr = 1'b0;
  always @(posedge clk_apb) begin
    if (!rst_n) begin last_mode <= 1'b0; last_cap <= 1'b0; last_flush <= 1'b0; seen_wr <= 1'b0; end
    else if (psel && penable && pwrite && (paddr == 16'h0004) && pstrb == 4'hF) begin
      last_mode <= pwdata[1]; last_cap <= pwdata[0]; last_flush <= pwdata[2]; seen_wr <= 1'b1;
    end
  end

  // ---- properties
  always @(posedge clk_apb) if (past_valid && rst_n && $past(rst_n)) begin
    // the mode never changes while capture is enabled before or after the change (a_mode_changes_only_when_safe)
    if (pclk_mode != $past(pclk_mode)) begin
      assert (!$past(capture_en) && !capture_en);
      assert (seen_wr);
      assert (pclk_mode == last_mode);
      assert (!last_cap);                       // the same write must not enable capture
      assert (!last_flush);
    end
    // capture is enabled only by a CTRL write that sets capture_en
    if (capture_en && !$past(capture_en)) begin
      assert (seen_wr);
      assert (last_cap);
    end
  end
  always @(posedge clk_apb) if (past_valid && rst_n && !$past(rst_n)) begin
    assert (!capture_en);
    assert (!pclk_mode);
  end

  // non-vacuity (cg_formal_mode_guard_cover)
  always @(posedge clk_apb) if (past_valid && rst_n && $past(rst_n)) begin
    cover (pclk_mode && !$past(pclk_mode));
    cover (capture_en && !$past(capture_en));
    cover (!pclk_mode && $past(pclk_mode));
  end
endmodule
