module tb_stub_sync #(parameter PARA_LEVELS = 2) (input logic i_clk_dst, input logic i_rst_n_dst, input logic i_d, output logic o_q);
  assign o_q = i_d;
endmodule
