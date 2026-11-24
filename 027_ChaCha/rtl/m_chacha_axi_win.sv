/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : AXI4 subordinate of the data window (section 6.3). A write burst feeds the input
 *                buffer, a read burst drains the output buffer; the address bits inside the
 *                window are ignored. A burst is served only when its transfer size is the full
 *                data width, its type is INCR, its length is at most min(256, 4096 / W) beats, it
 *                does not cross a 4 KB boundary and (with i_protect_en) AxPROT[1] is 0; a write
 *                burst also needs an active message and the byte strobes of every beat must equal
 *                the expected pattern of the stream layout (each part on a new beat, low lanes
 *                valid). Otherwise the burst gets SLVERR: a write burst is drained and gets one
 *                BRESP, a read burst returns every transfer with zero data and SLVERR. A read
 *                that finds the output buffer empty returns SLVERR with zero data for that
 *                transfer. At most one write and one read burst are outstanding. An error
 *                response raises a one-cycle event.
 *                With PARA_PIPE_IO = 1 the last-beat flag of the part tracker is computed in the
 *                cycle before it is used and kept in a register; behavior and cycle count do not
 *                change (DEC-036).
 * Decisions    : DEC-014, DEC-016, DEC-021, DEC-022, DEC-036, ASM-011
 */
`timescale 1ns/1ps

module m_chacha_axi_win #(
  // Parameter Description: data width of the window beat; a beat is PARA_AXI_DW / 8 bytes.
  // Parameter values: 32, 64, 128 or 256; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 32'd64,
  // Parameter Description: width of the AXI4 address.
  // Parameter values: 12 to 32; default is 12.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_AW = 32'd12,
  // Parameter Description: width of the AXI4 identifiers.
  // Parameter values: 1 to 16; default is 4.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_IDW = 32'd4,
  // Parameter Description: 1 computes the remaining-byte flags one cycle ahead and registers them.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_IO = 32'd0,
  localparam logic [31:0] LPARA_BYTES   = PARA_AXI_DW / 32'd8,
  localparam logic [31:0] LPARA_BYTE_LG = $clog2(LPARA_BYTES),
  localparam logic [31:0] LPARA_BMAX_RAW = 32'd4096 / LPARA_BYTES,
  localparam logic [31:0] LPARA_BMAX    = (LPARA_BMAX_RAW > 32'd256) ? 32'd256 : LPARA_BMAX_RAW,
  localparam logic [31:0] LPARA_RESP_OKAY   = 32'd0,
  localparam logic [31:0] LPARA_RESP_SLVERR = 32'd2,
  localparam logic [31:0] LPARA_BURST_INCR  = 32'd1
) (
  // AXI clock and reset
  input  wire                      i_clk_axi,
  input  wire                      i_rst_n_axi,

  // AXI4 write address channel
  input  wire  [PARA_AXI_IDW-1:0]  i_axi_awid,
  input  wire  [PARA_AXI_AW-1:0]   i_axi_awaddr,
  input  wire  [7:0]               i_axi_awlen,
  input  wire  [2:0]               i_axi_awsize,
  input  wire  [1:0]               i_axi_awburst,
  input  wire  [2:0]               i_axi_awprot,
  input  wire                      i_axi_awvalid,
  output logic                     o_axi_awready,

  // AXI4 write data channel
  input  wire  [PARA_AXI_DW-1:0]   i_axi_wdata,
  input  wire  [PARA_AXI_DW/8-1:0] i_axi_wstrb,
  input  wire                      i_axi_wlast,
  input  wire                      i_axi_wvalid,
  output logic                     o_axi_wready,

  // AXI4 write response channel
  output logic [PARA_AXI_IDW-1:0]  o_axi_bid,
  output logic [1:0]               o_axi_bresp,
  output logic                     o_axi_bvalid,
  input  wire                      i_axi_bready,

  // AXI4 read address channel
  input  wire  [PARA_AXI_IDW-1:0]  i_axi_arid,
  input  wire  [PARA_AXI_AW-1:0]   i_axi_araddr,
  input  wire  [7:0]               i_axi_arlen,
  input  wire  [2:0]               i_axi_arsize,
  input  wire  [1:0]               i_axi_arburst,
  input  wire  [2:0]               i_axi_arprot,
  input  wire                      i_axi_arvalid,
  output logic                     o_axi_arready,

  // AXI4 read data channel
  output logic [PARA_AXI_IDW-1:0]  o_axi_rid,
  output logic [PARA_AXI_DW-1:0]   o_axi_rdata,
  output logic [1:0]               o_axi_rresp,
  output logic                     o_axi_rlast,
  output logic                     o_axi_rvalid,
  input  wire                      i_axi_rready,

  // Protection check enable (static)
  input  wire                      i_protect_en,

  // Message description in CLK-AXI: start pulse, active level, lengths and direction
  input  wire                      i_start,
  input  wire                      i_act,
  input  wire  [15:0]              i_aad_len,
  input  wire  [15:0]              i_msg_len,
  input  wire                      i_dir,

  // Input buffer write port and output buffer read port
  output logic                     o_in_wr_en,
  output logic [PARA_AXI_DW-1:0]   o_in_wr_data,
  input  wire                      i_in_full,
  output logic                     o_out_rd_en,
  input  wire  [PARA_AXI_DW-1:0]   i_out_rd_data,
  input  wire                      i_out_empty,

  // Error event (one-cycle pulse)
  output logic                     o_err_evt
);

  // Part kinds of the input stream: associated data, message data, tag (decryption).
  typedef enum logic [1:0] {
    ENUM_KIND_AAD = 2'd0,
    ENUM_KIND_MSG = 2'd1,
    ENUM_KIND_TAG = 2'd2
  } kind_type_def;

  // Internal signal declarations: write path
  logic                           reg_w_open;
  logic                           reg_w_bad;
  logic [PARA_AXI_IDW-1:0]        reg_w_id;
  logic                           reg_bvalid;
  logic                           reg_bresp_err;
  kind_type_def                   reg_wp_kind;
  logic [16:0]                    reg_wp_rem;
  logic                           reg_wp_end;
  logic [16:0]                    w_start_len;
  logic                           w_wp_end;
  logic                           reg_wp_vld;
  logic [15:0]                    reg_len_msg;
  logic                           reg_dir;
  logic                           w_aw_fire;
  logic                           w_aw_bad;
  logic                           w_w_fire;
  logic                           w_w_good;
  logic [6:0]                     w_vb;
  logic [PARA_AXI_DW/8-1:0]       w_exp_strb;
  logic                           w_strb_ok;
  logic [16:0]                    w_wp_rem_nxt;
  kind_type_def                   w_nx_kind;
  logic [16:0]                    w_nx_len;
  logic                           w_nx_vld;
  logic [13:0]                    w_aw_end;
  logic [13:0]                    w_ar_end;
  // Internal signal declarations: read path
  logic                           reg_r_open;
  logic                           reg_r_bad;
  logic [PARA_AXI_IDW-1:0]        reg_r_id;
  logic [8:0]                     reg_r_left;
  logic                           reg_rvalid;
  logic [PARA_AXI_DW-1:0]         reg_rdata;
  logic                           reg_rresp_err;
  logic                           reg_rlast;
  logic                           reg_r_err_seen;
  logic                           reg_err_evt;
  logic                           w_err_evt;
  logic                           w_ar_fire;
  logic                           w_ar_bad;
  logic                           w_r_load;
  logic                           w_r_ok;

  // Write address check: transfer size, burst type, burst length, 4 KB boundary, protection and
  // an active message. The end address is the low 12 bits of the start plus len * W bytes.
  assign w_aw_end = $bits(w_aw_end)'({2'b00, i_axi_awaddr[11:0]} +
                    $bits(w_aw_end)'(({6'd0, i_axi_awlen} + 14'd1) << LPARA_BYTE_LG));
  assign w_aw_bad = (i_axi_awsize != 3'(LPARA_BYTE_LG)) | (i_axi_awburst != 2'(LPARA_BURST_INCR)) |
                    ({1'b0, i_axi_awlen} + 9'd1 > 9'(LPARA_BMAX)) | (w_aw_end > 14'd4096) |
                    (i_protect_en & i_axi_awprot[1]) | ~i_act;
  assign w_aw_fire = i_axi_awvalid & o_axi_awready;
  assign o_axi_awready = ~reg_w_open & ~reg_bvalid;

  // Write data: ready while a burst is open. A bad burst is drained; a good burst needs room in
  // the input buffer. A beat is written when the strobes match the expected pattern and a part
  // is left.
  assign o_axi_wready = reg_w_open & (reg_w_bad | ~i_in_full);
  assign w_w_fire     = i_axi_wvalid & o_axi_wready;

  // Expected beat of the stream: valid bytes are W or the rest of the part; the strobe pattern is
  // the low valid lanes set (little-endian lane order).
  assign w_vb = (PARA_PIPE_IO == 32'd1) ? (reg_wp_end ? reg_wp_rem[6:0] : 7'(LPARA_BYTES)) :
                ((reg_wp_rem >= 17'(LPARA_BYTES)) ? 7'(LPARA_BYTES) : reg_wp_rem[6:0]);
  always_comb begin : p_com_strb
    w_exp_strb = '0;
    for (int idx = 0; idx < PARA_AXI_DW/8; idx++) begin
      if (7'(idx) < w_vb)
        w_exp_strb[idx] = 1'b1;
    end
  end
  assign w_strb_ok    = reg_wp_vld & (i_axi_wstrb == w_exp_strb);
  assign w_w_good     = w_w_fire & ~reg_w_bad & w_strb_ok;
  assign w_wp_rem_nxt = $bits(w_wp_rem_nxt)'(reg_wp_rem - 17'(w_vb));
  assign w_wp_end     = (PARA_PIPE_IO == 32'd1) ? reg_wp_end : (w_wp_rem_nxt == 17'd0);

  // Length of the first part of a message: associated data, else message data, else the tag.
  assign w_start_len  = (i_aad_len != 16'd0) ? {1'b0, i_aad_len} :
                        (i_msg_len != 16'd0) ? {1'b0, i_msg_len} : 17'd16;
  assign o_in_wr_en   = w_w_good;

  // Written data: the lanes beyond the valid bytes are forced to zero.
  always_comb begin : p_com_wdata
    o_in_wr_data = '0;
    for (int idx = 0; idx < PARA_AXI_DW/8; idx++) begin
      if (w_exp_strb[idx])
        o_in_wr_data[8*idx +: 8] = i_axi_wdata[8*idx +: 8];
    end
  end

  // Next part of the stream after the current one, as in the input stream adapter.
  always_comb begin : p_com_nxt
    w_nx_kind = ENUM_KIND_TAG;
    w_nx_len  = 17'd16;
    w_nx_vld  = 1'b0;
    case (reg_wp_kind)
      ENUM_KIND_AAD: begin
        w_nx_kind = ENUM_KIND_TAG;
        w_nx_len  = 17'd16;
        w_nx_vld  = reg_dir;
        if (reg_len_msg != 16'd0) begin
          w_nx_kind = ENUM_KIND_MSG;
          w_nx_len  = {1'b0, reg_len_msg};
          w_nx_vld  = 1'b1;
        end
      end
      ENUM_KIND_MSG: begin
        w_nx_kind = ENUM_KIND_TAG;
        w_nx_len  = 17'd16;
        w_nx_vld  = reg_dir;
      end
      default: begin
        w_nx_kind = ENUM_KIND_TAG;
        w_nx_len  = 17'd16;
        w_nx_vld  = 1'b0;
      end
    endcase
  end

  // Write burst control: open at an address handshake, close with the last data beat; the flag of
  // a bad burst is set at the address handshake or by a bad beat (wrong strobes or no part left);
  // the response is valid until accepted.
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_wr
    if (!i_rst_n_axi) begin
      reg_w_open    <= 1'b0;
      reg_w_bad     <= 1'b0;
      reg_w_id      <= '0;
      reg_bvalid    <= 1'b0;
      reg_bresp_err <= 1'b0;
    end else begin
      if (w_aw_fire) begin
        reg_w_open <= 1'b1;
        reg_w_bad  <= w_aw_bad;
        reg_w_id   <= i_axi_awid;
      end
      if (w_w_fire & ~reg_w_bad & ~w_strb_ok)
        reg_w_bad <= 1'b1;
      if (w_w_fire & i_axi_wlast) begin
        reg_w_open    <= 1'b0;
        reg_bvalid    <= 1'b1;
        reg_bresp_err <= reg_w_bad | ~w_strb_ok;
      end
      if (reg_bvalid & i_axi_bready)
        reg_bvalid <= 1'b0;
    end
  end

  // Part tracker for the expected strobes: a start loads the first part (associated data, else
  // message data, else the tag of a decryption); every written beat reduces the remaining bytes
  // of the part, and the last beat of a part loads the next one or ends the stream.
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_part
    if (!i_rst_n_axi) begin
      reg_wp_kind <= ENUM_KIND_AAD;
      reg_wp_rem  <= 17'd0;
      reg_wp_end  <= 1'b1;
      reg_wp_vld  <= 1'b0;
      reg_len_msg <= 16'd0;
      reg_dir     <= 1'b0;
    end else begin
      casez ({i_start, w_w_good, w_wp_end})
        3'b1??: begin
          reg_len_msg <= i_msg_len;
          reg_dir     <= i_dir;
          reg_wp_kind <= ENUM_KIND_AAD;
          reg_wp_rem  <= {1'b0, i_aad_len};
          reg_wp_end  <= (w_start_len < 17'(LPARA_BYTES + 32'd1));
          reg_wp_vld  <= (i_aad_len != 16'd0) | (i_msg_len != 16'd0) | i_dir;
          if (i_aad_len == 16'd0) begin
            reg_wp_kind <= ENUM_KIND_MSG;
            reg_wp_rem  <= {1'b0, i_msg_len};
            if (i_msg_len == 16'd0) begin
              reg_wp_kind <= ENUM_KIND_TAG;
              reg_wp_rem  <= 17'd16;
            end
          end
        end
        3'b011: begin
          reg_wp_kind <= w_nx_kind;
          reg_wp_rem  <= w_nx_len;
          reg_wp_end  <= (w_nx_len < 17'(LPARA_BYTES + 32'd1));
          reg_wp_vld  <= w_nx_vld;
        end
        3'b010: begin
          reg_wp_rem <= w_wp_rem_nxt;
          reg_wp_end <= (reg_wp_rem < 17'(2 * LPARA_BYTES + 32'd1));
        end
        default: begin
          // No start and no good beat: the tracker holds.
        end
      endcase
    end
  end

  // Write channel outputs.
  assign o_axi_bid    = reg_w_id;
  assign o_axi_bvalid = reg_bvalid;
  assign o_axi_bresp  = reg_bresp_err ? 2'(LPARA_RESP_SLVERR) : 2'(LPARA_RESP_OKAY);

  // Read address check: transfer size, burst type, burst length, 4 KB boundary and protection. A
  // read does not need an active message: results stay readable after the message ends.
  assign w_ar_end = $bits(w_ar_end)'({2'b00, i_axi_araddr[11:0]} +
                    $bits(w_ar_end)'(({6'd0, i_axi_arlen} + 14'd1) << LPARA_BYTE_LG));
  assign w_ar_bad = (i_axi_arsize != 3'(LPARA_BYTE_LG)) | (i_axi_arburst != 2'(LPARA_BURST_INCR)) |
                    ({1'b0, i_axi_arlen} + 9'd1 > 9'(LPARA_BMAX)) | (w_ar_end > 14'd4096) |
                    (i_protect_en & i_axi_arprot[1]);
  assign w_ar_fire     = i_axi_arvalid & o_axi_arready;
  assign o_axi_arready = ~reg_r_open;

  // Read transfers: a transfer is loaded into the response register when the burst is open, beats
  // are left and the register is free or being accepted. A served transfer pops the buffer; an
  // empty buffer or a bad burst gives zero data with SLVERR.
  assign w_r_load    = reg_r_open & (reg_r_left != 9'd0) & (~reg_rvalid | i_axi_rready);
  assign w_r_ok      = ~reg_r_bad & ~i_out_empty;
  assign o_out_rd_en = w_r_load & w_r_ok;

  // Read burst control and response register.
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_rd
    if (!i_rst_n_axi) begin
      reg_r_open     <= 1'b0;
      reg_r_bad      <= 1'b0;
      reg_r_id       <= '0;
      reg_r_left     <= 9'd0;
      reg_rvalid     <= 1'b0;
      reg_rresp_err  <= 1'b0;
      reg_rlast      <= 1'b0;
      reg_r_err_seen <= 1'b0;
    end else begin
      if (w_ar_fire) begin
        reg_r_open     <= 1'b1;
        reg_r_bad      <= w_ar_bad;
        reg_r_id       <= i_axi_arid;
        reg_r_left     <= {1'b0, i_axi_arlen} + 9'd1;
        reg_r_err_seen <= 1'b0;
      end
      if (w_r_load) begin
        reg_rvalid    <= 1'b1;
        reg_rresp_err <= ~w_r_ok;
        reg_rlast     <= (reg_r_left == 9'd1);
        reg_r_left    <= $bits(reg_r_left)'(reg_r_left - 9'd1);
        if (~w_r_ok)
          reg_r_err_seen <= 1'b1;
      end else if (reg_rvalid & i_axi_rready)
        reg_rvalid <= 1'b0;
      if (reg_rvalid & i_axi_rready & reg_rlast)
        reg_r_open <= 1'b0;
    end
  end

  // Read data register: no reset; the valid flag qualifies it.
  always_ff @(posedge i_clk_axi) begin : p_ff_rdata
    if (w_r_load)
      reg_rdata <= w_r_ok ? i_out_rd_data : '0;
  end

  // Read channel outputs.
  assign o_axi_rid    = reg_r_id;
  assign o_axi_rdata  = reg_rdata;
  assign o_axi_rresp  = reg_rresp_err ? 2'(LPARA_RESP_SLVERR) : 2'(LPARA_RESP_OKAY);
  assign o_axi_rlast  = reg_rlast;
  assign o_axi_rvalid = reg_rvalid;

  // Error event: one pulse when a write response with SLVERR is issued and one pulse at the first
  // SLVERR transfer of a read burst.
  assign w_err_evt = (w_w_fire & i_axi_wlast & (reg_w_bad | ~w_strb_ok)) |
                     (w_r_load & ~w_r_ok & ~reg_r_err_seen);

  // The event is registered before it crosses into CLK-CORE (rule CLK-01).
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_err_evt
    if (!i_rst_n_axi)
      reg_err_evt <= 1'b0;
    else
      reg_err_evt <= w_err_evt;
  end
  assign o_err_evt = reg_err_evt;

endmodule
