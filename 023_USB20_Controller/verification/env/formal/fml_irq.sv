// Formal harness, property a_irq_level (REQ-IF-008). AI-generated candidate (R-117). o_int_usb is a level that is high
// while any enabled interrupt status bit is set, registered in CLK-BUS: the property allows one cycle of latency.
module fml_irq #(parameter int N = 25) (input logic clk, input logic rst_n, input logic [N-1:0] evt, raw, en, inj);
  logic [N-1:0] set, sts; logic irq;
  m_usb2_irq #(.PARA_USB2_IRQ_N(N)) dut (.i_clk_bus(clk), .i_rst_n_bus(rst_n), .i_evt(evt), .i_raw(raw), .i_en(en), .i_inj(inj),
                                         .o_set(set), .o_sts(sts), .o_int_usb(irq));
  logic act_d, act_d2, idle_d, idle_d2;
  wire  init;
  // Reset sequence fixed by the harness: reset low for two cycles, then high for the rest of the trace.
  logic [1:0] t;
  initial t = 2'd0;
  always @(posedge clk) begin if (t != 2'd3) t <= t + 2'd1; assume (rst_n == (t >= 2'd2)); end
  assign init = (t == 2'd3);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin act_d <= 1'b0; act_d2 <= 1'b0; idle_d <= 1'b0; idle_d2 <= 1'b0; end
    else begin
      act_d  <= |(raw & en);  act_d2  <= act_d & (|(raw & en));
      idle_d <= ~|(raw & en); idle_d2 <= idle_d & (~|(raw & en));
    end
  end
  always @(posedge clk) begin
    if (init && rst_n) begin
      a_irq_set:   assert (!(act_d2 && !irq));       // enabled status set for two cycles: output high
      a_irq_clear: assert (!(idle_d2 && irq));       // no enabled status for two cycles: output low
      a_irq_sts:   assert (sts == (raw & en));       // masked status
      c_irq_set:   cover (irq);
      c_irq_clear: cover (act_d2 && !(|(raw & en)));
    end
  end
endmodule
