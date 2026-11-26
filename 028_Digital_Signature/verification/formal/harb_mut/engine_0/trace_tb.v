`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [3:0] PI_job_start;
  reg [63:0] PI_in_data1;
  wire [0:0] PI_clk = clock;
  reg [63:0] PI_in_data0;
  reg [63:0] PI_in_data3;
  reg [63:0] PI_in_data2;
  reg [3:0] PI_in_last;
  reg [3:0] PI_out_ready;
  reg [3:0] PI_in_valid;
  reg [0:0] PI_s_out_valid;
  reg [0:0] PI_s_out_last;
  reg [3:0] PI_req;
  reg [0:0] PI_s_in_ready;
  harb_props UUT (
    .job_start(PI_job_start),
    .in_data1(PI_in_data1),
    .clk(PI_clk),
    .in_data0(PI_in_data0),
    .in_data3(PI_in_data3),
    .in_data2(PI_in_data2),
    .in_last(PI_in_last),
    .out_ready(PI_out_ready),
    .in_valid(PI_in_valid),
    .s_out_valid(PI_s_out_valid),
    .s_out_last(PI_s_out_last),
    .req(PI_req),
    .s_in_ready(PI_s_in_ready)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$490  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$496  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$502  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$494  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$500  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$506  = 1'b1;
    UUT.dut._witness_.anyinit_procdff_462 = 4'b0000;
    UUT.grant_q = 4'b1000;
    UUT.past_ok = 1'b0;
    UUT.req_q = 4'b0000;
    UUT.rst_n = 1'b0;

    // state 0
    PI_job_start = 4'b0000;
    PI_in_data1 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_in_data0 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_in_data3 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_in_data2 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_in_last = 4'b0000;
    PI_out_ready = 4'b0000;
    PI_in_valid = 4'b0000;
    PI_s_out_valid = 1'b0;
    PI_s_out_last = 1'b0;
    PI_req = 4'b0000;
    PI_s_in_ready = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_job_start <= 4'b0000;
      PI_in_data1 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data0 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data3 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data2 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_last <= 4'b0000;
      PI_out_ready <= 4'b0000;
      PI_in_valid <= 4'b0000;
      PI_s_out_valid <= 1'b0;
      PI_s_out_last <= 1'b0;
      PI_req <= 4'b1000;
      PI_s_in_ready <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_job_start <= 4'b0000;
      PI_in_data1 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data0 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data3 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data2 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_last <= 4'b0000;
      PI_out_ready <= 4'b0000;
      PI_in_valid <= 4'b0000;
      PI_s_out_valid <= 1'b0;
      PI_s_out_last <= 1'b0;
      PI_req <= 4'b1111;
      PI_s_in_ready <= 1'b0;
    end

    // state 3
    if (cycle == 2) begin
      PI_job_start <= 4'b0000;
      PI_in_data1 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data0 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data3 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data2 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_last <= 4'b0000;
      PI_out_ready <= 4'b0000;
      PI_in_valid <= 4'b0000;
      PI_s_out_valid <= 1'b0;
      PI_s_out_last <= 1'b0;
      PI_req <= 4'b1000;
      PI_s_in_ready <= 1'b0;
    end

    // state 4
    if (cycle == 3) begin
      PI_job_start <= 4'b0000;
      PI_in_data1 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data0 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_data3 <= 64'b1111111111111111111111111111111111111111111111111111111111111111;
      PI_in_data2 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_in_last <= 4'b0000;
      PI_out_ready <= 4'b0000;
      PI_in_valid <= 4'b0000;
      PI_s_out_valid <= 1'b0;
      PI_s_out_last <= 1'b0;
      PI_req <= 4'b1000;
      PI_s_in_ready <= 1'b0;
    end

    genclock <= cycle < 4;
    cycle <= cycle + 1;
  end
endmodule
