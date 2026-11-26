/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : AXI4 subordinate and DMA handshake of the digital signature IP (REQ-IF-002,
 *                REQ-IF-004, section 6.3). It writes and reads the buffer window through the
 *                buffer port of m_vlsit_dsig_buf: one write burst and one read burst at a time
 *                (the address channel is ready only when idle), INCR bursts of whole transfers
 *                inside the window [0, PARA_BUF_BYTES) while the control block is idle. FIXED
 *                and WRAP bursts, transfers larger than the data width, bursts past the window
 *                end and any access while the control block is busy are answered with SLVERR: a
 *                write writes no byte, a read returns zero data; every beat of the burst is
 *                still taken or given so that the channel stays in step. A reject of the buffer
 *                in the middle of a burst also gives SLVERR. The pulse o_err_buserr is raised
 *                once per burst that ends with SLVERR (dsig_err.buserr). DMA (assumption
 *                ASM-019, the figure WF-017 only sketches it): o_dma_in_req rises when the IP is
 *                enabled, idle and has no result, and stays until i_dma_in_ack; o_dma_out_req
 *                rises when a result is valid and stays until i_dma_out_ack. An acknowledge
 *                blocks the request until the next operation starts (input) or the result is
 *                cleared (output). The AXI4 byte lanes follow IHI 0022: byte i of a beat is in
 *                wdata[8 i +: 8].
 */
`timescale 1ns/1ps

module m_vlsit_dsig_axi #(
  // Parameter Description: size of the buffer window.
  // Parameter values: 64 to 65536, a multiple of PARA_AXI_DW / 8; default is 1024.
  // Parameter unit: byte
  parameter logic [31:0] PARA_BUF_BYTES = 1024,
  // Parameter Description: data width of the AXI4 port and of the buffer word.
  // Parameter values: 32, 64 or 128; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 64,
  // Parameter Description: width of the AXI4 id.
  // Parameter values: 1 to 16; default is 4.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_IDW = 4,
  // Parameter Description: width of the AXI4 address.
  // Parameter values: 16 to 32; default is 16.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_AW = 16,
  localparam logic [31:0] LPARA_LANES = PARA_AXI_DW / 8,
  localparam logic [31:0] LPARA_LSIZE = $clog2(LPARA_LANES),
  localparam logic [31:0] LPARA_DEPTH = PARA_BUF_BYTES / LPARA_LANES,
  localparam logic [31:0] LPARA_WA = $clog2(LPARA_DEPTH),
  localparam logic [31:0] LPARA_BURST_INCR = 2'b01,
  localparam logic [31:0] LPARA_RESP_OKAY = 2'b00,
  localparam logic [31:0] LPARA_RESP_SLVERR = 2'b10
) (
  // Clock and reset
  input  wire                     i_clk_core,
  input  wire                     i_rst_n_core,

  // AXI4 write channels
  input  wire                     i_axi_awvalid,
  output logic                    o_axi_awready,
  input  wire  [PARA_AXI_IDW-1:0] i_axi_awid,
  input  wire  [PARA_AXI_AW-1:0]  i_axi_awaddr,
  input  wire  [7:0]              i_axi_awlen,
  input  wire  [2:0]              i_axi_awsize,
  input  wire  [1:0]              i_axi_awburst,
  input  wire                     i_axi_wvalid,
  output logic                    o_axi_wready,
  input  wire  [PARA_AXI_DW-1:0]  i_axi_wdata,
  input  wire  [LPARA_LANES-1:0]  i_axi_wstrb,
  input  wire                     i_axi_wlast,
  output logic                    o_axi_bvalid,
  input  wire                     i_axi_bready,
  output logic [PARA_AXI_IDW-1:0] o_axi_bid,
  output logic [1:0]              o_axi_bresp,

  // AXI4 read channels
  input  wire                     i_axi_arvalid,
  output logic                    o_axi_arready,
  input  wire  [PARA_AXI_IDW-1:0] i_axi_arid,
  input  wire  [PARA_AXI_AW-1:0]  i_axi_araddr,
  input  wire  [7:0]              i_axi_arlen,
  input  wire  [2:0]              i_axi_arsize,
  input  wire  [1:0]              i_axi_arburst,
  output logic                    o_axi_rvalid,
  input  wire                     i_axi_rready,
  output logic [PARA_AXI_IDW-1:0] o_axi_rid,
  output logic [PARA_AXI_DW-1:0]  o_axi_rdata,
  output logic [1:0]              o_axi_rresp,
  output logic                    o_axi_rlast,

  // Buffer port
  output logic                    o_buf_wr_en,
  output logic [LPARA_WA-1:0]     o_buf_wr_addr,
  output logic [PARA_AXI_DW-1:0]  o_buf_wr_data,
  output logic [LPARA_LANES-1:0]  o_buf_wr_strb,
  input  wire                     i_buf_wr_rej,
  output logic                    o_buf_rd_en,
  output logic [LPARA_WA-1:0]     o_buf_rd_addr,
  input  wire  [PARA_AXI_DW-1:0]  i_buf_rd_data,
  input  wire                     i_buf_rd_valid,
  input  wire                     i_buf_rd_rej,

  // Control block status
  input  wire                     i_busy,
  input  wire                     i_ctrl_en,
  input  wire                     i_resvld,

  // DMA handshake
  output logic                    o_dma_in_req,
  input  wire                     i_dma_in_ack,
  output logic                    o_dma_out_req,
  input  wire                     i_dma_out_ack,

  // Error pulse for dsig_err.buserr
  output logic                    o_err_buserr
);

  // States of the write channel and of the read channel
  typedef enum logic [2:0] {
    ENUM_ST_W_IDLE = 3'd0,
    ENUM_ST_W_DATA = 3'd1,
    ENUM_ST_W_WAIT = 3'd2,
    ENUM_ST_W_RESP = 3'd3
  } axiw_state_type_def;

  typedef enum logic [2:0] {
    ENUM_ST_R_IDLE = 3'd0,
    ENUM_ST_R_REQ  = 3'd1,
    ENUM_ST_R_WAIT = 3'd2,
    ENUM_ST_R_DATA = 3'd3
  } axir_state_type_def;

  // Internal signal declarations
  axiw_state_type_def reg_fsm_axiw_current_state;
  axiw_state_type_def w_fsm_axiw_nxt_state;
  axir_state_type_def reg_fsm_axir_current_state;
  axir_state_type_def w_fsm_axir_nxt_state;

  logic [PARA_AXI_IDW-1:0] reg_wid;
  logic [PARA_AXI_AW-1:0]  reg_waddr;
  logic [2:0]              reg_wsize;
  logic                    reg_wbad;
  logic                    reg_werr;
  logic [PARA_AXI_IDW-1:0] reg_rid;
  logic [PARA_AXI_AW-1:0]  reg_raddr;
  logic [7:0]              reg_rlen;
  logic [7:0]              reg_rbeat;
  logic [2:0]              reg_rsize;
  logic                    reg_rbad;
  logic                    reg_rerr;
  logic [PARA_AXI_DW-1:0]  reg_rdata;
  logic                    reg_in_done;
  logic                    reg_out_done;
  logic                    reg_busy_q;
  logic                    reg_resvld_q;
  logic                    reg_err_pulse;

  logic                    w_wbad_nxt;
  logic                    w_rbad_nxt;
  logic [31:0]             w_wend;
  logic [31:0]             w_rend;
  logic                    w_wbeat;
  logic [PARA_AXI_AW-1:0]  w_waddr_nxt;
  logic [PARA_AXI_AW-1:0]  w_raddr_nxt;

  // Legality of a new burst: INCR, a transfer not larger than the data width, inside the window and
  // the control block idle. The end address is the aligned start plus the whole burst.
  assign w_wend = {16'd0, i_axi_awaddr} + (({24'd0, i_axi_awlen} + 32'd1) << i_axi_awsize);
  assign w_rend = {16'd0, i_axi_araddr} + (({24'd0, i_axi_arlen} + 32'd1) << i_axi_arsize);
  assign w_wbad_nxt = (i_axi_awburst != LPARA_BURST_INCR) | ({29'd0, i_axi_awsize} > LPARA_LSIZE) |
                      (w_wend > PARA_BUF_BYTES) | i_busy;
  assign w_rbad_nxt = (i_axi_arburst != LPARA_BURST_INCR) | ({29'd0, i_axi_arsize} > LPARA_LSIZE) |
                      (w_rend > PARA_BUF_BYTES) | i_busy;

  // Address of the next beat: the aligned address plus the transfer size.
  assign w_waddr_nxt = ((reg_waddr >> reg_wsize) + 1'b1) << reg_wsize;
  assign w_raddr_nxt = ((reg_raddr >> reg_rsize) + 1'b1) << reg_rsize;

  // Write data channel: a beat is taken in W_DATA and goes to the buffer when the burst is legal.
  assign o_axi_awready = (reg_fsm_axiw_current_state == ENUM_ST_W_IDLE);
  assign o_axi_wready  = (reg_fsm_axiw_current_state == ENUM_ST_W_DATA);
  assign w_wbeat       = i_axi_wvalid & o_axi_wready;
  assign o_buf_wr_en   = w_wbeat & ~reg_wbad;
  assign o_buf_wr_addr = reg_waddr[LPARA_LSIZE +: LPARA_WA];
  assign o_buf_wr_data = i_axi_wdata;
  assign o_buf_wr_strb = i_axi_wstrb;
  assign o_axi_bvalid  = (reg_fsm_axiw_current_state == ENUM_ST_W_RESP);
  assign o_axi_bid     = reg_wid;
  assign o_axi_bresp   = (reg_wbad | reg_werr) ? LPARA_RESP_SLVERR : LPARA_RESP_OKAY;

  // Read channels.
  assign o_axi_arready = (reg_fsm_axir_current_state == ENUM_ST_R_IDLE);
  assign o_buf_rd_en   = (reg_fsm_axir_current_state == ENUM_ST_R_REQ);
  assign o_buf_rd_addr = reg_raddr[LPARA_LSIZE +: LPARA_WA];
  assign o_axi_rvalid  = (reg_fsm_axir_current_state == ENUM_ST_R_DATA);
  assign o_axi_rid     = reg_rid;
  assign o_axi_rdata   = (reg_rbad | reg_rerr) ? '0 : reg_rdata;
  assign o_axi_rresp   = (reg_rbad | reg_rerr) ? LPARA_RESP_SLVERR : LPARA_RESP_OKAY;
  assign o_axi_rlast   = o_axi_rvalid & (reg_rbeat == reg_rlen);

  // DMA requests.
  assign o_dma_in_req  = i_ctrl_en & ~i_busy & ~i_resvld & ~reg_in_done;
  assign o_dma_out_req = i_resvld & ~reg_out_done;
  assign o_err_buserr  = reg_err_pulse;

  // Part 1 of the FSMs: state registers.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_axiw
    if (!i_rst_n_core)
      reg_fsm_axiw_current_state <= ENUM_ST_W_IDLE;
    else
      reg_fsm_axiw_current_state <= w_fsm_axiw_nxt_state;
  end

  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_axir
    if (!i_rst_n_core)
      reg_fsm_axir_current_state <= ENUM_ST_R_IDLE;
    else
      reg_fsm_axir_current_state <= w_fsm_axir_nxt_state;
  end

  // Part 2 of the write FSM: next state.
  always_comb begin : p_com_fsm_axiw_nxt
    w_fsm_axiw_nxt_state = reg_fsm_axiw_current_state;
    case (reg_fsm_axiw_current_state)
      ENUM_ST_W_IDLE: begin
        if (i_axi_awvalid)
          w_fsm_axiw_nxt_state = ENUM_ST_W_DATA;
      end
      ENUM_ST_W_DATA: begin
        if (w_wbeat & i_axi_wlast)
          w_fsm_axiw_nxt_state = ENUM_ST_W_WAIT;
      end
      ENUM_ST_W_WAIT: w_fsm_axiw_nxt_state = ENUM_ST_W_RESP;
      ENUM_ST_W_RESP: begin
        if (i_axi_bready)
          w_fsm_axiw_nxt_state = ENUM_ST_W_IDLE;
      end
      default: w_fsm_axiw_nxt_state = ENUM_ST_W_IDLE;
    endcase
  end

  // Part 2 of the read FSM: next state.
  always_comb begin : p_com_fsm_axir_nxt
    w_fsm_axir_nxt_state = reg_fsm_axir_current_state;
    case (reg_fsm_axir_current_state)
      ENUM_ST_R_IDLE: begin
        if (i_axi_arvalid) begin
          if (w_rbad_nxt)
            w_fsm_axir_nxt_state = ENUM_ST_R_DATA;
          else
            w_fsm_axir_nxt_state = ENUM_ST_R_REQ;
        end
      end
      ENUM_ST_R_REQ: w_fsm_axir_nxt_state = ENUM_ST_R_WAIT;
      ENUM_ST_R_WAIT: begin
        if (i_buf_rd_valid)
          w_fsm_axir_nxt_state = ENUM_ST_R_DATA;
      end
      ENUM_ST_R_DATA: begin
        if (i_axi_rready) begin
          if (reg_rbeat == reg_rlen)
            w_fsm_axir_nxt_state = ENUM_ST_R_IDLE;
          else if (reg_rbad | reg_rerr)
            w_fsm_axir_nxt_state = ENUM_ST_R_DATA;
          else
            w_fsm_axir_nxt_state = ENUM_ST_R_REQ;
        end
      end
      default: w_fsm_axir_nxt_state = ENUM_ST_R_IDLE;
    endcase
  end

  // Write channel registers.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_wr
    if (!i_rst_n_core) begin
      reg_wid   <= '0;
      reg_waddr <= '0;
      reg_wsize <= 3'd0;
      reg_wbad  <= 1'b0;
      reg_werr  <= 1'b0;
    end
    else begin
      case (reg_fsm_axiw_current_state)
        ENUM_ST_W_IDLE: begin
          if (i_axi_awvalid) begin
            reg_wid   <= i_axi_awid;
            reg_waddr <= i_axi_awaddr;
            reg_wsize <= i_axi_awsize;
            reg_wbad  <= w_wbad_nxt;
            reg_werr  <= 1'b0;
          end
        end
        ENUM_ST_W_DATA: begin
          if (w_wbeat)
            reg_waddr <= w_waddr_nxt;
          if (i_buf_wr_rej)
            reg_werr <= 1'b1;
        end
        ENUM_ST_W_WAIT: begin
          if (i_buf_wr_rej)
            reg_werr <= 1'b1;
        end
        default: begin
          reg_wid <= reg_wid;
        end
      endcase
    end
  end

  // Read channel registers.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_rd
    if (!i_rst_n_core) begin
      reg_rid    <= '0;
      reg_raddr  <= '0;
      reg_rlen   <= 8'd0;
      reg_rbeat  <= 8'd0;
      reg_rsize  <= 3'd0;
      reg_rbad   <= 1'b0;
      reg_rerr   <= 1'b0;
      reg_rdata  <= '0;
    end
    else begin
      case (reg_fsm_axir_current_state)
        ENUM_ST_R_IDLE: begin
          if (i_axi_arvalid) begin
            reg_rid   <= i_axi_arid;
            reg_raddr <= i_axi_araddr;
            reg_rlen  <= i_axi_arlen;
            reg_rsize <= i_axi_arsize;
            reg_rbeat <= 8'd0;
            reg_rbad  <= w_rbad_nxt;
            reg_rerr  <= 1'b0;
          end
        end
        ENUM_ST_R_WAIT: begin
          if (i_buf_rd_valid) begin
            reg_rdata <= i_buf_rd_data;
            if (1'b0)
              reg_rerr <= 1'b1;
          end
        end
        ENUM_ST_R_DATA: begin
          if (i_axi_rready) begin
            reg_rbeat <= reg_rbeat + 8'd1;
            reg_raddr <= w_raddr_nxt;
          end
        end
        default: begin
          reg_rid <= reg_rid;
        end
      endcase
    end
  end

  // Error pulse, DMA flags: one pulse per burst that is answered with SLVERR; the request flags are
  // blocked after an acknowledge until the next operation or the clearing of the result.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_misc
    if (!i_rst_n_core) begin
      reg_in_done   <= 1'b0;
      reg_out_done  <= 1'b0;
      reg_busy_q    <= 1'b0;
      reg_resvld_q  <= 1'b0;
      reg_err_pulse <= 1'b0;
    end
    else begin
      reg_busy_q   <= i_busy;
      reg_resvld_q <= i_resvld;
      reg_err_pulse <= ((reg_fsm_axiw_current_state == ENUM_ST_W_WAIT) & (reg_wbad | reg_werr | i_buf_wr_rej)) |
                       ((reg_fsm_axir_current_state == ENUM_ST_R_DATA) & i_axi_rready & (reg_rbeat == reg_rlen) &
                        (reg_rbad | reg_rerr));
      if (i_dma_in_ack)
        reg_in_done <= 1'b1;
      else if (i_busy & ~reg_busy_q)
        reg_in_done <= 1'b0;
      if (i_dma_out_ack)
        reg_out_done <= 1'b1;
      else if (~i_resvld & reg_resvld_q)
        reg_out_done <= 1'b0;
    end
  end

endmodule
