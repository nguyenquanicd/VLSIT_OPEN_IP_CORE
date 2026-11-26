/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-26
 * Description  : UTMI+ wake detector in CLK-BUS (REQ-IF-015, DEC-049, CDC-008, closes FND-015).
 *                It is always on, because a UTMI+ PHY may stop CLK-PHY while SuspendM is low
 *                and restarts it only after SuspendM is negated (UTMI 1.05 p. 21 and p. 48).
 *                While the speed engine requests suspend (i_suspend_n_phy = 0), the detector
 *                waits until LineState is a stable non-SE0 value for LPARA_UTMILP_SETTLE cycles
 *                and stores it as the idle value (J of the port speed; SE0 is never stored, so
 *                the SE0 that a high-speed device shows while it reverts to full-speed is not
 *                taken for idle). A line that differs from the idle value for LPARA_UTMILP_FLT
 *                cycles (resume K, reset SE0, remote-wake K, disconnect SE0) or a software wake
 *                request (one per suspend period, as DEC-022) sets o_wake, which the UTMI+
 *                adapter ORs into o_utmi_suspend_n. o_wake is cleared when the synchronized
 *                engine request is 1 again (hand-off: the engine has left suspend), or, after a
 *                line wake, when the line has been back at the idle value for LPARA_UTMILP_FLT
 *                cycles while the engine stayed suspended (spurious wake: SuspendM falls again).
 *                Both inputs cross through the library synchronizer; the source of
 *                i_suspend_n_phy is the flop reg_suspend_n of m_usb2_spd (BUG-045 rule).
 */
`timescale 1ns/1ps

module m_usb2_utmilp #(
  localparam logic [31:0] LPARA_LS_W          = 2,
  localparam logic [31:0] LPARA_LS_RV         = 1,
  localparam logic [31:0] LPARA_SUSP_W        = 1,
  localparam logic [31:0] LPARA_SUSP_RV       = 1,
  localparam logic [31:0] LPARA_CELL_2FF      = 2,
  localparam logic [31:0] LPARA_UTMILP_FLT    = 4,
  localparam logic [31:0] LPARA_UTMILP_SETTLE = 4,
  localparam logic [31:0] LPARA_CNT_W         = 3
) (
  // Clock and reset of the always-on logic
  input  wire        i_clk_bus,
  input  wire        i_rst_n_bus,

  // Asynchronous UTMI+ line state (the PHY may have stopped CLK-PHY)
  input  wire  [1:0] i_utmi_linestate,

  // Suspend request of the speed engine (CLK-PHY flop) and software wake request (CLK-BUS)
  input  wire        i_suspend_n_phy,
  input  wire        i_wake_req,

  // Wake request, ORed into o_utmi_suspend_n
  output logic       o_wake
);

  // Internal signal declarations
  logic [1:0]             w_ls_sync;
  logic                   w_susp_n_sync;
  logic [1:0]             reg_ls_prev;
  logic [1:0]             reg_idle;
  logic [LPARA_CNT_W-1:0] reg_cnt;
  logic                   reg_armed;
  logic                   reg_wake;
  logic                   reg_wake_line;
  logic                   reg_woke;
  logic [1:0]             w_idle_nxt;
  logic [LPARA_CNT_W-1:0] w_cnt_nxt;
  logic                   w_armed_nxt;
  logic                   w_wake_nxt;
  logic                   w_line_nxt;
  logic                   w_woke_nxt;
  logic                   w_settle_end;
  logic                   w_flt_end;

  // Library synchronizers of the asynchronous line state and of the engine suspend request.
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (LPARA_LS_W),
    .PARA_AFIFO_SYNC_RST_VAL (LPARA_LS_RV),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_ls (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (i_rst_n_bus),
    .i_data      (i_utmi_linestate),
    .o_data      (w_ls_sync)
  );

  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (LPARA_SUSP_W),
    .PARA_AFIFO_SYNC_RST_VAL (LPARA_SUSP_RV),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_susp (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (i_rst_n_bus),
    .i_data      (i_suspend_n_phy),
    .o_data      (w_susp_n_sync)
  );

  // Ends of the settle and filter counts.
  assign w_settle_end = (reg_cnt == LPARA_CNT_W'(LPARA_UTMILP_SETTLE - 1));
  assign w_flt_end    = (reg_cnt == LPARA_CNT_W'(LPARA_UTMILP_FLT - 1));
  assign o_wake       = reg_wake;

  // Arm, line wake, spurious-wake release and hand-off; the software wake has priority.
  always_comb begin : p_com_wake
    w_idle_nxt  = reg_idle;
    w_cnt_nxt   = reg_cnt;
    w_armed_nxt = reg_armed;
    w_wake_nxt  = reg_wake;
    w_line_nxt  = reg_wake_line;
    w_woke_nxt  = reg_woke;
    casez ({w_susp_n_sync, reg_armed, reg_wake, reg_wake_line})
      // Engine not suspended (also the hand-off): everything idle.
      4'b1???: begin
        w_cnt_nxt   = '0;
        w_armed_nxt = 1'b0;
        w_wake_nxt  = 1'b0;
        w_line_nxt  = 1'b0;
        w_woke_nxt  = 1'b0;
      end
      // Settle: a stable non-SE0 line becomes the idle value.
      4'b00??: begin
        casez ({((w_ls_sync == 2'b00) | (w_ls_sync != reg_ls_prev)), w_settle_end})
          2'b1?: w_cnt_nxt = '0;
          2'b01: begin
            w_armed_nxt = 1'b1;
            w_idle_nxt  = w_ls_sync;
            w_cnt_nxt   = '0;
          end
          default: w_cnt_nxt = reg_cnt + LPARA_CNT_W'(1);
        endcase
      end
      // Armed: a line away from idle for the filter time wakes the PHY.
      4'b010?: begin
        casez ({(w_ls_sync == reg_idle), w_flt_end})
          2'b1?: w_cnt_nxt = '0;
          2'b01: begin
            w_wake_nxt = 1'b1;
            w_line_nxt = 1'b1;
            w_cnt_nxt  = '0;
          end
          default: w_cnt_nxt = reg_cnt + LPARA_CNT_W'(1);
        endcase
      end
      // Line wake while the engine is still suspended: release after the filter time at idle.
      4'b0111: begin
        casez ({(w_ls_sync != reg_idle), w_flt_end})
          2'b1?: w_cnt_nxt = '0;
          2'b01: begin
            w_wake_nxt = 1'b0;
            w_line_nxt = 1'b0;
            w_cnt_nxt  = '0;
          end
          default: w_cnt_nxt = reg_cnt + LPARA_CNT_W'(1);
        endcase
      end
      // Software wake: held until the hand-off.
      default: w_cnt_nxt = '0;
    endcase
    if (~w_susp_n_sync & ~reg_wake & i_wake_req & ~reg_woke) begin
      w_wake_nxt = 1'b1;
      w_line_nxt = 1'b0;
      w_woke_nxt = 1'b1;
      w_cnt_nxt  = '0;
    end
  end

  // State flops of the wake detector.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_wake
    if (!i_rst_n_bus) begin
      reg_ls_prev   <= 2'b01;
      reg_idle      <= 2'b01;
      reg_cnt       <= '0;
      reg_armed     <= 1'b0;
      reg_wake      <= 1'b0;
      reg_wake_line <= 1'b0;
      reg_woke      <= 1'b0;
    end else begin
      reg_ls_prev   <= w_ls_sync;
      reg_idle      <= w_idle_nxt;
      reg_cnt       <= w_cnt_nxt;
      reg_armed     <= w_armed_nxt;
      reg_wake      <= w_wake_nxt;
      reg_wake_line <= w_line_nxt;
      reg_woke      <= w_woke_nxt;
    end
  end

endmodule
