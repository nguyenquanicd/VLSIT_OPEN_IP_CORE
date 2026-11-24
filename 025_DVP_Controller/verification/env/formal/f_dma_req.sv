// f_dma_req.sv - formal harness for m_dvp_dma_req (t_dvp_control_formal: dma_request_state).
// AI-generated candidate (R-117). Properties: HDS REQ-IF-004 (the request holds until a one-cycle ACK; after ACK it re-arms only after the
// occupancy fell below the watermark, or the watermark was 0 / above the depth per decision Q-DMA-1, and then reached it again; a zero
// watermark never starts a request). Assumption: the occupancy never exceeds the FIFO depth.
module f_dma_req (
  input wire        clk,
  input wire        rst_n,
  input wire [3:0]  occ,
  input wire [31:0] wm,
  input wire        ack
);
  localparam [31:0] DEPTH = 32'd8;
  wire req;
  m_dvp_dma_req #(.PARA_FIFO_DEPTH(DEPTH)) dut (
    .i_clk_apb (clk), .i_rst_n_apb (rst_n), .i_occupancy ({28'd0, occ}), .i_watermark (wm), .i_dma_ack (ack), .o_dma_req (req));

  reg past_valid = 1'b0;
  always @(posedge clk) past_valid <= 1'b1;
  initial assume (!rst_n);
  always @(posedge clk) begin
    if (past_valid && $past(rst_n)) assume (rst_n);
    assume (occ <= 4'd8);
  end

  wire cond_ok    = (wm != 32'd0) && (wm <= DEPTH) && ({28'd0, occ} >= wm);   // threshold reached with a legal watermark
  wire cond_below = (wm == 32'd0) || (wm > DEPTH) || ({28'd0, occ} < wm);     // re-arm condition

  // harness view of "an acknowledged request has not been re-armed yet"
  reg need_below = 1'b0;
  always @(posedge clk) begin
    if (!rst_n) need_below <= 1'b0;
    else if (req && ack) need_below <= 1'b1;
    else if (cond_below) need_below <= 1'b0;
  end

  always @(posedge clk) if (past_valid && rst_n && $past(rst_n)) begin
    if ($past(req) && !$past(ack)) assert (req);                                   // the request holds until ACK
    if (req && !$past(req)) assert ($past(cond_ok));                               // a request rises only at a reached legal threshold
    if (req && !$past(req)) assert (!$past(need_below));                           // no new request while an ACKed request is not re-armed
    if ($past(wm) == 32'd0) assert (!(req && !$past(req)));                        // a zero watermark never starts a request
    if ($past(req) && $past(ack)) assert (!req);                                   // ACK drops the request in the next cycle
  end

  always @(posedge clk) if (rst_n) begin
    cover (req);
    cover (req && ack);
    cover (past_valid && $past(req) && $past(ack) && !req);
    cover (past_valid && req && !$past(req) && $past(need_below) == 1'b0 && $past(cond_ok));
  end
endmodule
