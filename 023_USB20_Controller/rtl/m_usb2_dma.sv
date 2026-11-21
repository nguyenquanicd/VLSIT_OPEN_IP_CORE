/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : AXI4 master DMA in CLK-BUS (section 10.5, FEAT-006, DEC-010). Receive drain:
 *                for each packet event of the FIFO manager (tag, length) it reads the rows of
 *                the head packet through the bus port, writes them to the memory buffer of the
 *                endpoint or channel (INCR bursts of at most burst_len beats, never across a 4
 *                KB boundary, last beat with write strobes), moves the buffer address forward by
 *                the padded size and releases the packet. Transmit fill: when an IN endpoint or
 *                a host OUT channel is armed, it reads the transfer packet by packet from
 *                memory, writes the rows into the transmit queue and commits each packet once
 *                the queue has the room (credit counters from the credit events). One AXI beat
 *                is one RAM row, so the AXI data width equals four chunks of the UTMI+ width
 *                (DEC-010). Buffer addresses must be aligned to the row size. Scatter-gather
 *                (build option PARA_USB2_SG_EN, DEC-013): the address field of the CSR points to
 *                a list of 8-byte descriptors, one per packet {buffer address, length, last and
 *                ioc bits, status}; the engine reads the descriptor, moves the packet, writes
 *                back done, err, short and the bytes not transferred and moves the pointer to
 *                the next descriptor.
 */
`timescale 1ns/1ps

module m_usb2_dma #(
  // Parameter Description: AXI data width, equal to the RAM row width.
  // Parameter values: 32 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_DATA_W = 32,
  // Parameter Description: AXI address width.
  // Parameter values: 32, 40 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_ADDR_W = 32,
  // Parameter Description: AXI ID width.
  // Parameter values: 1 to 8; default is 4.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_ID_W = 4,
  // Parameter Description: device endpoint entries per direction (EP0 and the others).
  // Parameter values: 2 to 16; default is 9.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NEP1 = 9,
  // Parameter Description: number of host channels.
  // Parameter values: 1 to 16; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NHC = 8,
  // Parameter Description: 1 builds the scatter-gather descriptor engine (DEC-013).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_SG_EN = 0,
  // Parameter Description: RAM depth in 32-bit words; sets the width of the credit counters.
  // Parameter values: power of two from 256 to 32768; default is 1024.
  // Parameter unit: word
  parameter logic [31:0] PARA_USB2_FIFO_DEPTH = 1024,
  localparam logic [31:0] LPARA_NQ        = PARA_USB2_NEP1 + 32'd3,
  localparam logic [31:0] LPARA_HQ_NP     = PARA_USB2_NEP1 + 32'd1,
  localparam logic [31:0] LPARA_ROW_W     = PARA_USB2_AXI_DATA_W,
  localparam logic [31:0] LPARA_BYTES     = PARA_USB2_AXI_DATA_W / 32'd8,
  localparam logic [31:0] LPARA_BSH       = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd3 : 32'd2,
  localparam logic [31:0] LPARA_SH        = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_OP_WR     = 1,
  localparam logic [31:0] LPARA_OP_RD     = 2,
  localparam logic [31:0] LPARA_OP_POP    = 3,
  localparam logic [31:0] LPARA_OP_COMMIT = 4,
  localparam logic [31:0] LPARA_EV_PKT    = 0,
  localparam logic [31:0] LPARA_EV_CRD    = 1,
  localparam logic [31:0] LPARA_EVQ_N     = 8,
  localparam logic [31:0] LPARA_EVQ_W     = 3,
  localparam logic [31:0] LPARA_OUTST_MAX = 4,
  localparam logic [31:0] LPARA_ONE       = 1,
  localparam logic [31:0] LPARA_CW        = $clog2(PARA_USB2_FIFO_DEPTH >> ((PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd1 : 32'd0)) + 32'd1,
  localparam logic [31:0] LPARA_DESC_OFF  = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd0 : 32'd4,
  localparam logic [31:0] LPARA_DESC_ARL  = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd0 : 32'd1
) (
  // Clock and reset
  input  wire                               i_clk_bus,
  input  wire                               i_rst_n_bus,

  // Control from the CSR (bus domain)
  input  wire                               i_core_en,
  input  wire                               i_dma_en,
  input  wire                               i_role_host,
  input  wire                               i_fl_tx,
  input  wire                               i_sg_mode,
  input  wire                               i_win_en,
  input  wire                               i_err_stop,
  input  wire  [31:0]                       i_win_base,
  input  wire  [31:0]                       i_win_lim,
  input  wire  [4:0]                        i_tx_sel,
  input  wire  [31:0]                       i_dma_cfg,
  input  wire  [31:0]                       i_dma_hi,
  input  wire  [31:0]                       i_fifo_hnp,
  input  wire  [31:0]                       i_fifo_hpt,
  input  wire  [PARA_USB2_NEP1-1:0][31:0]   i_epi_ctrl,
  input  wire  [PARA_USB2_NEP1-1:0][31:0]   i_epi_xfer,
  input  wire  [PARA_USB2_NEP1-1:0][31:0]   i_epi_dma,
  input  wire  [PARA_USB2_NEP1-1:0][31:0]   i_epi_fifo,
  input  wire  [PARA_USB2_NEP1-1:0][31:0]   i_epo_dma,
  input  wire  [PARA_USB2_NHC-1:0][31:0]    i_hc_ctrl,
  input  wire  [PARA_USB2_NHC-1:0][31:0]    i_hc_xfer,
  input  wire  [PARA_USB2_NHC-1:0][31:0]    i_hc_dma,

  // Buffer address updates (hardware load of the rwi address fields)
  output logic [31:0]                       o_ld_addr,
  output logic [PARA_USB2_NEP1-1:0]         o_ld_epi_we,
  output logic [PARA_USB2_NEP1-1:0]         o_ld_epo_we,
  output logic [PARA_USB2_NHC-1:0]          o_ld_hc_we,

  // Bus port requests, responses and events (through m_usb2_cdc_fifo)
  output logic                              o_rq_vld,
  output logic [2:0]                        o_rq_op,
  output logic [4:0]                        o_rq_q,
  output logic [LPARA_ROW_W-1:0]            o_rq_data,
  input  wire                               i_rq_rdy,
  input  wire                               i_rs_vld,
  input  wire  [LPARA_ROW_W-1:0]            i_rs_data,
  output logic                              o_rs_pop,
  input  wire                               i_ev_vld,
  input  wire  [1:0]                        i_ev_type,
  input  wire  [4:0]                        i_ev_q,
  input  wire  [16:0]                       i_ev_val,
  output logic                              o_ev_pop,

  // AXI4 write channels
  output logic [PARA_USB2_AXI_ID_W-1:0]     o_axim_awid,
  output logic [PARA_USB2_AXI_ADDR_W-1:0]   o_axim_awaddr,
  output logic [7:0]                        o_axim_awlen,
  output logic [2:0]                        o_axim_awsize,
  output logic [1:0]                        o_axim_awburst,
  output logic [3:0]                        o_axim_awcache,
  output logic [2:0]                        o_axim_awprot,
  output logic                              o_axim_awvalid,
  input  wire                               i_axim_awready,
  output logic [PARA_USB2_AXI_DATA_W-1:0]   o_axim_wdata,
  output logic [PARA_USB2_AXI_DATA_W/8-1:0] o_axim_wstrb,
  output logic                              o_axim_wlast,
  output logic                              o_axim_wvalid,
  input  wire                               i_axim_wready,
  input  wire  [PARA_USB2_AXI_ID_W-1:0]     i_axim_bid,
  input  wire  [1:0]                        i_axim_bresp,
  input  wire                               i_axim_bvalid,
  output logic                              o_axim_bready,

  // AXI4 read channels
  output logic [PARA_USB2_AXI_ID_W-1:0]     o_axim_arid,
  output logic [PARA_USB2_AXI_ADDR_W-1:0]   o_axim_araddr,
  output logic [7:0]                        o_axim_arlen,
  output logic [2:0]                        o_axim_arsize,
  output logic [1:0]                        o_axim_arburst,
  output logic [3:0]                        o_axim_arcache,
  output logic [2:0]                        o_axim_arprot,
  output logic                              o_axim_arvalid,
  input  wire                               i_axim_arready,
  input  wire  [PARA_USB2_AXI_ID_W-1:0]     i_axim_rid,
  input  wire  [PARA_USB2_AXI_DATA_W-1:0]   i_axim_rdata,
  input  wire  [1:0]                        i_axim_rresp,
  input  wire                               i_axim_rlast,
  input  wire                               i_axim_rvalid,
  output logic                              o_axim_rready,

  // Error pulses to the interrupt block
  output logic                              o_axi_err,
  output logic                              o_dma_err
);

  // FSM states of the receive drain (AXI write side).
  typedef enum logic [3:0] {
    ENUM_ST_R_IDLE = 4'd0,
    ENUM_ST_R_AW   = 4'd1,
    ENUM_ST_R_W    = 4'd2,
    ENUM_ST_R_B    = 4'd3,
    ENUM_ST_R_UPD  = 4'd4,
    ENUM_ST_R_POP  = 4'd5,
    ENUM_ST_R_DAR  = 4'd6,
    ENUM_ST_R_DRD  = 4'd7,
    ENUM_ST_R_WBA  = 4'd8,
    ENUM_ST_R_WBW  = 4'd9,
    ENUM_ST_R_WBB  = 4'd10
  } rx_state_type_def;

  // FSM states of the transmit fill (AXI read side).
  typedef enum logic [3:0] {
    ENUM_ST_T_IDLE = 4'd0,
    ENUM_ST_T_CRED = 4'd1,
    ENUM_ST_T_AR   = 4'd2,
    ENUM_ST_T_R    = 4'd3,
    ENUM_ST_T_CM   = 4'd4,
    ENUM_ST_T_UPD  = 4'd5,
    ENUM_ST_T_DAR  = 4'd6,
    ENUM_ST_T_DRD  = 4'd7,
    ENUM_ST_T_WBA  = 4'd8,
    ENUM_ST_T_WBW  = 4'd9,
    ENUM_ST_T_WBB  = 4'd10
  } tx_state_type_def;

  // Internal signal declarations
  rx_state_type_def                           reg_fsm_rx_current_state;
  rx_state_type_def                           w_fsm_rx_nxt_state;
  tx_state_type_def                           reg_fsm_tx_current_state;
  tx_state_type_def                           w_fsm_tx_nxt_state;
  logic [4:0]                                 reg_evq_tag [LPARA_EVQ_N];
  logic [11:0]                                reg_evq_len [LPARA_EVQ_N];
  logic [LPARA_EVQ_W-1:0]                     reg_evq_rd;
  logic [LPARA_EVQ_W-1:0]                     reg_evq_wr;
  logic [LPARA_EVQ_W:0]                       reg_evq_cnt;
  logic [LPARA_NQ-1:0][LPARA_CW-1:0]          reg_credit;
  logic [LPARA_NQ-1:0][LPARA_CW-1:0]          w_q_size;
  logic [4:0]                                 reg_r_tag;
  logic [11:0]                                reg_r_len;
  logic [16:0]                                reg_r_left;
  logic [16:0]                                reg_r_rq_left;
  logic [PARA_USB2_AXI_ADDR_W-1:0]            reg_r_addr;
  logic [8:0]                                 reg_r_nb;
  logic [8:0]                                 reg_r_beat;
  logic [2:0]                                 reg_r_outst;
  logic [31:0]                                reg_ld_addr;
  logic [PARA_USB2_NEP1-1:0]                  reg_ld_epi_we;
  logic [PARA_USB2_NEP1-1:0]                  reg_ld_epo_we;
  logic [PARA_USB2_NHC-1:0]                   reg_ld_hc_we;
  logic [PARA_USB2_NEP1-1:0]                  reg_job_i;
  logic [PARA_USB2_NHC-1:0]                   reg_job_h;
  logic [PARA_USB2_NEP1-1:0]                  reg_en_i_d;
  logic [PARA_USB2_NHC-1:0]                   reg_en_h_d;
  logic                                       reg_t_host;
  logic [4:0]                                 reg_t_idx;
  logic [4:0]                                 reg_t_q;
  logic [PARA_USB2_AXI_ADDR_W-1:0]            reg_t_addr;
  logic [18:0]                                reg_t_rem;
  logic [10:0]                                reg_t_mps;
  logic [11:0]                                reg_t_len;
  logic [16:0]                                reg_t_rows;
  logic [16:0]                                reg_t_left;
  logic                                       reg_rq_pref;
  logic                                       reg_fl_d;
  logic                                       reg_axi_err;
  logic                                       reg_dma_err;
  logic [63:0]                                w_r_base64;
  logic [63:0]                                w_t_base64;
  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_r_base;
  logic [11:0]                                w_r_len_head;
  logic [4:0]                                 w_r_tag_head;
  logic [16:0]                                w_r_rows_head;
  logic [8:0]                                 w_burst;
  logic [8:0]                                 w_r_4k;
  logic [10:0]                                w_r_4k_wide;
  logic [10:0]                                w_t_4k_wide;
  logic [8:0]                                 w_r_nb_calc;
  logic [8:0]                                 w_t_4k;
  logic [8:0]                                 w_t_nb_calc;
  logic                                       w_r_want;
  logic [2:0]                                 w_r_op;
  logic                                       w_t_want;
  logic [2:0]                                 w_t_op;
  logic                                       w_sel_t;
  logic                                       w_sel_r;
  logic                                       w_grant_t;
  logic                                       w_grant_r;
  logic [LPARA_BYTES-1:0]                     w_wstrb;
  logic [3:0]                                 w_last_bytes;
  logic                                       w_pick_vld;
  logic                                       w_pick_host;
  logic [4:0]                                 w_pick_idx;
  logic [PARA_USB2_NEP1-1:0]                  w_edge_i;
  logic [PARA_USB2_NHC-1:0]                   w_edge_h;
  logic [31:0]                                w_pick_addr;
  logic [18:0]                                w_pick_xs;
  logic [10:0]                                w_pick_mps;
  logic [4:0]                                 w_pick_q;
  logic [11:0]                                w_t_len_calc;
  logic [16:0]                                w_t_rows_calc;
  logic                                       w_rx_upd;
  logic                                       w_tx_upd;
  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_t_addr_nxt;
  logic [PARA_USB2_AXI_ADDR_W-1:0]            w_r_addr_nxt;
  logic                                       w_sg;
  logic [31:0]                                reg_r_dp;
  logic [31:0]                                reg_t_dp;
  logic [31:0]                                reg_d_w0;
  logic [7:0]                                 reg_r_dctl;
  logic [7:0]                                 reg_t_dctl;
  logic [15:0]                                reg_r_dorg;
  logic [15:0]                                reg_t_dorg;
  logic [15:0]                                w_wb_notx;
  logic                                       reg_d_beat;
  logic                                       reg_r_ovf;
  logic                                       reg_t_dv;
  logic [10:0]                                reg_t_dlen;
  logic [10:0]                                w_t_cap;
  logic [63:0]                                w_rdata64;
  logic [31:0]                                w_d_w0;
  logic [31:0]                                w_d_w1;
  logic [63:0]                                w_d_addr64;
  logic                                       w_desc_rd;
  logic                                       w_desc_last;
  logic                                       w_d_ovf;
  logic                                       w_d_rx_bad;
  logic                                       w_r_win_bad;
  logic                                       w_t_win_bad;
  logic                                       w_t_win_hit;
  logic [32:0]                                w_r_win_end;
  logic [32:0]                                w_d_win_end;
  logic [32:0]                                w_t_win_end;
  logic [31:0]                                w_t_win_start;
  logic [32:0]                                w_win_top;
  logic                                       reg_halt;
  logic                                       reg_win_err;
  logic                                       reg_t_werr;
  logic                                       w_rx_dph;
  logic                                       w_tx_dph;
  logic                                       w_rx_dph_rd;
  logic                                       w_tx_dph_rd;
  logic                                       w_rx_wb;
  logic                                       w_tx_wb;
  logic                                       w_rx_ar_busy;
  logic                                       w_tx_ar_busy;
  logic                                       w_rx_aw_busy;
  logic                                       w_tx_aw_busy;
  logic                                       w_tx_pre_ar;
  logic                                       w_tx_pre_wb;
  logic                                       w_rx_gate;
  logic                                       w_wb_a;
  logic                                       w_wb_w;
  logic                                       w_wb_b;
  logic                                       w_dar;
  logic                                       w_t_rbeat;
  logic [31:0]                                w_wb_dp;
  logic [31:0]                                w_wb_w1;
  logic [31:0]                                w_dar_dp;
  logic [63:0]                                w_wb_a64;
  logic [63:0]                                w_wb_d64;
  logic [63:0]                                w_dar64;
  logic [7:0]                                 w_wb_s8;

  // Address helpers: the high word of the buffer address is shared by all buffers.
  assign w_burst  = (i_dma_cfg[4:0] == 5'd0) ? 9'd1 : ((i_dma_cfg[4:0] > 5'd16) ? 9'd16 : {4'd0, i_dma_cfg[4:0]});

  // Head packet of the event queue: the tag, the length, its rows and the buffer address.
  assign w_r_len_head  = reg_evq_len[reg_evq_rd];
  assign w_r_tag_head  = reg_evq_tag[reg_evq_rd];
  assign w_r_rows_head = ({5'd0, w_r_len_head} + LPARA_BYTES[16:0] - 17'd1) >> LPARA_BSH;
  assign w_r_base64    = {i_dma_hi, (i_role_host ? i_hc_dma[w_r_tag_head[3:0]] : i_epo_dma[w_r_tag_head[3:0]])};
  assign w_r_base      = w_r_base64[PARA_USB2_AXI_ADDR_W-1:0];
  assign w_t_base64    = {i_dma_hi, w_pick_addr};

  // Event stream of the FIFO manager: packet events go to the queue, credits to the counters.
  assign o_ev_pop = i_ev_vld;

  assign w_r_4k_wide = 11'((13'd4096 - {1'b0, reg_r_addr[11:0]}) >> LPARA_BSH);
  assign w_t_4k_wide = 11'((13'd4096 - {1'b0, reg_t_addr[11:0]}) >> LPARA_BSH);

  // Receive burst: the CSR limit, the beats left and the beats up to the next 4 KB boundary.
  always_comb begin : p_com_rburst
    w_r_4k      = (w_r_4k_wide > 11'd16) ? 9'd16 : w_r_4k_wide[8:0];
    w_r_nb_calc = w_burst;
    if (reg_r_left < {8'd0, w_r_nb_calc})
      w_r_nb_calc = reg_r_left[8:0];
    if (w_r_4k < w_r_nb_calc)
      w_r_nb_calc = w_r_4k;
  end

  // Write strobes: the last beat of the packet keeps only the bytes that belong to the length.
  always_comb begin : p_com_wstrb
    w_last_bytes = reg_r_len[3:0] & (LPARA_BYTES[3:0] - 4'd1);
    if (w_last_bytes == 4'd0)
      w_last_bytes = LPARA_BYTES[3:0];
    w_wstrb = '1;
    if (reg_r_left == 17'd1) begin
      w_wstrb = '0;
      for (int idx = 0; idx < LPARA_BYTES; idx++) begin
        if (idx < w_last_bytes)
          w_wstrb[idx] = 1'b1;
      end
    end
  end

  // Scatter-gather mode: the build option and the CSR bit (change the bit only while idle). The two
  // engines share the AXI channels only for the descriptors: the receive drain reads a descriptor
  // on the read channels and writes it back on the write channels, the transmit fill the same. An
  // engine starts a packet only when the other one does not hold the channels; the transmit fill
  // has the priority when both start in the same cycle, and a write-back of the transmit fill
  // waits in its own state until the receive drain has finished its packet.
  assign w_sg         = (PARA_USB2_SG_EN != 32'd0) & i_sg_mode;
  assign w_rx_dph_rd  = (reg_fsm_rx_current_state == ENUM_ST_R_DRD);
  assign w_tx_dph_rd  = (reg_fsm_tx_current_state == ENUM_ST_T_DRD);
  assign w_rx_dph     = (reg_fsm_rx_current_state == ENUM_ST_R_DAR) | w_rx_dph_rd;
  assign w_tx_dph     = (reg_fsm_tx_current_state == ENUM_ST_T_DAR) | w_tx_dph_rd;
  assign w_rx_wb      = (reg_fsm_rx_current_state == ENUM_ST_R_WBA) | (reg_fsm_rx_current_state == ENUM_ST_R_WBW) |
                        (reg_fsm_rx_current_state == ENUM_ST_R_WBB);
  assign w_tx_wb      = (reg_fsm_tx_current_state == ENUM_ST_T_WBA) | (reg_fsm_tx_current_state == ENUM_ST_T_WBW) |
                        (reg_fsm_tx_current_state == ENUM_ST_T_WBB);
  assign w_rx_ar_busy = w_rx_dph;
  assign w_tx_ar_busy = (reg_fsm_tx_current_state == ENUM_ST_T_AR) | (reg_fsm_tx_current_state == ENUM_ST_T_R) |
                        w_tx_dph;
  assign w_rx_aw_busy = w_rx_dph | w_rx_wb | (reg_fsm_rx_current_state == ENUM_ST_R_AW) |
                        (reg_fsm_rx_current_state == ENUM_ST_R_W) | (reg_fsm_rx_current_state == ENUM_ST_R_B);
  assign w_tx_aw_busy = w_tx_wb;
  assign w_tx_pre_ar  = (w_fsm_tx_nxt_state == ENUM_ST_T_AR) | (w_fsm_tx_nxt_state == ENUM_ST_T_DAR);
  assign w_tx_pre_wb  = (w_fsm_tx_nxt_state == ENUM_ST_T_WBA);
  assign w_rx_gate    = ~w_tx_ar_busy & ~w_tx_pre_ar & ~w_tx_aw_busy & ~w_tx_pre_wb;

  // Descriptor read: word 0 is the buffer address, word 1 {done, overflow, ..., length}.
  assign w_rdata64   = 64'(i_axim_rdata);
  assign w_d_w0      = (PARA_USB2_AXI_DATA_W == 32'd64) ? w_rdata64[31:0] : reg_d_w0;
  assign w_d_w1      = (PARA_USB2_AXI_DATA_W == 32'd64) ? w_rdata64[63:32] : w_rdata64[31:0];
  assign w_d_addr64  = {i_dma_hi, w_d_w0};
  assign w_desc_rd   = (w_rx_dph_rd | w_tx_dph_rd) & i_axim_rvalid;
  assign w_desc_last = w_desc_rd & i_axim_rlast;
  assign w_d_ovf     = (w_d_w1[15:0] < {4'd0, reg_r_len});
  // DMA address window (REQ-IF-014, BUG-008): a buffer or a descriptor must lie between i_win_base
  // and i_win_lim (low 32 bits; the high word of every address is u2_dma_hi). The end of the
  // object is compared in 33 bits so that a wrap past the top of the word is also a violation.
  assign w_win_top   = {1'b0, i_win_lim} + 33'd1;
  assign w_r_win_end = {1'b0, w_r_base64[31:0]} + (w_sg ? 33'd8 : {21'd0, w_r_len_head});
  assign w_r_win_bad = i_win_en & ((w_r_base64[31:0] < i_win_base) | (w_r_win_end > w_win_top));
  assign w_d_win_end = {1'b0, w_d_w0} + {21'd0, reg_r_len};
  assign w_d_rx_bad  = w_d_ovf | (i_win_en & ((w_d_w0 < i_win_base) | (w_d_win_end > w_win_top)));
  assign w_t_win_start = (w_sg & ~reg_t_dv) ? reg_t_dp : reg_t_addr[31:0];
  assign w_t_win_end = {1'b0, w_t_win_start} + ((w_sg & ~reg_t_dv) ? 33'd8 : {21'd0, w_t_len_calc});
  assign w_t_win_bad = i_win_en & ((w_t_win_start < i_win_base) | (w_t_win_end > w_win_top));
  assign w_t_win_hit = (reg_fsm_tx_current_state == ENUM_ST_T_CRED) & (reg_t_rem != 19'd0) & w_t_win_bad;
  assign w_dar       = (reg_fsm_rx_current_state == ENUM_ST_R_DAR) | (reg_fsm_tx_current_state == ENUM_ST_T_DAR);
  assign w_dar_dp    = (reg_fsm_rx_current_state == ENUM_ST_R_DAR) ? reg_r_dp : reg_t_dp;
  assign w_dar64     = {i_dma_hi, w_dar_dp};

  // Descriptor write-back: the done flag and the length, one beat on the lane of word 1.
  assign w_wb_a      = (reg_fsm_rx_current_state == ENUM_ST_R_WBA) |
                       ((reg_fsm_tx_current_state == ENUM_ST_T_WBA) & ~w_rx_aw_busy);
  assign w_wb_w      = (reg_fsm_rx_current_state == ENUM_ST_R_WBW) | (reg_fsm_tx_current_state == ENUM_ST_T_WBW);
  assign w_wb_b      = (reg_fsm_rx_current_state == ENUM_ST_R_WBB) | (reg_fsm_tx_current_state == ENUM_ST_T_WBB);
  assign w_wb_dp     = w_rx_wb ? reg_r_dp : reg_t_dp;
  assign w_wb_a64    = {i_dma_hi, w_wb_dp + LPARA_DESC_OFF};
  assign w_wb_notx   = w_rx_wb ? (reg_r_ovf ? reg_r_dorg : (reg_r_dorg - {4'd0, reg_r_len})) :
                                 (reg_t_dorg - {4'd0, reg_t_len});
  assign w_wb_w1     = w_rx_wb ? {5'd0, ((w_wb_notx != 16'd0) & ~reg_r_ovf), reg_r_ovf, 1'b1, reg_r_dctl, w_wb_notx} :
                                 {5'd0, ((w_wb_notx != 16'd0) & ~reg_t_werr), reg_t_werr, 1'b1, reg_t_dctl, w_wb_notx};
  assign w_wb_d64    = (PARA_USB2_AXI_DATA_W == 32'd64) ? {w_wb_w1, 32'd0} : {32'd0, w_wb_w1};
  assign w_wb_s8     = (PARA_USB2_AXI_DATA_W == 32'd64) ? 8'hF0 : 8'h0F;

  // AXI write channels follow the state of the receive drain (and the write-backs).
  assign o_axim_awid    = '0;
  assign o_axim_awaddr  = w_wb_a ? w_wb_a64[PARA_USB2_AXI_ADDR_W-1:0] : reg_r_addr;
  assign o_axim_awlen   = w_wb_a ? 8'd0 : (w_r_nb_calc[7:0] - 8'd1);
  assign o_axim_awsize  = LPARA_BSH[2:0];
  assign o_axim_awburst = 2'b01;
  assign o_axim_awcache = i_dma_cfg[8:5];
  assign o_axim_awprot  = i_dma_cfg[11:9];
  assign o_axim_awvalid = (reg_fsm_rx_current_state == ENUM_ST_R_AW) | w_wb_a;
  assign o_axim_wdata   = w_wb_w ? w_wb_d64[PARA_USB2_AXI_DATA_W-1:0] : i_rs_data;
  assign o_axim_wstrb   = w_wb_w ? w_wb_s8[PARA_USB2_AXI_DATA_W/8-1:0] : w_wstrb;
  assign o_axim_wlast   = w_wb_w | (reg_r_beat == (reg_r_nb - 9'd1));
  assign o_axim_wvalid  = ((reg_fsm_rx_current_state == ENUM_ST_R_W) & i_rs_vld) | w_wb_w;
  assign o_rs_pop       = (reg_fsm_rx_current_state == ENUM_ST_R_W) & i_rs_vld & i_axim_wready;
  assign o_axim_bready  = (reg_fsm_rx_current_state == ENUM_ST_R_B) | w_wb_b;

  // Part 1, sequential: the state of the receive drain.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_fsm_rx
    if (!i_rst_n_bus)
      reg_fsm_rx_current_state <= ENUM_ST_R_IDLE;
    else
      reg_fsm_rx_current_state <= w_fsm_rx_nxt_state;
  end

  // Part 2, combinational: next state of the receive drain.
  always_comb begin : p_com_fsm_rx_nxt
    w_fsm_rx_nxt_state = reg_fsm_rx_current_state;
    case (reg_fsm_rx_current_state)
      ENUM_ST_R_IDLE: begin
        casez ({((reg_evq_cnt != '0) & i_dma_en & i_core_en & ~reg_halt),
                ((w_r_rows_head == 17'd0) | w_r_win_bad), w_sg, w_rx_gate})
          4'b11??: w_fsm_rx_nxt_state = ENUM_ST_R_POP;
          4'b1011: w_fsm_rx_nxt_state = ENUM_ST_R_DAR;
          4'b100?: w_fsm_rx_nxt_state = ENUM_ST_R_AW;
          default: w_fsm_rx_nxt_state = ENUM_ST_R_IDLE;
        endcase
      end
      ENUM_ST_R_DAR: begin
        if (i_axim_arready)
          w_fsm_rx_nxt_state = ENUM_ST_R_DRD;
      end
      ENUM_ST_R_DRD: begin
        if (w_desc_last)
          w_fsm_rx_nxt_state = w_d_rx_bad ? ENUM_ST_R_WBA : ENUM_ST_R_AW;
      end
      ENUM_ST_R_WBA: begin
        if (i_axim_awready)
          w_fsm_rx_nxt_state = ENUM_ST_R_WBW;
      end
      ENUM_ST_R_WBW: begin
        if (i_axim_wready)
          w_fsm_rx_nxt_state = ENUM_ST_R_WBB;
      end
      ENUM_ST_R_WBB: begin
        if (i_axim_bvalid)
          w_fsm_rx_nxt_state = ENUM_ST_R_UPD;
      end
      ENUM_ST_R_AW: begin
        if (i_axim_awready)
          w_fsm_rx_nxt_state = ENUM_ST_R_W;
      end
      ENUM_ST_R_W: begin
        if (o_rs_pop & o_axim_wlast)
          w_fsm_rx_nxt_state = ENUM_ST_R_B;
      end
      ENUM_ST_R_B: begin
        if (i_axim_bvalid)
          w_fsm_rx_nxt_state = (reg_r_left == 17'd0) ? (w_sg ? ENUM_ST_R_WBA : ENUM_ST_R_UPD) : ENUM_ST_R_AW;
      end
      ENUM_ST_R_UPD: begin
        w_fsm_rx_nxt_state = ENUM_ST_R_POP;
      end
      ENUM_ST_R_POP: begin
        if (w_grant_r)
          w_fsm_rx_nxt_state = ENUM_ST_R_IDLE;
      end
      default: w_fsm_rx_nxt_state = ENUM_ST_R_IDLE;
    endcase
  end

  // Receive drain registers: the packet in progress, beat counters and the read request counters.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_rx
    if (!i_rst_n_bus) begin
      reg_r_tag     <= 5'd0;
      reg_r_len     <= 12'd0;
      reg_r_left    <= 17'd0;
      reg_r_rq_left <= 17'd0;
      reg_r_addr    <= '0;
      reg_r_nb      <= 9'd0;
      reg_r_beat    <= 9'd0;
      reg_r_outst   <= 3'd0;
      reg_r_dp      <= 32'd0;
      reg_r_ovf     <= 1'b0;
      reg_r_dctl    <= 8'd0;
      reg_r_dorg    <= 16'd0;
    end else begin
      if ((reg_fsm_rx_current_state == ENUM_ST_R_IDLE) & (reg_evq_cnt != '0) & i_dma_en & i_core_en &
          ~reg_halt) begin
        reg_r_tag     <= w_r_tag_head;
        reg_r_len     <= w_r_len_head;
        reg_r_left    <= w_r_rows_head;
        reg_r_rq_left <= w_r_rows_head;
        reg_r_addr    <= w_r_base;
        reg_r_outst   <= 3'd0;
        reg_r_dp      <= w_r_base64[31:0];
        reg_r_ovf     <= 1'b0;
      end
      if ((reg_fsm_rx_current_state == ENUM_ST_R_DRD) & w_desc_last) begin
        reg_r_addr <= w_d_addr64[PARA_USB2_AXI_ADDR_W-1:0];
        reg_r_ovf  <= w_d_rx_bad;
        reg_r_dctl <= w_d_w1[23:16];
        reg_r_dorg <= w_d_w1[15:0];
        if (w_d_rx_bad) begin
          reg_r_left    <= 17'd0;
          reg_r_rq_left <= 17'd0;
        end
      end
      if ((reg_fsm_rx_current_state == ENUM_ST_R_WBB) & i_axim_bvalid)
        reg_r_dp <= reg_r_dp + 32'd8;
      if (reg_fsm_rx_current_state == ENUM_ST_R_AW) begin
        reg_r_nb   <= w_r_nb_calc;
        reg_r_beat <= 9'd0;
      end
      if (o_rs_pop) begin
        reg_r_beat <= reg_r_beat + 9'd1;
        reg_r_left <= reg_r_left - 17'd1;
        reg_r_addr <= reg_r_addr + (PARA_USB2_AXI_ADDR_W)'(LPARA_BYTES);
      end
      if (w_grant_r & (w_r_op == LPARA_OP_RD[2:0])) begin
        reg_r_rq_left <= reg_r_rq_left - 17'd1;
        if (!o_rs_pop)
          reg_r_outst <= reg_r_outst + 3'd1;
      end else if (o_rs_pop) begin
        reg_r_outst <= reg_r_outst - 3'd1;
      end
    end
  end

  // Descriptor beat capture: the first beat holds word 0 (the only beat on a 64-bit bus).
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_desc
    if (!i_rst_n_bus) begin
      reg_d_w0   <= 32'd0;
      reg_d_beat <= 1'b0;
    end else if (w_desc_rd) begin
      if (!reg_d_beat)
        reg_d_w0 <= i_axim_rdata[31:0];
      reg_d_beat <= ~i_axim_rlast & ~reg_d_beat;
    end
  end

  // Event queue and credit counters: a packet event is queued, a credit event adds rows to the
  // queue credit, and the transmit fill takes rows away. The credit restarts at the queue size
  // while the core is off and after a flush of the queue.
  always_comb begin : p_com_qsize
    w_q_size = '0;
    for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin
      w_q_size[idx + 1] = {1'b0, i_epi_fifo[idx][31:16]} >> LPARA_SH;
    end
    w_q_size[LPARA_HQ_NP]     = {1'b0, i_fifo_hnp[31:16]} >> LPARA_SH;
    w_q_size[LPARA_HQ_NP + 1] = {1'b0, i_fifo_hpt[31:16]} >> LPARA_SH;
  end

  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_evq
    if (!i_rst_n_bus) begin
      reg_evq_rd  <= '0;
      reg_evq_wr  <= '0;
      reg_evq_cnt <= '0;
      reg_credit  <= '0;
      reg_fl_d    <= 1'b0;
      for (int idx = 0; idx < LPARA_EVQ_N; idx++) begin
        reg_evq_tag[idx] <= 5'd0;
        reg_evq_len[idx] <= 12'd0;
      end
    end else begin
      reg_fl_d <= i_fl_tx;
      if (i_ev_vld & (i_ev_type == LPARA_EV_PKT[1:0])) begin
        reg_evq_tag[reg_evq_wr] <= i_ev_q;
        reg_evq_len[reg_evq_wr] <= i_ev_val[11:0];
        reg_evq_wr              <= reg_evq_wr + LPARA_ONE[LPARA_EVQ_W-1:0];
      end
      if ((reg_fsm_rx_current_state == ENUM_ST_R_POP) & w_grant_r)
        reg_evq_rd <= reg_evq_rd + LPARA_ONE[LPARA_EVQ_W-1:0];
      case ({(i_ev_vld & (i_ev_type == LPARA_EV_PKT[1:0])),
             ((reg_fsm_rx_current_state == ENUM_ST_R_POP) & w_grant_r)})
        2'b10:   reg_evq_cnt <= reg_evq_cnt + LPARA_ONE[LPARA_EVQ_W:0];
        2'b01:   reg_evq_cnt <= reg_evq_cnt - LPARA_ONE[LPARA_EVQ_W:0];
        default: reg_evq_cnt <= reg_evq_cnt;
      endcase
      for (int idx = 0; idx < LPARA_NQ; idx++) begin
        if (!i_core_en | (i_fl_tx & ~reg_fl_d & (i_tx_sel == idx[4:0])))
          reg_credit[idx] <= w_q_size[idx];
        else
          reg_credit[idx] <= reg_credit[idx] +
                             ((i_ev_vld & (i_ev_type == LPARA_EV_CRD[1:0]) & (i_ev_q == idx[4:0])) ?
                              i_ev_val : 17'd0) -
                             (((idx[4:0] == reg_t_q) & (reg_fsm_tx_current_state == ENUM_ST_T_UPD) &
                               ~w_rx_upd) ? reg_t_rows : 17'd0);
      end
    end
  end

  // Transmit side: the arming edge of every IN endpoint and every host OUT channel becomes a job.
  always_comb begin : p_com_edges
    w_edge_i = '0;
    w_edge_h = '0;
    for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin
      w_edge_i[idx] = i_epi_ctrl[idx][22] & ~reg_en_i_d[idx];
    end
    for (int idx = 0; idx < PARA_USB2_NHC; idx++) begin
      w_edge_h[idx] = i_hc_ctrl[idx][31] & ~reg_en_h_d[idx] & ~i_hc_ctrl[idx][15];
    end
  end

  // Job selection: the lowest armed IN endpoint, else the lowest armed host OUT channel.
  always_comb begin : p_com_pick
    w_pick_vld  = 1'b0;
    w_pick_host = 1'b0;
    w_pick_idx  = 5'd0;
    w_pick_addr = 32'd0;
    w_pick_xs   = 19'd0;
    w_pick_mps  = 11'd0;
    w_pick_q    = 5'd0;
    for (int idx = PARA_USB2_NHC - 1; idx >= 0; idx--) begin
      if (reg_job_h[idx]) begin
        w_pick_vld  = 1'b1;
        w_pick_host = 1'b1;
        w_pick_idx  = idx[4:0];
        w_pick_addr = i_hc_dma[idx];
        w_pick_xs   = i_hc_xfer[idx][18:0];
        w_pick_mps  = i_hc_ctrl[idx][10:0];
        w_pick_q    = ((i_hc_ctrl[idx][17:16] == 2'd1) | (i_hc_ctrl[idx][17:16] == 2'd3)) ?
                      (LPARA_HQ_NP[4:0] + 5'd1) : LPARA_HQ_NP[4:0];
      end
    end
    for (int idx = PARA_USB2_NEP1 - 1; idx >= 0; idx--) begin
      if (reg_job_i[idx]) begin
        w_pick_vld  = 1'b1;
        w_pick_host = 1'b0;
        w_pick_idx  = idx[4:0];
        w_pick_addr = i_epi_dma[idx];
        w_pick_xs   = i_epi_xfer[idx][18:0];
        w_pick_mps  = i_epi_ctrl[idx][10:0];
        w_pick_q    = idx[4:0] + 5'd1;
      end
    end
  end

  // Packet of the transmit fill: its length, rows and the burst limits.
  assign w_t_cap       = w_sg ? reg_t_dlen : reg_t_mps;
  assign w_t_len_calc  = (reg_t_rem > {8'd0, w_t_cap}) ? {1'b0, w_t_cap} : reg_t_rem[11:0];
  assign w_t_rbeat     = (reg_fsm_tx_current_state == ENUM_ST_T_R) & w_grant_t & i_axim_rvalid;
  assign w_t_rows_calc = ({5'd0, w_t_len_calc} + LPARA_BYTES[16:0] - 17'd1) >> LPARA_BSH;

  always_comb begin : p_com_tburst
    w_t_4k      = (w_t_4k_wide > 11'd16) ? 9'd16 : w_t_4k_wide[8:0];
    w_t_nb_calc = w_burst;
    if (reg_t_left < {8'd0, w_t_nb_calc})
      w_t_nb_calc = reg_t_left[8:0];
    if (w_t_4k < w_t_nb_calc)
      w_t_nb_calc = w_t_4k;
  end

  // AXI read channels follow the state of the transmit fill.
  assign o_axim_arid    = '0;
  assign o_axim_araddr  = w_dar ? w_dar64[PARA_USB2_AXI_ADDR_W-1:0] : reg_t_addr;
  assign o_axim_arlen   = w_dar ? LPARA_DESC_ARL[7:0] : (w_t_nb_calc[7:0] - 8'd1);
  assign o_axim_arsize  = LPARA_BSH[2:0];
  assign o_axim_arburst = 2'b01;
  assign o_axim_arcache = i_dma_cfg[8:5];
  assign o_axim_arprot  = i_dma_cfg[11:9];
  assign o_axim_arvalid = (reg_fsm_tx_current_state == ENUM_ST_T_AR) | w_dar;
  assign o_axim_rready  = ((reg_fsm_tx_current_state == ENUM_ST_T_R) & w_grant_t) | w_rx_dph_rd | w_tx_dph_rd;

  // Part 1, sequential: the state of the transmit fill.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_fsm_tx
    if (!i_rst_n_bus)
      reg_fsm_tx_current_state <= ENUM_ST_T_IDLE;
    else
      reg_fsm_tx_current_state <= w_fsm_tx_nxt_state;
  end

  // Part 2, combinational: next state of the transmit fill.
  always_comb begin : p_com_fsm_tx_nxt
    w_fsm_tx_nxt_state = reg_fsm_tx_current_state;
    case (reg_fsm_tx_current_state)
      ENUM_ST_T_IDLE: begin
        if (w_pick_vld & i_dma_en & i_core_en & ~reg_halt)
          w_fsm_tx_nxt_state = ENUM_ST_T_CRED;
      end
      ENUM_ST_T_CRED: begin
        // A window violation ends the job before any AXI access: a bad buffer of a descriptor is
        // written back with err, anything else goes back to idle.
        casez ({w_t_win_hit, (w_sg & reg_t_dv), (reg_t_rem == 19'd0), (w_sg & ~reg_t_dv),
                (reg_credit[reg_t_q] >= w_t_rows_calc), w_rx_ar_busy})
          6'b11????: w_fsm_tx_nxt_state = ENUM_ST_T_WBA;
          6'b10????: w_fsm_tx_nxt_state = ENUM_ST_T_IDLE;
          6'b0?1???: w_fsm_tx_nxt_state = ENUM_ST_T_IDLE;
          6'b0?01?0: w_fsm_tx_nxt_state = ENUM_ST_T_DAR;
          6'b0?0010: w_fsm_tx_nxt_state = ENUM_ST_T_AR;
          default:   w_fsm_tx_nxt_state = ENUM_ST_T_CRED;
        endcase
      end
      ENUM_ST_T_DAR: begin
        if (i_axim_arready)
          w_fsm_tx_nxt_state = ENUM_ST_T_DRD;
      end
      ENUM_ST_T_DRD: begin
        if (w_desc_last)
          w_fsm_tx_nxt_state = ENUM_ST_T_CRED;
      end
      ENUM_ST_T_WBA: begin
        if (i_axim_awready & ~w_rx_aw_busy)
          w_fsm_tx_nxt_state = ENUM_ST_T_WBW;
      end
      ENUM_ST_T_WBW: begin
        if (i_axim_wready)
          w_fsm_tx_nxt_state = ENUM_ST_T_WBB;
      end
      ENUM_ST_T_WBB: begin
        if (i_axim_bvalid)
          w_fsm_tx_nxt_state = ENUM_ST_T_UPD;
      end
      ENUM_ST_T_AR: begin
        if (i_axim_arready)
          w_fsm_tx_nxt_state = ENUM_ST_T_R;
      end
      ENUM_ST_T_R: begin
        if (o_axim_rready & i_axim_rvalid & i_axim_rlast)
          w_fsm_tx_nxt_state = (reg_t_left == 17'd1) ? ENUM_ST_T_CM : ENUM_ST_T_AR;
      end
      ENUM_ST_T_CM: begin
        if (w_grant_t)
          w_fsm_tx_nxt_state = w_sg ? ENUM_ST_T_WBA : ENUM_ST_T_UPD;
      end
      ENUM_ST_T_UPD: begin
        if (!w_rx_upd)
          w_fsm_tx_nxt_state = ENUM_ST_T_CRED;
      end
      default: w_fsm_tx_nxt_state = ENUM_ST_T_IDLE;
    endcase
  end

  // Transmit fill registers: the job context, the packet in progress and the arming edges.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_tx
    if (!i_rst_n_bus) begin
      reg_en_i_d <= '0;
      reg_en_h_d <= '0;
      reg_job_i  <= '0;
      reg_job_h  <= '0;
      reg_t_host <= 1'b0;
      reg_t_idx  <= 5'd0;
      reg_t_q    <= 5'd0;
      reg_t_addr <= '0;
      reg_t_rem  <= 19'd0;
      reg_t_mps  <= 11'd0;
      reg_t_len  <= 12'd0;
      reg_t_rows <= 17'd0;
      reg_t_left <= 17'd0;
      reg_t_dp   <= 32'd0;
      reg_t_dv   <= 1'b0;
      reg_t_dlen <= 11'd0;
      reg_t_dctl <= 8'd0;
      reg_t_dorg <= 16'd0;
      reg_t_werr <= 1'b0;
    end else begin
      for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin
        reg_en_i_d[idx] <= i_epi_ctrl[idx][22];
      end
      for (int idx = 0; idx < PARA_USB2_NHC; idx++) begin
        reg_en_h_d[idx] <= i_hc_ctrl[idx][31];
      end
      reg_job_i <= reg_job_i | w_edge_i;
      reg_job_h <= reg_job_h | w_edge_h;
      if ((reg_fsm_tx_current_state == ENUM_ST_T_IDLE) & w_pick_vld & i_dma_en & i_core_en & ~reg_halt) begin
        reg_t_werr <= 1'b0;
        reg_t_host <= w_pick_host;
        reg_t_idx  <= w_pick_idx;
        reg_t_q    <= w_pick_q;
        reg_t_addr <= w_t_base64[PARA_USB2_AXI_ADDR_W-1:0];
        reg_t_rem  <= w_pick_xs;
        reg_t_mps  <= w_pick_mps;
        reg_t_dp   <= w_pick_addr;
        reg_t_dv   <= 1'b0;
        if (w_pick_host)
          reg_job_h[w_pick_idx[3:0]] <= 1'b0;
        else
          reg_job_i[w_pick_idx[3:0]] <= 1'b0;
      end
      if (reg_fsm_tx_current_state == ENUM_ST_T_CRED) begin
        reg_t_len  <= w_t_len_calc;
        reg_t_rows <= w_t_rows_calc;
        reg_t_left <= w_t_rows_calc;
      end
      // Window violation of the transmit fill: nothing is sent; a descriptor buffer keeps its
      // length (nothing transferred) and is written back with err, then the job ends.
      if (w_t_win_hit) begin
        reg_t_len  <= 12'd0;
        reg_t_werr <= 1'b1;
        if (!(w_sg & reg_t_dv))
          reg_t_rem <= 19'd0;
      end
      if ((reg_fsm_tx_current_state == ENUM_ST_T_DRD) & w_desc_last) begin
        reg_t_addr <= w_d_addr64[PARA_USB2_AXI_ADDR_W-1:0];
        reg_t_dlen <= (w_d_w1[15:0] > {5'd0, reg_t_mps}) ? reg_t_mps : w_d_w1[10:0];
        reg_t_dctl <= w_d_w1[23:16];
        reg_t_dorg <= w_d_w1[15:0];
        reg_t_dv   <= 1'b1;
        if (w_d_w1[15:0] == 16'd0)
          reg_t_rem <= 19'd0;
      end
      if ((reg_fsm_tx_current_state == ENUM_ST_T_WBB) & i_axim_bvalid)
        reg_t_dp <= reg_t_dp + 32'd8;
      if ((reg_fsm_tx_current_state == ENUM_ST_T_UPD) & ~w_rx_upd)
        reg_t_dv <= 1'b0;
      if (w_t_rbeat) begin
        reg_t_left <= reg_t_left - 17'd1;
        reg_t_addr <= reg_t_addr + (PARA_USB2_AXI_ADDR_W)'(LPARA_BYTES);
      end
      if ((reg_fsm_tx_current_state == ENUM_ST_T_UPD) & ~w_rx_upd)
        reg_t_rem <= (reg_t_werr | (reg_t_rem <= {7'd0, reg_t_len})) ? 19'd0 : (reg_t_rem - {7'd0, reg_t_len});
    end
  end

  // Bus port request arbitration: the transmit fill writes rows and commits, the receive drain
  // reads rows and releases packets; the two take turns when both ask.
  always_comb begin : p_com_rq
    w_r_want = 1'b0;
    w_r_op   = LPARA_OP_RD[2:0];
    w_t_want = 1'b0;
    w_t_op   = LPARA_OP_WR[2:0];
    if (reg_fsm_rx_current_state == ENUM_ST_R_POP) begin
      w_r_want = 1'b1;
      w_r_op   = LPARA_OP_POP[2:0];
    end else if ((reg_fsm_rx_current_state != ENUM_ST_R_IDLE) & ~w_rx_dph & (reg_r_rq_left != 17'd0) &
                 (reg_r_outst < LPARA_OUTST_MAX[2:0])) begin
      w_r_want = 1'b1;
    end
    if (reg_fsm_tx_current_state == ENUM_ST_T_CM) begin
      w_t_want = 1'b1;
      w_t_op   = LPARA_OP_COMMIT[2:0];
    end else if ((reg_fsm_tx_current_state == ENUM_ST_T_R) & i_axim_rvalid) begin
      w_t_want = 1'b1;
    end
  end

  assign w_sel_t   = w_t_want & (~w_r_want | reg_rq_pref);
  assign w_sel_r   = w_r_want & ~w_sel_t;
  assign w_grant_t = w_sel_t & i_rq_rdy;
  assign w_grant_r = w_sel_r & i_rq_rdy;
  assign o_rq_vld  = w_sel_t | w_sel_r;
  assign o_rq_op   = w_sel_t ? w_t_op : w_r_op;
  assign o_rq_q    = w_sel_t ? reg_t_q : reg_r_tag;
  assign o_rq_data = i_axim_rdata;

  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_pref
    if (!i_rst_n_bus)
      reg_rq_pref <= 1'b0;
    else if (w_grant_t)
      reg_rq_pref <= 1'b0;
    else if (w_grant_r)
      reg_rq_pref <= 1'b1;
  end

  // Buffer address updates: the receive drain has priority; the new address is the old address
  // moved by the padded size of the packet.
  assign w_rx_upd     = (reg_fsm_rx_current_state == ENUM_ST_R_UPD);
  assign w_tx_upd     = (reg_fsm_tx_current_state == ENUM_ST_T_UPD) & ~w_rx_upd;
  assign w_r_addr_nxt = reg_r_addr;
  assign w_t_addr_nxt = reg_t_addr;

  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_ld
    if (!i_rst_n_bus) begin
      reg_ld_addr   <= 32'd0;
      reg_ld_epi_we <= '0;
      reg_ld_epo_we <= '0;
      reg_ld_hc_we  <= '0;
    end else begin
      reg_ld_epi_we <= '0;
      reg_ld_epo_we <= '0;
      reg_ld_hc_we  <= '0;
      if (w_rx_upd) begin
        reg_ld_addr <= w_sg ? reg_r_dp : w_r_addr_nxt[31:0];
        if (i_role_host)
          reg_ld_hc_we[reg_r_tag[3:0]] <= 1'b1;
        else
          reg_ld_epo_we[reg_r_tag[3:0]] <= 1'b1;
      end else if (w_tx_upd) begin
        reg_ld_addr <= w_sg ? reg_t_dp : w_t_addr_nxt[31:0];
        if (reg_t_host)
          reg_ld_hc_we[reg_t_idx[3:0]] <= 1'b1;
        else
          reg_ld_epi_we[reg_t_idx[3:0]] <= 1'b1;
      end
    end
  end

  assign o_ld_addr   = reg_ld_addr;
  assign o_ld_epi_we = reg_ld_epi_we;
  assign o_ld_epo_we = reg_ld_epo_we;
  assign o_ld_hc_we  = reg_ld_hc_we;

  // Errors: a non-OKAY write response or read beat is an AXI error and stops the engine through
  // the interrupt (the error is reported once per response).
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_err
    if (!i_rst_n_bus) begin
      reg_axi_err <= 1'b0;
      reg_dma_err <= 1'b0;
      reg_win_err <= 1'b0;
      reg_halt    <= 1'b0;
    end else begin
      reg_axi_err <= (i_axim_bvalid & o_axim_bready & (i_axim_bresp != 2'b00)) |
                     (i_axim_rvalid & o_axim_rready & (i_axim_rresp != 2'b00));
      // Window violation of the receive drain (packet dropped at the pick) or of the transmit fill.
      reg_win_err <= ((reg_fsm_rx_current_state == ENUM_ST_R_IDLE) & (reg_evq_cnt != '0) & i_dma_en &
                      i_core_en & ~reg_halt & (w_r_rows_head != 17'd0) & w_r_win_bad) | w_t_win_hit;
      reg_dma_err <= reg_axi_err | reg_win_err |
                     ((reg_fsm_rx_current_state == ENUM_ST_R_DRD) & w_desc_last & w_d_rx_bad);
      // With ahb_err_stop = 1 an AXI error stops the DMA: no new packet is started until software
      // clears dma_en (ERR-007, BUG-009). The packet in progress is finished.
      if (!i_dma_en)
        reg_halt <= 1'b0;
      else if (reg_axi_err & i_err_stop)
        reg_halt <= 1'b1;
    end
  end

  assign o_axi_err = reg_axi_err;
  assign o_dma_err = reg_dma_err;

endmodule
