/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : FIFO manager (section 10.4, FEAT-007, DEC-006). One RAM of rows of four chunks
 *                (32 bits for 8-bit UTMI+, 64 bits for 16-bit UTMI+, one parity bit per row when
 *                enabled) holds the queues: queue 0 is the shared receive region (packets in a
 *                ring with a packet length queue), the other queues are transmit rings (one per
 *                device IN endpoint, then host non-periodic and periodic). The packet port
 *                writes received payload into queue 0 and commits or rolls back a packet at its
 *                end; it reads transmit payload from a queue as a chunk stream and commits the
 *                rows on the acknowledge. The bus port (requests from CLK-BUS through
 *                m_usb2_cdc_fifo) writes rows into a transmit queue (OP_WR then OP_COMMIT),
 *                reads rows of the head packet of queue 0 (OP_RD then OP_POP) and flushes a
 *                queue. Credits and packet events go back to CLK-BUS as event words. Packet port
 *                accesses have priority; PARA_USB2_RAM_1P = 1 serializes reads and writes for a
 *                single-port macro. The CSR region fields are in 32-bit words; the module
 *                converts them to rows.
 */
`timescale 1ns/1ps

module m_usb2_fifo #(
  // Parameter Description: UTMI+ data width; the RAM row holds four chunks of this width.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: number of queues: receive, one per device IN endpoint, host
  // non-periodic and periodic.
  // Parameter values: 3 to 19; default is 11.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NQ = 11,
  // Parameter Description: RAM depth in 32-bit words.
  // Parameter values: power of two from 256 to 32768; default is 1024.
  // Parameter unit: word
  parameter logic [31:0] PARA_USB2_FIFO_DEPTH = 1024,
  // Parameter Description: 1 stores one parity bit per row and reports a mismatch.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_RAM_PAR_EN = 1,
  // Parameter Description: 1 allows one RAM access per cycle (single-port macro); 0 uses the two
  // ports of the library macro.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_RAM_1P = 0,
  localparam logic [31:0] LPARA_RW       = PARA_USB2_UTMI_W * 32'd4,
  localparam logic [31:0] LPARA_RAM_W    = LPARA_RW + PARA_USB2_RAM_PAR_EN,
  localparam logic [31:0] LPARA_SH       = (PARA_USB2_UTMI_W == 32'd16) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_ROWS     = PARA_USB2_FIFO_DEPTH >> LPARA_SH,
  localparam logic [31:0] LPARA_ADDR_W   = $clog2(LPARA_ROWS),
  localparam logic [31:0] LPARA_BPR_SH   = (PARA_USB2_UTMI_W == 32'd16) ? 32'd3 : 32'd2,
  localparam logic [31:0] LPARA_PLQ_N    = 8,
  localparam logic [31:0] LPARA_PLQ_W    = 3,
  localparam logic [31:0] LPARA_OP_WR    = 1,
  localparam logic [31:0] LPARA_OP_RD    = 2,
  localparam logic [31:0] LPARA_OP_POP   = 3,
  localparam logic [31:0] LPARA_OP_COMMIT = 4,
  localparam logic [31:0] LPARA_OP_FLUSH = 5,
  localparam logic [31:0] LPARA_EV_PKT   = 0,
  localparam logic [31:0] LPARA_EV_CRD   = 1,
  localparam logic [31:0] LPARA_W16      = 16,
  localparam logic [31:0] LPARA_ONE      = 1
) (
  // Clock and reset
  input  wire                        i_clk_phy,
  input  wire                        i_rst_n_core,

  // Region configuration in 32-bit words and flush request
  input  wire  [PARA_USB2_NQ*16-1:0] i_q_base,
  input  wire  [PARA_USB2_NQ*16-1:0] i_q_size,
  input  wire                        i_flush_vld,
  input  wire  [4:0]                 i_flush_q,

  // Packet port: received payload write
  input  wire                        i_rxw_sop,
  input  wire  [4:0]                 i_rxw_tag,
  input  wire  [1:0]                 i_rxw_n,
  input  wire  [15:0]                i_rxw_b,
  input  wire                        i_rxw_end,
  input  wire                        i_rxw_ok,
  input  wire  [11:0]                i_rxw_len,
  output logic [16:0]                o_rx_free,
  output logic                       o_plq_free,

  // Packet port: transmit payload read
  input  wire                        i_txr_start,
  input  wire  [4:0]                 i_txr_q,
  input  wire  [11:0]                i_txr_len,
  input  wire                        i_txr_commit,
  input  wire                        i_txr_cancel,
  input  wire                        i_src_pop,
  output logic [15:0]                o_src_dat,
  output logic                       o_src_vld,
  output logic [PARA_USB2_NQ*17-1:0] o_q_cnt,

  // Bus port (requests in CLK-PHY, from m_usb2_cdc_fifo)
  input  wire                        i_bp_vld,
  input  wire  [2:0]                 i_bp_op,
  input  wire  [4:0]                 i_bp_q,
  input  wire  [LPARA_RW-1:0]        i_bp_data,
  output logic                       o_bp_rdy,
  output logic                       o_bp_rsp_vld,
  output logic [LPARA_RW-1:0]        o_bp_rsp_data,

  // Event words to the bus side
  output logic                       o_ev_vld,
  output logic [1:0]                 o_ev_type,
  output logic [4:0]                 o_ev_q,
  output logic [16:0]                o_ev_val,
  input  wire                        i_ev_rdy,

  // Error pulses
  output logic                       o_ovf,
  output logic                       o_par_err
);

  // Internal signal declarations
  logic [PARA_USB2_NQ-1:0][15:0]            w_base;
  logic [PARA_USB2_NQ-1:0][15:0]            w_size;
  logic [PARA_USB2_NQ-1:0][LPARA_ADDR_W-1:0]           reg_wptr;
  logic [PARA_USB2_NQ-1:0][LPARA_ADDR_W-1:0]           reg_rptr;
  logic [PARA_USB2_NQ-1:0][LPARA_ADDR_W:0]             reg_cnt;
  logic [PARA_USB2_NQ-1:0][LPARA_ADDR_W:0]             reg_wpend;
  logic [PARA_USB2_NQ-1:0][LPARA_ADDR_W:0]             reg_cr;
  logic [LPARA_ADDR_W-1:0]                           reg_rx_wptr;
  logic [LPARA_ADDR_W:0]                             reg_rx_rows;
  logic                                     reg_rx_ovf;
  logic [4:0]                               reg_rx_tag;
  logic [LPARA_RW-1:0]                      reg_asm;
  logic [3:0]                               reg_asm_n;
  logic [LPARA_RW-1:0]                      reg_wrow;
  logic                                     reg_wrow_v;
  logic [LPARA_ADDR_W-1:0]                           reg_wrow_ptr;
  logic [1:0]                               reg_end_st;
  logic                                     reg_end_ok;
  logic [11:0]                              reg_end_len;
  logic [4:0]                               reg_plq_tag [LPARA_PLQ_N];
  logic [11:0]                              reg_plq_len [LPARA_PLQ_N];
  logic [LPARA_PLQ_W-1:0]                   reg_plq_rd;
  logic [LPARA_PLQ_W-1:0]                   reg_plq_wr;
  logic [LPARA_PLQ_W:0]                     reg_plq_cnt;
  logic [LPARA_PLQ_W:0]                     reg_plq_rep;
  logic [LPARA_ADDR_W-1:0]                           reg_rd_off;
  logic [15:0]                              w_pop_ptr;
  logic                                     w_flush_q0;
  logic                                     reg_rd_act;
  logic [4:0]                               reg_rd_q;
  logic [LPARA_ADDR_W:0]                             reg_rd_rows;
  logic [LPARA_ADDR_W:0]                             reg_rd_left;
  logic                                              reg_rd_more;
  logic [LPARA_ADDR_W-1:0]                           reg_rd_ptr;
  logic                                     reg_rd_pend;
  logic                                     reg_rd_dest;
  logic [LPARA_RW-1:0]                      reg_cur;
  logic                                     reg_cur_v;
  logic [LPARA_RW-1:0]                      reg_nxt;
  logic                                     reg_nxt_v;
  logic [1:0]                               reg_idx;
  logic                                     reg_bp_rsp_v;
  logic [4:0]                               reg_cr_scan;
  logic                                     reg_ovf;
  logic                                     reg_par_err;
  logic [15:0]                              w_rd_wrap;
  logic                                     w_rd_req_pkt;
  logic [LPARA_ADDR_W-1:0]                  w_rd_addr_pkt;
  logic                                     w_wr_req_pkt;
  logic [LPARA_ADDR_W-1:0]                  w_wr_addr_pkt;
  logic                                     w_bus_wr_req;
  logic                                     w_bus_wr_op;
  logic                                     w_bus_q_full;
  logic                                     w_bus_rd_req;
  logic                                     w_bus_nram;
  logic [LPARA_ADDR_W-1:0]                  w_bus_wr_addr;
  logic [LPARA_ADDR_W-1:0]                  w_bus_rd_addr;
  logic                                     w_wr_pkt_gnt;
  logic                                     w_wr_bus_gnt;
  logic                                     w_rd_pkt_gnt;
  logic                                     w_rd_bus_gnt;
  logic [LPARA_ADDR_W-1:0]                  w_ram_wr_addr;
  logic [LPARA_RW-1:0]                      w_ram_wr_data;
  logic                                     w_ram_wr_en;
  logic [LPARA_ADDR_W-1:0]                  w_ram_rd_addr;
  logic                                     w_ram_rd_en;
  logic [LPARA_RAM_W-1:0]                   w_ram_wr_word;
  logic [LPARA_RAM_W-1:0]                   w_ram_rd_word;
  logic [LPARA_RW-1:0]                      w_ram_rd_data;
  logic                                     w_par_bad;
  logic [LPARA_RW+15:0]                     w_cat;
  logic [LPARA_RW-1:0]                      w_asm_row;
  logic [LPARA_RW-1:0]                      w_asm_nxt;
  logic [3:0]                               w_asm_n_nxt;
  logic                                     w_asm_full;
  logic [16:0]                              w_rows_head;
  logic [11:0]                              w_head_len;
  logic                                     w_end_flush;
  logic                                     w_end_commit;
  logic                                     w_pkt_good;
  logic                                     w_issue;
  logic                                     w_pop_adv;
  logic [16:0]                              w_free0;
  logic [16:0]                              reg_rx_free;
  logic [16:0]                              w_rows_txr;
  logic                                     w_ev_pkt_pend;
  logic [LPARA_PLQ_W-1:0]                   w_ev_idx;
  logic                                     w_ev_crd_hit;
  logic                                     w_pop_plq;

  // Region configuration in rows: the words are divided by the number of words per row.
  always_comb begin : p_com_cfg
    w_base = '0;
    w_size = '0;
    for (int idx = 0; idx < PARA_USB2_NQ; idx++) begin
      w_base[idx] = i_q_base[idx*16 +: 16] >> LPARA_SH;
      w_size[idx] = i_q_size[idx*16 +: 16] >> LPARA_SH;
    end
  end

  // Number of rows of the head packet of queue 0 and its tag and length.
  assign w_head_len  = reg_plq_len[reg_plq_rd];
  assign w_rows_head = ({5'd0, w_head_len} + (17'd1 << LPARA_BPR_SH) - 17'd1) >> LPARA_BPR_SH;
  assign w_rows_txr  = ({5'd0, i_txr_len} + (17'd1 << LPARA_BPR_SH) - 17'd1) >> LPARA_BPR_SH;

  // Free rows of the receive region and room in the packet length queue, seen by the engines.
  assign w_free0    = {1'b0, w_size[0]} - reg_cnt[0] - reg_rx_rows;
  assign o_rx_free  = reg_rx_free;
  assign o_plq_free = (reg_plq_cnt < LPARA_PLQ_N[LPARA_PLQ_W:0]);

  // Committed rows of every queue for the engines.
  always_comb begin : p_com_cnt
    o_q_cnt = '0;
    for (int idx = 0; idx < PARA_USB2_NQ; idx++) begin
      o_q_cnt[idx*17 +: 17] = reg_cnt[idx];
    end
  end

  // Receive assembler: the chunk is merged with the held bytes; a full row goes to the row
  // register, the remainder (at most one byte) stays in the assembler.
  assign w_cat = {16'h0000, reg_asm} | ({{LPARA_RW{1'b0}}, i_rxw_b} << (8 * reg_asm_n));

  always_comb begin : p_com_asm
    w_asm_row   = w_cat[LPARA_RW-1:0];
    w_asm_nxt   = w_cat[LPARA_RW-1:0];
    w_asm_n_nxt = reg_asm_n + {2'b00, i_rxw_n};
    w_asm_full  = 1'b0;
    if (i_rxw_n != 2'd0) begin
      if (w_asm_n_nxt >= (4'd1 << LPARA_BPR_SH)) begin
        w_asm_full  = 1'b1;
        w_asm_nxt   = w_cat[LPARA_RW+15:16] >> (LPARA_RW - 16);
        w_asm_n_nxt = w_asm_n_nxt - (4'd1 << LPARA_BPR_SH);
      end
    end else begin
      w_asm_n_nxt = reg_asm_n;
      w_asm_nxt   = reg_asm;
    end
  end

  // Pop of the head packet by the bus port.
  assign w_pop_plq = i_bp_vld & o_bp_rdy & (i_bp_op == LPARA_OP_POP[2:0]) & (reg_plq_cnt != '0);

  // Packet end: flush of the partial row, then commit or rollback.
  assign w_end_flush  = (reg_end_st == 2'd1);
  assign w_end_commit = (reg_end_st == 2'd2) & ~reg_wrow_v;
  assign w_pkt_good   = reg_end_ok & ~reg_rx_ovf;

  // Row write requests of the packet port (the row register) and of the bus port.
  assign w_wr_req_pkt  = reg_wrow_v;
  assign w_wr_addr_pkt = w_base[0][LPARA_ADDR_W-1:0] + reg_wrow_ptr[LPARA_ADDR_W-1:0];
  // A bus row write waits while its transmit queue holds no free row: committed rows plus rows of
  // the packet being written fill the region (REQ-FUNC-027: unread data is never overwritten).
  assign w_bus_wr_op   = i_bp_vld & (i_bp_op == LPARA_OP_WR[2:0]);
  assign w_bus_q_full  = ((reg_cnt[i_bp_q] + reg_wpend[i_bp_q]) >= {1'b0, w_size[i_bp_q]});
  assign w_bus_wr_req  = w_bus_wr_op & ~w_bus_q_full;
  assign w_bus_rd_req  = i_bp_vld & (i_bp_op == LPARA_OP_RD[2:0]);
  assign w_bus_nram    = i_bp_vld & ~w_bus_wr_op & ~w_bus_rd_req;
  assign w_bus_wr_addr = w_base[i_bp_q][LPARA_ADDR_W-1:0] + reg_wptr[i_bp_q][LPARA_ADDR_W-1:0];
  assign w_rd_wrap     = reg_rd_off;
  assign w_bus_rd_addr = w_base[0][LPARA_ADDR_W-1:0] + w_rd_wrap[LPARA_ADDR_W-1:0];

  // Packet read request: the reader issues a row read when a buffer slot is free.
  assign w_issue       = reg_rd_act & reg_rd_more & ~reg_rd_pend &
                         (~reg_cur_v | ~reg_nxt_v);
  assign w_rd_req_pkt  = w_issue;
  assign w_rd_addr_pkt = w_base[reg_rd_q][LPARA_ADDR_W-1:0] + reg_rd_ptr[LPARA_ADDR_W-1:0];

  // Grants: packet port first; with one port a read blocks the write of the same cycle.
  always_comb begin : p_com_gnt
    w_rd_pkt_gnt = w_rd_req_pkt;
    w_wr_pkt_gnt = w_wr_req_pkt;
    w_rd_bus_gnt = w_bus_rd_req & ~w_rd_req_pkt;
    w_wr_bus_gnt = w_bus_wr_req & ~w_wr_req_pkt;
    if (PARA_USB2_RAM_1P != 32'd0) begin
      w_wr_pkt_gnt = w_wr_req_pkt & ~w_rd_req_pkt;
      w_rd_bus_gnt = w_bus_rd_req & ~w_rd_req_pkt & ~w_wr_req_pkt;
      w_wr_bus_gnt = w_bus_wr_req & ~w_wr_req_pkt & ~w_rd_req_pkt;
    end
  end

  assign o_bp_rdy = w_bus_nram | w_rd_bus_gnt | w_wr_bus_gnt;

  // RAM port multiplexers and the parity bit.
  assign w_ram_wr_en   = w_wr_pkt_gnt | w_wr_bus_gnt;
  assign w_ram_wr_addr = w_wr_pkt_gnt ? w_wr_addr_pkt : w_bus_wr_addr;
  assign w_ram_wr_data = w_wr_pkt_gnt ? reg_wrow : i_bp_data;
  assign w_ram_rd_en   = w_rd_pkt_gnt | w_rd_bus_gnt;
  assign w_ram_rd_addr = w_rd_pkt_gnt ? w_rd_addr_pkt : w_bus_rd_addr;

  generate
    if (PARA_USB2_RAM_PAR_EN != 32'd0) begin : gen_par
      assign w_ram_wr_word = {^w_ram_wr_data, w_ram_wr_data};
      assign w_ram_rd_data = w_ram_rd_word[LPARA_RW-1:0];
      assign w_par_bad     = (^w_ram_rd_word) & (reg_rd_pend | reg_bp_rsp_v);
    end else begin : gen_nopar
      assign w_ram_wr_word = w_ram_wr_data;
      assign w_ram_rd_data = w_ram_rd_word;
      assign w_par_bad     = 1'b0;
    end
  endgenerate

  // The RAM: the library wrapper of the 1W1R macro (active-low enables, one-cycle read).
  m_vlsit_sfifo_ram_macro #(
    .PARA_SFIFO_DEPTH  (LPARA_ROWS),
    .PARA_SFIFO_DATA_W (LPARA_RAM_W)
  ) u_ram (
    .i_clk_wr   (i_clk_phy),
    .i_wr_en_n  (~w_ram_wr_en),
    .i_wr_addr  (w_ram_wr_addr),
    .i_wr_data  (w_ram_wr_word),
    .i_clk_rd   (i_clk_phy),
    .i_rd_en_n  (~w_ram_rd_en),
    .i_rd_addr  (w_ram_rd_addr),
    .o_rd_data  (w_ram_rd_word)
  );

  // Pointer arithmetic: add an offset to a ring pointer and wrap at the size of the ring.
  function automatic logic [15:0] wrap_ptr (input logic [15:0] i_ptr, input logic [15:0] i_inc,
                                            input logic [15:0] i_sz);
    logic [16:0] w_sum;
    w_sum = {1'b0, i_ptr} + {1'b0, i_inc};
    if (w_sum >= {1'b0, i_sz})
      w_sum = w_sum - {1'b0, i_sz};
    return w_sum[15:0];
  endfunction

  // Receive side: assembler, row register, end sequence and the packet length queue.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_rx
    if (!i_rst_n_core) begin
      reg_asm      <= '0;
      reg_asm_n    <= 4'd0;
      reg_wrow     <= '0;
      reg_wrow_v   <= 1'b0;
      reg_wrow_ptr <= 16'd0;
      reg_rx_wptr  <= 16'd0;
      reg_rx_rows  <= 17'd0;
      reg_rx_ovf   <= 1'b0;
      reg_rx_tag   <= 5'd0;
      reg_end_st   <= 2'd0;
      reg_end_ok   <= 1'b0;
      reg_end_len  <= 12'd0;
      reg_ovf      <= 1'b0;
    end else begin
      reg_ovf <= 1'b0;
      if (w_wr_pkt_gnt)
        reg_wrow_v <= 1'b0;
      if (i_rxw_sop) begin
        reg_asm     <= '0;
        reg_asm_n   <= 4'd0;
        reg_rx_wptr <= reg_wptr[0];
        reg_rx_rows <= 17'd0;
        reg_rx_ovf  <= (reg_plq_cnt >= LPARA_PLQ_N[LPARA_PLQ_W:0]);
        reg_rx_tag  <= i_rxw_tag;
      end else begin
        reg_asm   <= w_asm_nxt;
        reg_asm_n <= w_asm_n_nxt;
      end
      if (w_asm_full & ~i_rxw_sop) begin
        if (({1'b0, w_size[0]} - reg_cnt[0] - reg_rx_rows) == 17'd0 | reg_rx_ovf) begin
          reg_rx_ovf <= 1'b1;
          reg_ovf    <= 1'b1;
        end else begin
          reg_wrow     <= w_asm_row;
          reg_wrow_v   <= 1'b1;
          reg_wrow_ptr <= reg_rx_wptr;
          reg_rx_wptr  <= wrap_ptr(reg_rx_wptr, 16'd1, w_size[0]);
          reg_rx_rows  <= reg_rx_rows + 17'd1;
        end
      end
      if (i_rxw_end & (reg_end_st == 2'd0)) begin
        reg_end_st  <= 2'd1;
        reg_end_ok  <= i_rxw_ok;
        reg_end_len <= i_rxw_len;
      end
      if (w_end_flush) begin
        reg_end_st <= 2'd2;
        if ((reg_asm_n != 4'd0) & ~reg_rx_ovf & ~reg_wrow_v) begin
          reg_wrow     <= reg_asm;
          reg_wrow_v   <= 1'b1;
          reg_wrow_ptr <= reg_rx_wptr;
          reg_rx_wptr  <= wrap_ptr(reg_rx_wptr, 16'd1, w_size[0]);
          reg_rx_rows  <= reg_rx_rows + 17'd1;
          reg_asm      <= '0;
          reg_asm_n    <= 4'd0;
        end else if ((reg_asm_n != 4'd0) & reg_wrow_v) begin
          reg_end_st <= 2'd1;
        end
      end
      if (w_end_commit) begin
        reg_end_st  <= 2'd0;
        reg_rx_rows <= 17'd0;
      end
    end
  end

  // Free rows of the receive region, registered (one cycle old, never early to rise by more than
  // the rows of one write): the subtraction stays out of the token decision path (PIPE option
  // free).
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_free
    if (!i_rst_n_core)
      reg_rx_free <= 17'd0;
    else
      reg_rx_free <= w_free0[16] ? 17'd0 : w_free0;
  end

  // Packet length queue: push at commit, pop at OP_POP; the report counter follows the events.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_plq
    if (!i_rst_n_core) begin
      reg_plq_rd  <= '0;
      reg_plq_wr  <= '0;
      reg_plq_cnt <= '0;
      reg_plq_rep <= '0;
      for (int idx = 0; idx < LPARA_PLQ_N; idx++) begin
        reg_plq_tag[idx] <= 5'd0;
        reg_plq_len[idx] <= 12'd0;
      end
    end else begin
      if (w_end_commit & w_pkt_good) begin
        reg_plq_tag[reg_plq_wr] <= reg_rx_tag;
        reg_plq_len[reg_plq_wr] <= reg_end_len;
        reg_plq_wr              <= reg_plq_wr + LPARA_ONE[LPARA_PLQ_W-1:0];
      end
      if (w_pop_plq)
        reg_plq_rd <= reg_plq_rd + LPARA_ONE[LPARA_PLQ_W-1:0];
      case ({w_pop_plq & (reg_plq_rep != '0), (o_ev_vld & i_ev_rdy & (o_ev_type == LPARA_EV_PKT[1:0]))})
        2'b10:   reg_plq_rep <= reg_plq_rep - LPARA_ONE[LPARA_PLQ_W:0];
        2'b01:   reg_plq_rep <= reg_plq_rep + LPARA_ONE[LPARA_PLQ_W:0];
        default: reg_plq_rep <= reg_plq_rep;
      endcase
      case ({(w_end_commit & w_pkt_good), w_pop_plq})
        2'b10:   reg_plq_cnt <= reg_plq_cnt + LPARA_ONE[LPARA_PLQ_W:0];
        2'b01:   reg_plq_cnt <= reg_plq_cnt - LPARA_ONE[LPARA_PLQ_W:0];
        default: reg_plq_cnt <= reg_plq_cnt;
      endcase
    end
  end

  // Per-queue pointers and counters: written by the receive commit (queue 0), the bus port and
  // the transmit commit of the packet port.
  generate
    for (genvar gen_q = 0; gen_q < PARA_USB2_NQ; gen_q++) begin : gen_queue
      logic w_flush_q;
      logic w_rxc_q;
      logic w_pop_q;
      logic w_wr_q;
      logic w_cm_q;
      logic w_txc_q;
      logic [16:0] w_inc;
      logic [16:0] w_dec;

      assign w_flush_q = (i_flush_vld & (i_flush_q == 5'(gen_q))) |
                         (i_bp_vld & o_bp_rdy & (i_bp_op == LPARA_OP_FLUSH[2:0]) & (i_bp_q == 5'(gen_q)));
      assign w_rxc_q   = (gen_q == 0) & w_end_commit & w_pkt_good;
      assign w_pop_q   = (gen_q == 0) & w_pop_plq;
      assign w_wr_q    = (gen_q != 0) & w_wr_bus_gnt & (i_bp_q == 5'(gen_q));
      assign w_cm_q    = (gen_q != 0) & i_bp_vld & o_bp_rdy & (i_bp_op == LPARA_OP_COMMIT[2:0]) & (i_bp_q == 5'(gen_q));
      assign w_txc_q   = (gen_q != 0) & i_txr_commit & reg_rd_act & (reg_rd_q == 5'(gen_q));
      assign w_inc     = (w_rxc_q ? reg_rx_rows : 17'd0) + (w_cm_q ? reg_wpend[gen_q] : 17'd0);
      assign w_dec     = (w_pop_q ? w_rows_head : 17'd0) + (w_txc_q ? reg_rd_rows : 17'd0);

      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_q
        if (!i_rst_n_core) begin
          reg_wptr[gen_q]  <= 16'd0;
          reg_rptr[gen_q]  <= 16'd0;
          reg_cnt[gen_q]   <= 17'd0;
          reg_wpend[gen_q] <= 17'd0;
          reg_cr[gen_q]    <= 17'd0;
        end else if (w_flush_q) begin
          reg_wptr[gen_q]  <= 16'd0;
          reg_rptr[gen_q]  <= 16'd0;
          reg_cnt[gen_q]   <= 17'd0;
          reg_wpend[gen_q] <= 17'd0;
          reg_cr[gen_q]    <= 17'd0;
        end else begin
          if (w_rxc_q)
            reg_wptr[gen_q] <= reg_rx_wptr;
          if (w_wr_q) begin
            reg_wptr[gen_q]  <= wrap_ptr(reg_wptr[gen_q], 16'd1, w_size[gen_q]);
            reg_wpend[gen_q] <= reg_wpend[gen_q] + 17'd1;
          end
          if (w_cm_q)
            reg_wpend[gen_q] <= w_wr_q ? 17'd1 : 17'd0;
          if (w_pop_q)
            reg_rptr[gen_q] <= wrap_ptr(reg_rptr[gen_q], w_rows_head[15:0], w_size[gen_q]);
          if (w_txc_q)
            reg_rptr[gen_q] <= wrap_ptr(reg_rptr[gen_q], 16'(reg_rd_rows), w_size[gen_q]);
          reg_cnt[gen_q] <= reg_cnt[gen_q] + w_inc - w_dec;
          if (w_txc_q)
            reg_cr[gen_q] <= reg_cr[gen_q] + reg_rd_rows;
          if (w_ev_crd_hit & (reg_cr_scan == 5'(gen_q)))
            reg_cr[gen_q] <= w_txc_q ? reg_rd_rows : 17'd0;
        end
      end
    end
  endgenerate

  // Reader of the packet port: rows are read into the current and the next buffer and served as
  // chunks of one byte (8-bit mode) or two bytes (16-bit mode).
  assign w_pop_adv = i_src_pop & reg_cur_v;

  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_rd
    if (!i_rst_n_core) begin
      reg_rd_act    <= 1'b0;
      reg_rd_q      <= 5'd0;
      reg_rd_rows   <= 17'd0;
      reg_rd_left   <= 17'd0;
      reg_rd_more   <= 1'b0;
      reg_rd_ptr    <= 16'd0;
      reg_rd_pend   <= 1'b0;
      reg_rd_dest   <= 1'b0;
      reg_cur       <= '0;
      reg_cur_v     <= 1'b0;
      reg_nxt       <= '0;
      reg_nxt_v     <= 1'b0;
      reg_idx       <= 2'd0;
    end else begin
      reg_rd_pend <= w_rd_pkt_gnt;
      if (i_txr_start) begin
        reg_rd_act    <= 1'b1;
        reg_rd_q      <= i_txr_q;
        reg_rd_rows   <= w_rows_txr;
        reg_rd_left   <= w_rows_txr;
        reg_rd_more   <= (w_rows_txr != 17'd0);
        reg_rd_ptr    <= reg_rptr[i_txr_q];
        reg_cur_v     <= 1'b0;
        reg_nxt_v     <= 1'b0;
        reg_idx       <= 2'd0;
      end else begin
        if (i_txr_cancel | i_txr_commit)
          reg_rd_act <= 1'b0;
        if (w_rd_pkt_gnt) begin
          reg_rd_left   <= reg_rd_left - 17'd1;
          reg_rd_more   <= (reg_rd_left != 17'd1);
          reg_rd_ptr    <= wrap_ptr(reg_rd_ptr, 16'd1, w_size[reg_rd_q]);
          reg_rd_dest   <= reg_cur_v;
        end
        if (reg_rd_pend) begin
          if (reg_rd_dest) begin
            reg_nxt   <= w_ram_rd_data;
            reg_nxt_v <= 1'b1;
          end else begin
            reg_cur   <= w_ram_rd_data;
            reg_cur_v <= 1'b1;
            reg_idx   <= 2'd0;
          end
        end
        if (w_pop_adv) begin
          if (reg_idx == 2'd3) begin
            reg_idx <= 2'd0;
            if (reg_nxt_v & ~(reg_rd_pend & reg_rd_dest)) begin
              reg_cur   <= reg_nxt;
              reg_cur_v <= 1'b1;
              reg_nxt_v <= 1'b0;
            end else begin
              reg_cur_v <= 1'b0;
            end
          end else begin
            reg_idx <= reg_idx + 2'd1;
          end
        end
      end
    end
  end

  // Chunk of the current row: one byte in 8-bit mode, two bytes in 16-bit mode.
  always_comb begin : p_com_chunk
    o_src_dat = 16'h0000;
    if (PARA_USB2_UTMI_W == LPARA_W16)
      o_src_dat = reg_cur[16*reg_idx +: 16];
    else
      o_src_dat = {8'h00, reg_cur[8*reg_idx +: 8]};
  end

  assign o_src_vld = reg_cur_v;

  // Bus port response: the RAM data of the read of the previous cycle.
  // Pointer of the next bus read row, kept incrementally (ring pointer of queue 0): it moves by one
  // row for each read and jumps to the new read pointer when the head packet is released.
  assign w_pop_ptr   = wrap_ptr(reg_rptr[0], w_rows_head[15:0], w_size[0]);
  assign w_flush_q0  = (i_flush_vld & (i_flush_q == 5'd0)) |
                       (i_bp_vld & o_bp_rdy & (i_bp_op == LPARA_OP_FLUSH[2:0]) & (i_bp_q == 5'd0));

  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_bp
    if (!i_rst_n_core) begin
      reg_bp_rsp_v <= 1'b0;
      reg_rd_off   <= 16'd0;
      reg_par_err  <= 1'b0;
    end else begin
      reg_bp_rsp_v <= w_rd_bus_gnt;
      reg_par_err  <= w_par_bad;
      if (w_rd_bus_gnt)
        reg_rd_off <= wrap_ptr(reg_rd_off, 16'd1, w_size[0]);
      if (w_pop_plq)
        reg_rd_off <= w_pop_ptr;
      if (w_flush_q0)
        reg_rd_off <= 16'd0;
    end
  end

  assign o_bp_rsp_vld  = reg_bp_rsp_v;
  assign o_bp_rsp_data = w_ram_rd_data;
  assign o_ovf         = reg_ovf;
  assign o_par_err     = reg_par_err;

  // Events to the bus side: a new packet first, then a credit by a round-robin scan.
  assign w_ev_pkt_pend = (reg_plq_cnt > reg_plq_rep);
  assign w_ev_idx      = reg_plq_rd + reg_plq_rep[LPARA_PLQ_W-1:0];
  assign w_ev_crd_hit  = ~w_ev_pkt_pend & (reg_cr[reg_cr_scan] != 17'd0) & i_ev_rdy;

  always_comb begin : p_com_ev
    o_ev_vld  = 1'b0;
    o_ev_type = LPARA_EV_PKT[1:0];
    o_ev_q    = 5'd0;
    o_ev_val  = 17'd0;
    if (w_ev_pkt_pend) begin
      o_ev_vld  = 1'b1;
      o_ev_type = LPARA_EV_PKT[1:0];
      o_ev_q    = reg_plq_tag[w_ev_idx];
      o_ev_val  = {5'd0, reg_plq_len[w_ev_idx]};
    end else if (reg_cr[reg_cr_scan] != 17'd0) begin
      o_ev_vld  = 1'b1;
      o_ev_type = LPARA_EV_CRD[1:0];
      o_ev_q    = reg_cr_scan;
      o_ev_val  = reg_cr[reg_cr_scan];
    end
  end

  // Credit scan pointer: moves when the current queue has nothing to report.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_scan
    if (!i_rst_n_core)
      reg_cr_scan <= 5'd0;
    else if (reg_cr[reg_cr_scan] == 17'd0 | w_ev_crd_hit) begin
      if (reg_cr_scan == (PARA_USB2_NQ[4:0] - 5'd1))
        reg_cr_scan <= 5'd0;
      else
        reg_cr_scan <= reg_cr_scan + 5'd1;
    end
  end

endmodule
