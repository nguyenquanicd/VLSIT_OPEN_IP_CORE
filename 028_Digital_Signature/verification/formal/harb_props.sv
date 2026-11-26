// harb_props.sv - formal properties of m_vlsit_dsig_harb (4 requesters, the configuration of the top), proven with SymbiYosys.
// Source of each property: the description of the arbiter in section 10.4 and the module header (one owner at a time, the grant
// stays with the owner until its request falls, then the next request in fixed priority order, registered grant, the stream
// signals of the owner only).
`timescale 1ns/1ps
module harb_props (
  input wire        clk,
  input wire [3:0]  req, job_start, in_valid, in_last, out_ready,
  input wire [63:0] in_data0, in_data1, in_data2, in_data3,
  input wire        s_in_ready, s_out_valid, s_out_last
);
  reg rst_n = 1'b0;
  always @(posedge clk) rst_n <= 1'b1;
  wire [3:0] grant, in_ready, out_valid, out_last; wire [255:0] out_data; wire [15:0] out_nb;
  wire o_job_start, o_in_valid, o_in_last, o_out_ready; wire [3:0] o_job_mode, o_in_nb; wire [15:0] o_job_outlen; wire [63:0] o_in_data;
  m_vlsit_dsig_harb #(.PARA_NREQ(4)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_req(req), .i_job_start(job_start), .i_job_mode(16'h4321), .i_job_outlen(64'd0),
    .i_in_valid(in_valid), .i_in_data({in_data3, in_data2, in_data1, in_data0}), .i_in_nb(16'h8888), .i_in_last(in_last),
    .i_out_ready(out_ready), .o_grant(grant), .o_in_ready(in_ready), .o_out_valid(out_valid), .o_out_data(out_data), .o_out_nb(out_nb),
    .o_out_last(out_last), .o_job_start(o_job_start), .o_job_mode(o_job_mode), .o_job_outlen(o_job_outlen), .o_in_valid(o_in_valid),
    .o_in_data(o_in_data), .o_in_nb(o_in_nb), .o_in_last(o_in_last), .i_in_ready(s_in_ready), .i_out_valid(s_out_valid),
    .i_out_data(64'hA5A5_5A5A_0F0F_F0F0), .i_out_nb(4'd8), .i_out_last(s_out_last), .o_out_ready(o_out_ready));

  wire [3:0] own = grant & req;
  function automatic [3:0] lowest(input [3:0] r);
    lowest = r[0] ? 4'b0001 : r[1] ? 4'b0010 : r[2] ? 4'b0100 : r[3] ? 4'b1000 : 4'b0000;
  endfunction
  reg [3:0] req_q, grant_q; reg past_ok = 1'b0;
  always @(posedge clk) begin req_q <= req; grant_q <= grant; past_ok <= rst_n; end

  always @(*) if (rst_n) begin
    // P1 one owner at most
    assert ((grant & (grant - 4'd1)) == 4'd0);
    // P6 the stream reaches the sequencer from the owner only, and the answers go to the owner only
    assert (o_in_valid == |(own & in_valid));
    assert (o_job_start == |(own & job_start));
    assert ((in_ready & ~own) == 4'd0);
    assert ((out_valid & ~own) == 4'd0);
    assert (o_job_mode == (own[0] ? 4'h1 : own[1] ? 4'h2 : own[2] ? 4'h3 : own[3] ? 4'h4 : 4'h0));
    assert (o_in_data == (own[0] ? in_data0 : own[1] ? in_data1 : own[2] ? in_data2 : own[3] ? in_data3 : 64'd0));
  end
  always @(posedge clk) if (past_ok && rst_n) begin
    // P2 a grant goes only to a requester of the previous cycle (registered grant)
    assert ((grant & ~req_q) == 4'd0);
    // P3 the owner keeps the grant while its request stays high
    if (|(grant_q & req_q)) assert (grant == grant_q);
    // P4 + P5 without an owner, the grant goes to the requester of highest priority (lowest index) of the previous cycle
    if (!(|(grant_q & req_q))) assert (grant == lowest(req_q));
  end
endmodule
