/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : ULPI link-side adapter, 8-bit SDR (section 6.3, FEAT-003, REQ-IF-003, DEC-003).
 *                Receive: RX CMD decoding (line state, VBUS state, RxActive, RxError, host
 *                disconnect, ID) and USB data bytes (dir with nxt). Transmit: TX CMD with the
 *                PID from the first stream byte, payload bytes accepted on nxt, stp after the
 *                last byte. Register access: the function control register 0x04 and the OTG
 *                control register 0x0A follow the mode inputs (DrvVbusExternal from
 *                u2_hport.ext_vbus); u2_phy_acc reads or writes a register (immediate or
 *                extended address). Register operations start only when
 *                the link is idle and the bus is free, and retry after an abort by a USB
 *                receive. o_lp_active tells the always-on logic that SuspendM was written to 0;
 *                o_ulpi_stp ORs the low-power stp.
 */
`timescale 1ns/1ps

module m_usb2_phyif_ulpi #(
  // Parameter Description: cycles to wait for dir after a register read command before retry.
  // Parameter values: 4 to 15; default is 8.
  // Parameter unit: cycle
  parameter logic [31:0] PARA_USB2_ULPI_RD_TMO = 8,
  localparam logic [31:0] LPARA_CNT_W      = 4,
  localparam logic [31:0] LPARA_TXCMD_PID  = 32'h00000040,
  localparam logic [31:0] LPARA_RDCMD      = 32'h000000C0,
  localparam logic [31:0] LPARA_WRCMD      = 32'h00000080,
  localparam logic [31:0] LPARA_EXT_RD     = 32'h000000EF,
  localparam logic [31:0] LPARA_EXT_WR     = 32'h000000AF,
  localparam logic [31:0] LPARA_IMM_MAX    = 32'h0000003F,
  localparam logic [31:0] LPARA_FC_ADDR    = 32'h00000004,
  localparam logic [31:0] LPARA_OTG_ADDR   = 32'h0000000A,
  localparam logic [31:0] LPARA_INIT_8     = 32'h000000FF,
  localparam logic [31:0] LPARA_SRC_FC     = 32'd0,
  localparam logic [31:0] LPARA_SRC_OTG    = 32'd1,
  localparam logic [31:0] LPARA_SRC_USER   = 32'd2
) (
  // Clock and reset
  input  wire         i_clk_phy,
  input  wire         i_rst_n_phy,

  // ULPI pins
  input  wire         i_ulpi_dir,
  input  wire         i_ulpi_nxt,
  input  wire  [7:0]  i_ulpi_data,
  output logic        o_ulpi_stp,
  output logic [7:0]  o_ulpi_data,
  output logic        o_ulpi_data_oe,

  // Low power coupling with the always-on logic
  input  wire         i_stp_lp,
  output logic        o_lp_active,

  // Link transmit stream
  input  wire  [15:0] i_tx_data,
  input  wire  [1:0]  i_tx_valid,
  output logic        o_tx_ready,
  output logic        o_tx_abort,
  input  wire         i_link_idle,

  // Link receive stream and line state
  output logic [15:0] o_rx_data,
  output logic [1:0]  o_rx_valid,
  output logic        o_rx_active,
  output logic        o_rx_err,
  output logic [1:0]  o_linestate,

  // Mode controls from the speed engine
  input  wire  [1:0]  i_xcvr_sel,
  input  wire         i_term_sel,
  input  wire  [1:0]  i_op_mode,
  input  wire         i_suspend_n,
  input  wire         i_dp_pd,
  input  wire         i_dm_pd,
  input  wire         i_drv_vbus,
  input  wire         i_ext_vbus,
  input  wire         i_chrg_vbus,
  input  wire         i_dischrg_vbus,
  input  wire         i_id_pullup,

  // Status to the speed engine
  output logic        o_hostdisc,
  output logic        o_iddig,
  output logic        o_avalid,
  output logic        o_bvalid,
  output logic        o_vbusvalid,
  output logic        o_sessend,

  // PHY register access of u2_phy_acc
  input  wire         i_reg_start,
  input  wire         i_reg_wr,
  input  wire  [7:0]  i_reg_addr,
  input  wire  [7:0]  i_reg_wdata,
  output logic        o_reg_busy,
  output logic        o_reg_done,
  output logic [7:0]  o_reg_rdata
);

  // FSM states of the transmit and register-operation sequencer.
  typedef enum logic [3:0] {
    ENUM_ST_IDLE   = 4'd0,
    ENUM_ST_TXCMD  = 4'd1,
    ENUM_ST_TXDATA = 4'd2,
    ENUM_ST_STP    = 4'd3,
    ENUM_ST_RCMD   = 4'd4,
    ENUM_ST_RADDR  = 4'd5,
    ENUM_ST_RWDATA = 4'd6,
    ENUM_ST_RRD1   = 4'd7,
    ENUM_ST_RRD2   = 4'd8
  } ulpi_state_type_def;

  // Internal signal declarations
  ulpi_state_type_def      reg_fsm_ulpi_current_state;
  ulpi_state_type_def      w_fsm_ulpi_nxt_state;
  logic                    reg_dir_d;
  logic [7:0]              reg_data;
  logic                    reg_oe;
  logic                    reg_stp;
  logic [7:0]              w_data_nxt;
  logic                    w_stp_nxt;
  logic                    w_tx_ready;
  logic                    w_abort;
  logic [7:0]              w_fc_want;
  logic [7:0]              w_otg_want;
  logic [7:0]              reg_fc_wr;
  logic [7:0]              reg_otg_wr;
  logic                    w_fc_pend;
  logic                    w_otg_pend;
  logic                    w_mode_pend;
  logic                    w_tx_go;
  logic                    reg_user_pend;
  logic                    reg_user_wr;
  logic [7:0]              reg_user_addr;
  logic [7:0]              reg_user_wdata;
  logic [7:0]              reg_op_addr;
  logic [7:0]              reg_op_wdata;
  logic                    reg_op_wr;
  logic [1:0]              reg_op_src;
  logic                    w_op_start;
  logic [1:0]              w_op_src_nxt;
  logic [7:0]              w_op_addr_nxt;
  logic [7:0]              w_op_wdata_nxt;
  logic                    w_op_wr_nxt;
  logic                    w_op_ext;
  logic                    w_op_done;
  logic [LPARA_CNT_W-1:0]  reg_tmo;
  logic [7:0]              reg_rdata;
  logic                    reg_done;
  logic                    reg_rx_active;
  logic                    reg_rx_err;
  logic                    reg_rx_dv;
  logic [7:0]              reg_rx_d;
  logic [1:0]              reg_linestate;
  logic [1:0]              reg_vbus_state;
  logic                    reg_hostdisc;
  logic                    reg_iddig;
  logic                    w_rx_start;
  logic                    w_rx_cmd;
  logic                    w_rx_byte;
  logic                    w_rx_end;

  // Wanted register values from the mode inputs (function control and OTG control registers).
  assign w_fc_want  = {1'b0, i_suspend_n, 1'b0, i_op_mode, i_term_sel, i_xcvr_sel};
  // OTG Control: DrvVbusExternal (bit 6) follows DrvVbus when u2_hport.ext_vbus is 1, so a PHY
  // that switches VBUS through its own enable pin (CPEN of TUSB1210) drives it (DEC-048 PHY-06);
  // UseExternalVbusIndicator (bit 7) stays 0: the PHY takes VBUS valid from its own comparator.
  assign w_otg_want = {1'b0, i_drv_vbus & i_ext_vbus, i_drv_vbus, i_chrg_vbus, i_dischrg_vbus, i_dm_pd, i_dp_pd, i_id_pullup};
  assign w_fc_pend  = (w_fc_want != reg_fc_wr);
  assign w_otg_pend = (w_otg_want != reg_otg_wr);

  // Operation start: only from IDLE, with a free bus and an idle link; mode registers go first.
  // A transmit starts only when the PHY registers already show the mode inputs, so a chirp or a
  // test stream never leaves with the old OpMode (BUG-027); a pending mode write goes first even
  // when a stream is waiting.
  assign w_mode_pend = w_fc_pend | w_otg_pend;
  assign w_tx_go    = i_tx_valid[0] & ~i_ulpi_dir & ~reg_dir_d & ~w_mode_pend;
  assign w_op_start = (reg_fsm_ulpi_current_state == ENUM_ST_IDLE) & ~i_ulpi_dir & ~reg_dir_d &
                      (~i_tx_valid[0] | w_mode_pend) & i_link_idle &
                      (w_mode_pend | reg_user_pend);
  // Extended register address: addresses above 0x3F need the extended command.
  assign w_op_ext   = (reg_op_addr > LPARA_IMM_MAX[7:0]);

  // Selection of the next operation by priority.
  always_comb begin : p_com_op_sel
    w_op_src_nxt   = LPARA_SRC_USER[1:0];
    w_op_addr_nxt  = reg_user_addr;
    w_op_wdata_nxt = reg_user_wdata;
    w_op_wr_nxt    = reg_user_wr;
    if (w_fc_pend) begin
      w_op_src_nxt   = LPARA_SRC_FC[1:0];
      w_op_addr_nxt  = LPARA_FC_ADDR[7:0];
      w_op_wdata_nxt = w_fc_want;
      w_op_wr_nxt    = 1'b1;
    end else if (w_otg_pend) begin
      w_op_src_nxt   = LPARA_SRC_OTG[1:0];
      w_op_addr_nxt  = LPARA_OTG_ADDR[7:0];
      w_op_wdata_nxt = w_otg_want;
      w_op_wr_nxt    = 1'b1;
    end
  end

  // Receive decode: start of a USB receive (dir and nxt rise together), RX CMD byte, data byte.
  assign w_rx_start = i_ulpi_dir & ~reg_dir_d & i_ulpi_nxt;
  assign w_rx_cmd   = i_ulpi_dir & reg_dir_d & ~i_ulpi_nxt & (reg_fsm_ulpi_current_state != ENUM_ST_RRD2);
  assign w_rx_byte  = i_ulpi_dir & reg_dir_d & i_ulpi_nxt & reg_rx_active;
  assign w_rx_end   = ~i_ulpi_dir & reg_dir_d;

  // Part 1, sequential: the current state of the sequencer.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_fsm_ulpi
    if (!i_rst_n_phy)
      reg_fsm_ulpi_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_ulpi_current_state <= w_fsm_ulpi_nxt_state;
  end

  // Part 2, combinational: the next state. A direction change to the PHY aborts a transmit or a
  // register operation; a register operation is retried because its request stays pending.
  always_comb begin : p_com_fsm_nxt
    w_fsm_ulpi_nxt_state = reg_fsm_ulpi_current_state;
    case (reg_fsm_ulpi_current_state)
      ENUM_ST_IDLE: begin
        if (w_tx_go)
          w_fsm_ulpi_nxt_state = ENUM_ST_TXCMD;
        else if (w_op_start)
          w_fsm_ulpi_nxt_state = ENUM_ST_RCMD;
      end
      ENUM_ST_TXCMD: begin
        if (i_ulpi_dir)
          w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
        else if (i_ulpi_nxt)
          w_fsm_ulpi_nxt_state = i_tx_valid[0] ? ENUM_ST_TXDATA : ENUM_ST_STP;
      end
      ENUM_ST_TXDATA: begin
        if (i_ulpi_dir)
          w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
        else if (i_ulpi_nxt & ~i_tx_valid[0])
          w_fsm_ulpi_nxt_state = ENUM_ST_STP;
      end
      ENUM_ST_STP:   w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
      ENUM_ST_RCMD: begin
        if (i_ulpi_dir)
          w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
        else if (i_ulpi_nxt)
          w_fsm_ulpi_nxt_state = w_op_ext ? ENUM_ST_RADDR :
                                 (reg_op_wr ? ENUM_ST_RWDATA : ENUM_ST_RRD1);
      end
      ENUM_ST_RADDR: begin
        if (i_ulpi_dir)
          w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
        else if (i_ulpi_nxt)
          w_fsm_ulpi_nxt_state = reg_op_wr ? ENUM_ST_RWDATA : ENUM_ST_RRD1;
      end
      ENUM_ST_RWDATA: begin
        if (i_ulpi_dir)
          w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
        else if (i_ulpi_nxt)
          w_fsm_ulpi_nxt_state = ENUM_ST_STP;
      end
      ENUM_ST_RRD1: begin
        if (i_ulpi_dir & ~reg_dir_d & ~i_ulpi_nxt)
          w_fsm_ulpi_nxt_state = ENUM_ST_RRD2;
        else if (i_ulpi_nxt | (reg_tmo == '0))
          w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_RRD2:  w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
      default:       w_fsm_ulpi_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Part 3, combinational: the data bus value, the stp (set in the cycle after the last byte was
  // accepted), the stream handshake and the end of a register operation. The read data is valid
  // in RRD2 (dir high, nxt low).
  always_comb begin : p_com_fsm_out
    w_data_nxt  = 8'h00;
    w_stp_nxt   = 1'b0;
    w_tx_ready  = 1'b0;
    w_abort     = 1'b0;
    w_op_done   = 1'b0;
    case (reg_fsm_ulpi_current_state)
      ENUM_ST_IDLE: begin
        if (w_tx_go) begin
          w_data_nxt = LPARA_TXCMD_PID[7:0] | {4'h0, i_tx_data[3:0]};
          w_tx_ready = 1'b1;
        end else if (w_op_start) begin
          w_data_nxt = (w_op_addr_nxt > LPARA_IMM_MAX[7:0]) ?
                       (w_op_wr_nxt ? LPARA_EXT_WR[7:0] : LPARA_EXT_RD[7:0]) :
                       ((w_op_wr_nxt ? LPARA_WRCMD[7:0] : LPARA_RDCMD[7:0]) | w_op_addr_nxt);
        end
      end
      ENUM_ST_TXCMD: begin
        w_data_nxt = reg_data;
        casez ({i_ulpi_dir, i_ulpi_nxt, i_tx_valid[0]})
          3'b1??: begin
            w_abort    = 1'b1;
            w_data_nxt = 8'h00;
          end
          3'b011: begin
            w_data_nxt = i_tx_data[7:0];
            w_tx_ready = 1'b1;
          end
          3'b010: begin
            w_data_nxt = 8'h00;
            w_stp_nxt  = 1'b1;
          end
          default: w_data_nxt = reg_data;
        endcase
      end
      ENUM_ST_TXDATA: begin
        w_data_nxt = reg_data;
        casez ({i_ulpi_dir, i_ulpi_nxt, i_tx_valid[0]})
          3'b1??: begin
            w_abort    = 1'b1;
            w_data_nxt = 8'h00;
          end
          3'b011: begin
            w_data_nxt = i_tx_data[7:0];
            w_tx_ready = 1'b1;
          end
          3'b010: begin
            w_data_nxt = 8'h00;
            w_stp_nxt  = 1'b1;
          end
          default: w_data_nxt = reg_data;
        endcase
      end
      ENUM_ST_STP: begin
        // The stp flop is already 1 in this cycle; it is cleared on the next edge.
        w_data_nxt = 8'h00;
      end
      ENUM_ST_RCMD: begin
        w_data_nxt = reg_data;
        if (i_ulpi_dir)
          w_data_nxt = 8'h00;
        else if (i_ulpi_nxt)
          w_data_nxt = w_op_ext ? reg_op_addr : (reg_op_wr ? reg_op_wdata : 8'h00);
      end
      ENUM_ST_RADDR: begin
        w_data_nxt = reg_data;
        if (i_ulpi_dir)
          w_data_nxt = 8'h00;
        else if (i_ulpi_nxt)
          w_data_nxt = reg_op_wr ? reg_op_wdata : 8'h00;
      end
      ENUM_ST_RWDATA: begin
        w_data_nxt = reg_data;
        if (i_ulpi_dir)
          w_data_nxt = 8'h00;
        else if (i_ulpi_nxt) begin
          w_data_nxt = 8'h00;
          w_stp_nxt  = 1'b1;
          w_op_done  = 1'b1;
        end
      end
      ENUM_ST_RRD2: begin
        w_op_done = 1'b1;
      end
      default: begin
        w_data_nxt = 8'h00;
      end
    endcase
  end

  // Output and datapath flops: bus value, output enable, stp, previous dir and operation fields.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_bus
    if (!i_rst_n_phy) begin
      reg_dir_d <= 1'b0;
      reg_data  <= 8'h00;
      reg_oe    <= 1'b0;
      reg_stp   <= 1'b0;
    end else begin
      reg_dir_d <= i_ulpi_dir;
      reg_data  <= w_data_nxt;
      reg_oe    <= ~i_ulpi_dir;
      reg_stp   <= w_stp_nxt;
    end
  end

  // Register operation fields: latched at the start and kept for the retry after an abort.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_op
    if (!i_rst_n_phy) begin
      reg_op_addr  <= 8'h00;
      reg_op_wdata <= 8'h00;
      reg_op_wr    <= 1'b0;
      reg_op_src   <= LPARA_SRC_FC[1:0];
      reg_tmo      <= '0;
    end else begin
      if (w_op_start) begin
        reg_op_addr  <= w_op_addr_nxt;
        reg_op_wdata <= w_op_wdata_nxt;
        reg_op_wr    <= w_op_wr_nxt;
        reg_op_src   <= w_op_src_nxt;
      end
      if (reg_fsm_ulpi_current_state != ENUM_ST_RRD1)
        reg_tmo <= PARA_USB2_ULPI_RD_TMO[LPARA_CNT_W-1:0];
      else
        reg_tmo <= reg_tmo - 4'd1;
    end
  end

  // Completion of the register operation: the written mode value is remembered, the user request
  // is cleared and the read data is captured. A user request is taken from the CSR strobe.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_done
    if (!i_rst_n_phy) begin
      reg_fc_wr      <= LPARA_INIT_8[7:0];
      reg_otg_wr     <= LPARA_INIT_8[7:0];
      reg_user_pend  <= 1'b0;
      reg_user_wr    <= 1'b0;
      reg_user_addr  <= 8'h00;
      reg_user_wdata <= 8'h00;
      reg_rdata      <= 8'h00;
      reg_done       <= 1'b0;
    end else begin
      reg_done <= 1'b0;
      if (i_reg_start & ~reg_user_pend) begin
        reg_user_pend  <= 1'b1;
        reg_user_wr    <= i_reg_wr;
        reg_user_addr  <= i_reg_addr;
        reg_user_wdata <= i_reg_wdata;
      end
      if (w_op_done) begin
        case (reg_op_src)
          LPARA_SRC_FC[1:0]:  reg_fc_wr  <= reg_op_wdata;
          LPARA_SRC_OTG[1:0]: reg_otg_wr <= reg_op_wdata;
          default: begin
            reg_user_pend <= 1'b0;
            reg_done      <= 1'b1;
            if (!reg_op_wr)
              reg_rdata <= i_ulpi_data;
          end
        endcase
      end
    end
  end

  // Receive state: RxActive, RxError, line state, VBUS state, host disconnect, ID and data byte.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_rx
    if (!i_rst_n_phy) begin
      reg_rx_active  <= 1'b0;
      reg_rx_err   <= 1'b0;
      reg_rx_dv      <= 1'b0;
      reg_rx_d       <= 8'h00;
      reg_linestate  <= 2'b00;
      reg_vbus_state <= 2'b00;
      reg_hostdisc   <= 1'b0;
      reg_iddig      <= 1'b1;
    end else begin
      reg_rx_dv <= w_rx_byte;
      reg_rx_d  <= i_ulpi_data;
      if (w_rx_start) begin
        reg_rx_active <= 1'b1;
        reg_rx_err  <= 1'b0;
      end
      if (w_rx_end)
        reg_rx_active <= 1'b0;
      if (w_rx_cmd) begin
        reg_linestate  <= i_ulpi_data[1:0];
        reg_vbus_state <= i_ulpi_data[3:2];
        reg_iddig      <= ~i_ulpi_data[6];
        reg_hostdisc   <= (i_ulpi_data[5:4] == 2'b10);
        reg_rx_active  <= i_ulpi_data[4];
        reg_rx_err   <= (i_ulpi_data[5:4] == 2'b11);
      end
    end
  end

  // Outputs: pins and the link stream. In low power mode the PHY clock may stop, so the low
  // power stp of the always-on logic is ORed with the stp flop.
  assign o_ulpi_stp     = reg_stp | i_stp_lp;
  assign o_ulpi_data    = reg_data;
  assign o_ulpi_data_oe = reg_oe;
  assign o_lp_active    = ~reg_fc_wr[6];
  assign o_tx_ready     = w_tx_ready;
  assign o_tx_abort     = w_abort;
  assign o_rx_data      = {8'h00, reg_rx_d};
  assign o_rx_valid     = {1'b0, reg_rx_dv};
  assign o_rx_active    = reg_rx_active;
  assign o_rx_err     = reg_rx_err;
  assign o_linestate    = reg_linestate;
  assign o_hostdisc     = reg_hostdisc;
  assign o_iddig        = reg_iddig;
  assign o_avalid       = reg_vbus_state[1];
  assign o_bvalid       = reg_vbus_state[1];
  assign o_vbusvalid    = (reg_vbus_state == 2'b11);
  assign o_sessend      = (reg_vbus_state == 2'b00);
  assign o_reg_busy     = reg_user_pend;
  assign o_reg_done     = reg_done;
  assign o_reg_rdata    = reg_rdata;

endmodule
