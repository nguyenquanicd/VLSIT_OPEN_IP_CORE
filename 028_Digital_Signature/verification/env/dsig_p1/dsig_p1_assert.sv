// dsig_p1_assert.sv - assertions on the control block, the buffer and their interfaces to the CSR,
// written from the specification (section number or requirement ID in each name):
// section 10.1 (states), 10.2 (rules DEC-030 to DEC-035), 10.5 (buffer), 11.3 (CSR connection),
// 12 (errors), 6.4 (interrupts). The simulator has no concurrent assertions, so they are clocked
// checks sampled before the flip-flops update (guide section 3). i_mask bit n disables assertion n
// for the cycles of a test that breaks its premise on purpose (state corruption by force).
`timescale 1ns/1ps

module dsig_p1_assert #(
  parameter integer PARA_BUF_BYTES = 1024
) (
  input  wire        i_clk,
  input  wire        i_rstn,
  input  wire [3:0]  i_state,
  input  wire        i_busy,         // o_busy of the control block
  input  wire [4:0]  i_sts,          // {mlok, edok, sigok, resvld, busy}
  input  wire [2:0]  i_eng_start,
  input  wire        i_key_start,
  input  wire        i_rng_start,
  input  wire        i_vas_start,
  input  wire        i_zero_req,
  input  wire        i_zero_done,
  input  wire [11:0] i_err_set,
  input  wire [2:0]  i_alarm_set,
  input  wire [14:0] i_alg_act,
  input  wire        i_locked,
  input  wire [3:0]  i_run_alg,
  input  wire [1:0]  i_run_op,
  input  wire [31:0] i_cnt_ops,
  input  wire [31:0] i_cnt_fail,
  input  wire        i_log_locked,
  input  wire        i_irq,
  input  wire [2:0]  i_irq_sts,
  input  wire [2:0]  i_irq_raw,
  input  wire [2:0]  i_irq_en,
  input  wire        i_alarm,
  input  wire [2:0]  i_alarm_flags,
  input  wire        i_cmd_start,
  input  wire        i_cmd_start_clr,
  input  wire        i_cmd_clr_clr,
  input  wire        i_bus_wr_en,
  input  wire        i_bus_wr_rej,
  input  wire        i_bus_rd_en,
  input  wire        i_bus_rd_rej,
  input  wire        i_buf_err_ovf,
  input  wire        i_buf_err_busy,
  input  wire        i_bus_rd_valid,
  input  wire        i_reg_wr_en,
  input  wire        i_reg_rd_en,
  input  wire [16:0] i_win_addr,
  input  wire        i_win_addr_we,
  input  wire [16:0] i_win_addr_wdata,
  input  wire        i_eng_rd_en,
  input  wire        i_eng_rd_valid,
  input  wire [63:0] i_mask
);

  `include "tb_chk.svh"

  localparam [3:0] S_IDLE = 0, S_CHECK = 1, S_KEY = 2, S_RNG = 3, S_RUN = 4, S_VAS = 5,
                   S_RESULT = 6, S_CLEAR = 7, S_ERR = 8;

  reg [3:0]  r_state;
  reg        r_locked, r_log_locked, r_busy, r_bus_wr_en, r_bus_wr_rej, r_bus_rd_en;
  reg [14:0] r_alg_act;
  reg [31:0] r_cnt_ops, r_cnt_fail;
  reg [2:0]  r_eng_start;
  reg [4:0]  r_sts;
  reg        r_reg_wr_en, r_reg_rd_en, r_eng_rd_en, r_zero_done;
  reg        r_cmd_start;
  reg        r_cmd_clr_clr;
  reg        inflight;           // an engine run was started and has not ended
  integer    clr_cnt;            // clocks spent in ENUM_ST_CLEAR
  integer    eng_rd_pend;        // clocks since an engine read request without data
  integer    bus_rd_pend;
  reg        ok_trans;
  reg [11:0] r_err_set;

  initial begin
    r_state = 0; r_locked = 0; r_log_locked = 0; r_busy = 0; r_bus_wr_en = 0; r_bus_wr_rej = 0;
    r_bus_rd_en = 0; r_alg_act = 0; r_cnt_ops = 0; r_cnt_fail = 0; r_eng_start = 0; r_sts = 0;
    r_reg_wr_en = 0; r_reg_rd_en = 0; r_eng_rd_en = 0; r_zero_done = 0; r_cmd_start = 0;
    r_cmd_clr_clr = 0; r_err_set = 0; inflight = 0; clr_cnt = 0; eng_rd_pend = 0; bus_rd_pend = 0;
    as_reg(1,  "FSM-01 state transitions follow the table of section 10.1");
    as_reg(2,  "FSM-02 an unused encoding goes to ENUM_ST_CLEAR (DEC-035, 10.1)");
    as_reg(3,  "FSM-03 sts.busy is 0 in ENUM_ST_IDLE (10.1)");
    as_reg(4,  "FSM-04 sts.busy is 1 in ENUM_ST_RUN (10.1)");
    as_reg(5,  "REQ-REG-001 SVA-004 an engine starts only for an enabled algorithm");
    as_reg(6,  "SVA-001 at most one engine start per operation (one run at a time)");
    as_reg(7,  "SVA-002 engine start is one-hot (one engine owns the run)");
    as_reg(8,  "REQ-FUNC-009 engine start only while busy");
    as_reg(9,  "ERR-001 to ERR-006 a failing check sets one flag, not several (section 12)");
    as_reg(10, "ENUM_ST_KEY only for signing or key generation (10.1)");
    as_reg(11, "ENUM_ST_VAS only after signing (10.1)");
    as_reg(12, "DEC-031 random request only for signing or key generation");
    as_reg(13, "ENUM_ST_CLEAR requests the zeroization (10.1, OP-006)");
    as_reg(14, "REQ-SEC-005 PERF-003 ENUM_ST_CLEAR lasts at most 100 clocks");
    as_reg(15, "DEC-034 dsig_alg_act holds while locked");
    as_reg(16, "REQ-REG-002 the lock stays until reset");
    as_reg(17, "DEC-033 counters never decrease");
    as_reg(18, "DEC-033 REQ-SEC-006 counters stop after the log lock");
    as_reg(19, "6.4 o_irq is the OR of the masked events");
    as_reg(20, "6.4 irq_sts is the raw event masked by the enable");
    as_reg(21, "6.4 o_alarm high for fault or lock violation");
    as_reg(22, "6.4 o_alarm low when no alarm flag is set");
    as_reg(23, "ERR-011 lock violation sets the error and the alarm together");
    as_reg(24, "ERR-010 verify-after-sign mismatch sets the fault alarm");
    as_reg(25, "ERR-008 entropy timeout sets the random-source alarm");
    as_reg(26, "11.3 the start bit is cleared by hardware only while a start is pending");
    as_reg(27, "11.3 status bits are never X after reset");
    as_reg(28, "REQ-SEC-005 SVA-005 secrets are zero when ENUM_ST_CLEAR ends");
    as_reg(29, "10.5 REQ-IF-002 a bus write while busy is rejected");
    as_reg(30, "10.5 REQ-IF-002 a bus write while idle is accepted");
    as_reg(31, "10.5 the window address advances by 4 after a window access");
    as_reg(32, "10.5 the window address changes only after a window register access");
    as_reg(33, "10.5 engine read data valid within 4 clocks");
    as_reg(34, "10.5 bus read data valid within 4 clocks");
    as_reg(35, "REQ-RESET-001 outputs at reset: idle, not busy, no start, no interrupt, no buffer response");
    as_reg(36, "10.1 engine start is a one-cycle pulse");
    as_reg(37, "DEC-030 edok and mlok change only at a result or clear");
    as_reg(38, "REQ-FUNC-009 a failing check enters ENUM_ST_ERR with its flag set (10.1, 12)");
  end

  always @(posedge i_clk) begin
    if (i_rstn === 1'b1) begin
      // Legal transitions of the control FSM
      case (r_state)
        S_IDLE:   ok_trans = (i_state == S_IDLE) | (i_state == S_CHECK) | (i_state == S_CLEAR);
        S_CHECK:  ok_trans = (i_state == S_KEY) | (i_state == S_RNG) | (i_state == S_RUN) | (i_state == S_ERR);
        S_KEY:    ok_trans = (i_state == S_KEY) | (i_state == S_RNG) | (i_state == S_RUN) | (i_state == S_ERR) |
                             (i_state == S_CLEAR);
        S_RNG:    ok_trans = (i_state == S_RNG) | (i_state == S_RUN) | (i_state == S_ERR) | (i_state == S_CLEAR);
        S_RUN:    ok_trans = (i_state == S_RUN) | (i_state == S_VAS) | (i_state == S_RESULT) | (i_state == S_ERR) |
                             (i_state == S_CLEAR);
        S_VAS:    ok_trans = (i_state == S_VAS) | (i_state == S_RESULT) | (i_state == S_ERR) | (i_state == S_CLEAR);
        S_RESULT: ok_trans = (i_state == S_CLEAR);
        S_CLEAR:  ok_trans = (i_state == S_CLEAR) | (i_state == S_IDLE);
        S_ERR:    ok_trans = (i_state == S_CLEAR);
        default:  ok_trans = 1'b1;
      endcase
      as_chk(1,  (r_state <= S_ERR) & ~i_mask[1],                  ok_trans);
      as_chk(2,  (r_state > S_ERR) & ~i_mask[2],                   i_state == S_CLEAR);
      as_chk(3,  (i_state == S_IDLE) & ~i_mask[3],                 ~i_sts[0]);
      as_chk(4,  (i_state == S_RUN) & ~i_mask[4],                  i_sts[0]);
      as_chk(5,  (|i_eng_start) & ~i_mask[5],                      (i_run_alg <= 4'd14) & i_alg_act[i_run_alg]);
      as_chk(6,  (|i_eng_start) & ~i_mask[6],                      ~inflight);
      as_chk(7,  (|i_eng_start) & ~i_mask[7],                      (i_eng_start == 3'b001) | (i_eng_start == 3'b010) | (i_eng_start == 3'b100));
      as_chk(8,  (|i_eng_start) & ~i_mask[8],                      i_busy);
      as_chk(9,  (r_state == S_CHECK) & (i_state == S_ERR) & ((|i_err_set[5:0]) | (|r_err_set[5:0])) & ~i_mask[9],
                 (((i_err_set[5:0] | r_err_set[5:0]) & ((i_err_set[5:0] | r_err_set[5:0]) - 6'd1)) == 6'd0));
      as_chk(10, i_key_start & ~i_mask[10],                        (i_run_op == 2'd0) | (i_run_op == 2'd1));
      as_chk(11, i_vas_start & ~i_mask[11],                        i_run_op == 2'd1);
      as_chk(12, i_rng_start & ~i_mask[12],                        (i_run_op == 2'd0) | (i_run_op == 2'd1));
      as_chk(13, (i_state == S_CLEAR) & ~i_mask[13],               i_zero_req);
      as_chk(14, (i_state == S_CLEAR) & ~i_mask[14],               clr_cnt <= 100);
      as_chk(15, r_locked & i_locked & ~i_mask[15],                i_alg_act == r_alg_act);
      as_chk(16, r_locked & ~i_mask[16],                           i_locked);
      as_chk(17, ~i_mask[17],                                      (i_cnt_ops >= r_cnt_ops) & (i_cnt_fail >= r_cnt_fail));
      as_chk(18, r_log_locked & ~i_mask[18],                       (i_cnt_ops == r_cnt_ops) & (i_cnt_fail == r_cnt_fail));
      as_chk(19, ~i_mask[19],                                      i_irq == (|i_irq_sts));
      as_chk(20, ~i_mask[20],                                      i_irq_sts == (i_irq_raw & i_irq_en));
      as_chk(21, (i_alarm_flags[0] | i_alarm_flags[1]) & ~i_mask[21], i_alarm);
      as_chk(22, ~(|i_alarm_flags) & ~i_mask[22],                  ~i_alarm);
      as_chk(23, i_err_set[10] & ~i_mask[23],                      i_alarm_set[1]);
      as_chk(24, i_err_set[9] & ~i_mask[24],                       i_alarm_set[0]);
      as_chk(25, i_err_set[7] & ~i_mask[25],                       i_alarm_set[2]);
      as_chk(26, i_cmd_start_clr & ~i_mask[26],                    i_cmd_start | r_cmd_start);
      as_chk(27, ~i_mask[27],                                      ~(^i_sts === 1'bx));
      as_chk(28, (r_state == S_CLEAR) & (i_state == S_IDLE) & ~i_mask[28], r_zero_done);
      as_chk(29, r_bus_wr_en & r_busy & ~i_mask[29],               i_bus_wr_rej | r_bus_wr_rej);
      as_chk(30, r_bus_wr_en & ~r_busy & ~i_busy & ~i_mask[30],    ~(i_bus_wr_rej | r_bus_wr_rej));
      as_chk(31, i_win_addr_we & (i_win_addr < PARA_BUF_BYTES) & ~i_mask[31],
                 i_win_addr_wdata == (i_win_addr + 17'd4));
      as_chk(32, i_win_addr_we & ~i_mask[32],                      i_reg_wr_en | i_reg_rd_en | r_reg_wr_en | r_reg_rd_en);
      as_chk(33, (eng_rd_pend > 0) & ~i_mask[33],                  eng_rd_pend <= 4);
      as_chk(34, (bus_rd_pend > 0) & ~i_mask[34],                  bus_rd_pend <= 4);
      as_chk(36, (|r_eng_start) & ~i_mask[36],                     (i_eng_start & r_eng_start) == 3'b000);
      as_chk(37, ((i_sts[4:3] != r_sts[4:3])) & ~i_mask[37],       (r_state == S_RESULT) | r_cmd_clr_clr);
      as_chk(38, (r_state == S_CHECK) & (i_state == S_ERR) & ~i_mask[38], (|i_err_set) | (|r_err_set));
      // Bookkeeping
      if (|i_eng_start) inflight <= 1'b1;
      else if ((i_state == S_IDLE) | (i_state == S_CLEAR) | (i_state == S_RESULT) | (i_state == S_ERR) | (i_state == S_VAS))
        inflight <= 1'b0;
      if (i_state == S_CLEAR) clr_cnt <= clr_cnt + 1; else clr_cnt <= 0;
      if (i_eng_rd_en) eng_rd_pend <= 1;
      else if (eng_rd_pend > 0) begin
        if (i_eng_rd_valid) eng_rd_pend <= 0; else eng_rd_pend <= eng_rd_pend + 1;
      end
      if (i_bus_rd_en) bus_rd_pend <= 1;
      else if (bus_rd_pend > 0) begin
        if (i_bus_rd_valid) bus_rd_pend <= 0; else bus_rd_pend <= bus_rd_pend + 1;
      end
    end else begin
      // Reset asserted (the clock edge samples the asynchronous reset state)
      as_chk(35, ~i_mask[35], (i_state == S_IDLE) & ~i_busy & (i_eng_start == 3'b000) & ~i_irq & ~i_bus_wr_rej & ~i_bus_rd_rej &
                          ~i_bus_rd_valid & ~i_eng_rd_valid & ~i_buf_err_ovf & ~i_buf_err_busy);
      inflight <= 1'b0; clr_cnt <= 0; eng_rd_pend <= 0; bus_rd_pend <= 0;
    end
    r_state      <= i_state;
    r_locked     <= i_locked;
    r_log_locked <= i_log_locked;
    r_busy       <= i_busy;
    r_bus_wr_en  <= i_bus_wr_en;
    r_bus_wr_rej <= i_bus_wr_rej;
    r_bus_rd_en  <= i_bus_rd_en;
    r_alg_act    <= i_alg_act;
    r_cnt_ops    <= i_cnt_ops;
    r_cnt_fail   <= i_cnt_fail;
    r_eng_start  <= i_eng_start;
    r_sts        <= i_sts;
    r_reg_wr_en  <= i_reg_wr_en;
    r_reg_rd_en  <= i_reg_rd_en;
    r_eng_rd_en  <= i_eng_rd_en;
    r_zero_done  <= i_zero_done;
    r_cmd_start  <= i_cmd_start;
    r_cmd_clr_clr <= i_cmd_clr_clr;
    r_err_set    <= i_err_set;
  end

endmodule
