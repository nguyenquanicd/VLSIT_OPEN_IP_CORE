// Formal harness, property a_rst_sync (REQ-RESET-001). AI-generated candidate (R-117). Scope: with test mode off and no
// soft reset, each domain reset output is low one cycle after its input is low and returns high within 4 cycles after
// the input has stayed high. Both clocks are tied to one clock here; the asynchronous assertion path of the library
// synchronizer cell is not provable in this single-clock model and stays a review item of REQ-CLK-002.
module fml_rst (input logic clk, input logic rst_n_phy, input logic rst_n_bus);
  logic o_phy, o_core, o_bus, o_phyrst, busy, clr;
  m_usb2_rst dut (.i_clk_phy(clk), .i_rst_n_phy(rst_n_phy), .i_clk_bus(clk), .i_rst_n_bus(rst_n_bus), .i_dft_test_en(1'b0),
                  .i_soft_req(1'b0), .i_phy_hold(1'b0), .o_soft_busy(busy), .o_soft_clr(clr), .o_rst_n_phy(o_phy),
                  .o_rst_n_core(o_core), .o_rst_n_bus(o_bus), .o_phy_rst_n(o_phyrst));
  logic [2:0] hb, hp; logic lb, lp; logic [1:0] t;
  initial begin t = 2'd0; hb = 3'd0; hp = 3'd0; lb = 1'b0; lp = 1'b0; end
  always @(posedge clk) begin
    if (t != 2'd3) t <= t + 2'd1;
    if (t < 2'd2) assume (!rst_n_bus && !rst_n_phy);
    hb <= !rst_n_bus ? 3'd0 : ((hb == 3'd7) ? hb : hb + 3'd1);
    hp <= !rst_n_phy ? 3'd0 : ((hp == 3'd7) ? hp : hp + 3'd1);
    lb <= !rst_n_bus; lp <= !rst_n_phy;
    if (t == 2'd3) begin
      // assertion is asynchronous: the output is low in the same step as the input (also one cycle later)
      a_rst_bus_low:  assert (!((lb || !rst_n_bus) && o_bus));
      a_rst_phy_low:  assert (!((lp || !rst_n_phy) && o_phy));
      a_rst_bus_rel:  assert (!((hb >= 3'd5) && rst_n_bus && !o_bus));
      a_rst_phy_rel:  assert (!((hp >= 3'd5) && rst_n_phy && !o_phy));
      a_rst_core_rel: assert (!((hp >= 3'd5) && (hb >= 3'd5) && rst_n_phy && rst_n_bus && !o_core));
      c_rst_release:  cover (o_bus && o_phy && o_core);
      c_rst_again:    cover (lb && (hp >= 3'd5));
    end
  end
endmodule
