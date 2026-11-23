`timescale 1ns/1ps
// Reproduction of review finding F-021: m_usb2_axs compares the 4-bit channel index with PARA_USB2_NUM_DMA_CH[3:0].
// For NUM_DMA_CH = 16 the slice is 0, so no channel is accepted.
// Build and run: sh run_repro.sh (Verilator, see build_run.sh); Icarus 14 cannot compile m_usb2_axs.sv (packed-array index in always_comb).
// The checks use only the specification rule (REQ-IF-007 / section 8: a channel c < PARA_USB2_NUM_DMA_CH with an enabled
// write map accepts a write; a channel >= NUM_DMA_CH is refused). Observed: the AXI response of the DUT and its error event.
`ifndef NCH
`define NCH 16
`endif
module tb_repro_f021;
  localparam int NCH = `NCH;
  localparam int NEP1 = 9;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic [NEP1-1:0][31:0] epi_ctrl = '0, epi_fifo = '0;
  logic [NCH-1:0][31:0]  dmach_map;
  logic [NCH-1:0]        dma_ack = '0;
  logic [31:0] awaddr = 0, araddr = 0;
  logic        awvalid = 0, wvalid = 0, wlast = 0, bready = 1;
  wire         awready, wready, bvalid, err_evt;
  wire  [1:0]  bresp;

  m_usb2_axs #(.PARA_USB2_NUM_DMA_CH(NCH), .PARA_USB2_NEP1(NEP1)) dut (
    .i_clk_bus(clk), .i_rst_n_bus(rst_n), .i_core_en(1'b1), .i_win_en(1'b1), .i_req_thr(8'd1),
    .i_fifo_hnp(32'd0), .i_fifo_hpt(32'd0), .i_epi_ctrl(epi_ctrl), .i_epi_fifo(epi_fifo), .i_dmach_map(dmach_map),
    .o_err_evt(err_evt), .o_dma_req(), .i_dma_ack(dma_ack),
    .o_rq_vld(), .o_rq_op(), .o_rq_q(), .o_rq_data(), .i_rq_rdy(1'b1), .i_rs_vld(1'b0), .i_rs_data(32'd0), .o_rs_pop(),
    .i_ev_vld(1'b0), .i_ev_type(2'd0), .i_ev_q(5'd0), .i_ev_val(17'd0), .o_ev_pop(),
    .i_axis_awid(4'd0), .i_axis_awaddr(awaddr), .i_axis_awlen(8'd0), .i_axis_awsize(3'd2), .i_axis_awburst(2'b01),
    .i_axis_awvalid(awvalid), .o_axis_awready(awready), .i_axis_wdata(32'd0), .i_axis_wstrb(4'hF), .i_axis_wlast(wlast),
    .i_axis_wvalid(wvalid), .o_axis_wready(wready), .o_axis_bid(), .o_axis_bresp(bresp), .o_axis_bvalid(bvalid), .i_axis_bready(bready),
    .i_axis_arid(4'd0), .i_axis_araddr(araddr), .i_axis_arlen(8'd0), .i_axis_arsize(3'd2), .i_axis_arburst(2'b01),
    .i_axis_arvalid(1'b0), .o_axis_arready(), .o_axis_rid(), .o_axis_rdata(), .o_axis_rresp(), .o_axis_rlast(), .o_axis_rvalid(),
    .i_axis_rready(1'b1));

  int errors = 0;
  int n_evt = 0;
  always @(posedge clk) if (err_evt) n_evt++;

  // One single-beat write to the window of channel ch. Returns after the address phase and two cycles; the accepted case waits for a
  // credit grant (no credit is supplied), so the response is not awaited: the decision is read from the error flag of the burst,
  // which is also what drives SLVERR for a refused access.
  task automatic aw(input int ch, output bit refused);
    n_evt = 0;
    @(negedge clk); awaddr = ch << 12; awvalid = 1;
    @(negedge clk); awvalid = 0;
    repeat (3) @(negedge clk);
    refused = (dut.reg_w_err === 1'b1);
    // finish a refused burst so that the channel returns to idle: one data beat, then the response
    if (refused) begin
      wvalid = 1; wlast = 1; @(negedge clk); wvalid = 0; wlast = 0;
      repeat (3) @(negedge clk);
    end
  endtask

  task automatic do_reset;
    rst_n = 0; repeat (3) @(negedge clk); rst_n = 1; @(negedge clk);
  endtask

  initial begin
    bit ref0, refl, refx;
    for (int c = 0; c < NCH; c++) dmach_map[c] = 32'h0000_0060 | (c % 8);   // enable (bit 6), write direction (bit 5), region = endpoint (c % 8)
    do_reset();
    aw(0, ref0);                       // channel 0 is enabled: must be accepted for every NCH from 1 to 16
    $display("NUM_DMA_CH=%0d channel 0      : %s", NCH, ref0 ? "REFUSED (SLVERR)" : "accepted");
    if (ref0) errors++;
    do_reset();
    aw(NCH - 1, refl);                 // the last legal channel: must be accepted
    $display("NUM_DMA_CH=%0d channel %0d     : %s", NCH, NCH - 1, refl ? "REFUSED (SLVERR)" : "accepted");
    if (refl) errors++;
    if (NCH < 16) begin
      do_reset();
      aw(NCH, refx);                   // the first illegal channel: must be refused
      $display("NUM_DMA_CH=%0d channel %0d     : %s", NCH, NCH, refx ? "refused (correct)" : "ACCEPTED (wrong)");
      if (!refx) errors++;
    end
    if (errors == 0) $display("RESULT NCH=%0d: PASS", NCH);
    else             $display("RESULT NCH=%0d: FAIL (%0d wrong decisions)", NCH, errors);
    $finish;
  end
endmodule
