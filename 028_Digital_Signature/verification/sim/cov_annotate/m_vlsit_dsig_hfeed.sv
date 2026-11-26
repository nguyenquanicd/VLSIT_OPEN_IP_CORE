//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-24
         * Description  : Hash job feeder used by the engines of the digital signature IP (OP-008). One
         *                go pulse computes Hash(head || tail): the head is a byte vector given by the
         *                engine (byte 0 in bits [7:0], up to PARA_HEAD_BYTES bytes), the tail is a byte
         *                string of any length that starts at any byte address of a read source (the
         *                message in the buffer or a local memory; 64-bit words, read data one cycle
         *                after the request). The feeder asks the hash arbiter for the sequencer, streams
         *                head and tail as words of 1 to 8 bytes (the sequencer joins the bytes of
         *                consecutive words), and collects the first o_dlen bytes of the output in
         *                o_digest (byte 0 in bits [7:0]). o_done is a one-cycle pulse; the request to
         *                the arbiter is dropped when the job is complete. The tail read address is a
         *                byte address; the source returns the aligned word that contains it. The feeder
         *                does not need a packer: the sequencer accepts words of any size. Requirements:
         *                OP-008, section 10.4.
         */
        `timescale 1ns/1ps
        
        module m_vlsit_dsig_hfeed #(
          // Parameter Description: largest head in bytes.
          // Parameter values: 8 to 256, a multiple of 8; default is 128.
          // Parameter unit: byte
          parameter logic [31:0] PARA_HEAD_BYTES = 128,
          // Parameter Description: largest digest collected in bytes.
          // Parameter values: 8 to 128, a multiple of 8; default is 64.
          // Parameter unit: byte
          parameter logic [31:0] PARA_DIG_BYTES = 64,
          // Parameter Description: width of the tail byte address.
          // Parameter values: 8 to 32; default is 24.
          // Parameter unit: bit
          parameter logic [31:0] PARA_TA_W = 24,
          // Parameter Description: largest mid segment in bytes (sent between the two tails).
          // Parameter values: 8 to 256, a multiple of 8; default is 8.
          // Parameter unit: byte
          parameter logic [31:0] PARA_MID_BYTES = 8
        ) (
          // Clock, reset and clearing
          input  wire                          i_clk_core,
          input  wire                          i_rst_n_core,
          input  wire                          i_clr,
        
          // Job
          input  wire                          i_go,
          input  wire  [3:0]                   i_mode,
          input  wire  [15:0]                  i_outlen,
          input  wire  [8*PARA_HEAD_BYTES-1:0] i_head,
          input  wire  [8:0]                   i_head_len,
          input  wire  [PARA_TA_W-1:0]         i_tail_addr,
          input  wire  [PARA_TA_W-1:0]         i_tail_len,
          input  wire  [PARA_TA_W-1:0]         i_tail2_addr,
          input  wire  [PARA_TA_W-1:0]         i_tail2_len,
          input  wire  [8*PARA_MID_BYTES-1:0]  i_mid,
          input  wire  [8:0]                   i_mid_len,
        
          // Result
          output logic [8*PARA_DIG_BYTES-1:0]  o_digest,
          output logic                         o_done,
          output logic                         o_busy,
        
          // Tail read source
          output logic                         o_tr_en,
          output logic [PARA_TA_W-4:0]         o_tr_addr,
          input  wire  [63:0]                  i_tr_data,
          input  wire                          i_tr_valid,
        
          // Hash arbiter side
          output logic                         o_hs_req,
          input  wire                          i_hs_grant,
          output logic                         o_hs_start,
          output logic [3:0]                   o_hs_mode,
          output logic [15:0]                  o_hs_outlen,
          output logic                         o_hs_in_valid,
          output logic [63:0]                  o_hs_in_data,
          output logic [3:0]                   o_hs_in_nb,
          output logic                         o_hs_in_last,
          input  wire                          i_hs_in_ready,
          input  wire                          i_hs_out_valid,
          input  wire  [63:0]                  i_hs_out_data,
          input  wire  [3:0]                   i_hs_out_nb,
          input  wire                          i_hs_out_last,
          output logic                         o_hs_out_ready
        );
        
          // States
          typedef enum logic [3:0] {
            ENUM_ST_IDLE  = 4'd0,
            ENUM_ST_GRANT = 4'd1,
            ENUM_ST_START = 4'd2,
            ENUM_ST_HEAD  = 4'd3,
            ENUM_ST_TRD   = 4'd4,
            ENUM_ST_TWT   = 4'd5,
            ENUM_ST_TSND  = 4'd6,
            ENUM_ST_OUT   = 4'd7,
            ENUM_ST_DONE  = 4'd8,
            ENUM_ST_MID   = 4'd9
          } hfeed_state_type_def;
        
          // Internal signal declarations
          hfeed_state_type_def reg_fsm_hfeed_current_state;
          hfeed_state_type_def w_fsm_hfeed_nxt_state;
        
          logic [3:0]                    reg_mode;
          logic [15:0]                   reg_outlen;
          logic [8*PARA_HEAD_BYTES-1:0]  reg_head;
          logic [8:0]                    reg_head_left;
          logic [8*PARA_MID_BYTES-1:0]   reg_mid;
          logic [8:0]                    reg_mid_left;
          logic [PARA_TA_W-1:0]          reg_tail_left;
          logic [PARA_TA_W-1:0]          reg_tail2_left;
          logic [PARA_TA_W-1:0]          reg_tail2_addr;
          logic [PARA_TA_W-4:0]          reg_tword;
          logic [2:0]                    reg_toff;
          logic [63:0]                   reg_tprev;
          logic                          reg_tprev_v;
          logic [63:0]                   reg_tcur;
          logic [8*PARA_DIG_BYTES-1:0]   reg_digest;
          logic [15:0]                   reg_dcnt;
          logic [63:0]                   w_tword;
          logic [3:0]                    w_tnb;
          logic                          w_tlast;
          logic                          w_tlast_all;
          logic [63:0]                   w_hword;
          logic [3:0]                    w_hnb;
          logic                          w_hlast;
          logic                          w_head_only;
          logic                          w_tail2_pend;
          logic                          w_mid_pend;
          logic [63:0]                   w_mword;
          logic [3:0]                    w_mnb;
          logic                          w_mlast;
        
          // Head word: the next up to 8 head bytes; it is the last word when no tail follows.
          assign w_tail2_pend = (reg_tail2_left != '0);
          assign w_mid_pend   = (reg_mid_left != 9'd0);
          assign w_head_only  = (reg_tail_left == '0) & ~w_tail2_pend & ~w_mid_pend;
~132377665   assign w_mnb        = (reg_mid_left > 9'd8) ? 4'd8 : reg_mid_left[3:0];
          assign w_mword      = reg_mid[63:0];
          assign w_mlast      = (reg_mid_left <= 9'd8) & ~w_tail2_pend;
~126584219   assign w_hnb       = (reg_head_left > 9'd8) ? 4'd8 : reg_head_left[3:0];
          assign w_hword     = reg_head[63:0];
          assign w_hlast     = w_head_only & (reg_head_left <= 9'd8);
        
          // Tail word: bytes from the byte address, joined from two aligned words if not aligned.
 132377765   always_comb begin : p_com_tword
 132377765     w_tword = reg_tcur;
~132377750     if (reg_toff != 3'd0)
~085035       w_tword = (reg_tprev >> {reg_toff, 3'b000}) | (reg_tcur << {(3'd0 - reg_toff), 3'b000});
~132377765     w_tnb   = (reg_tail_left > {{(PARA_TA_W-4){1'b0}}, 4'd8}) ? 4'd8 : reg_tail_left[3:0];
 132377765     w_tlast = (reg_tail_left <= {{(PARA_TA_W-4){1'b0}}, 4'd8});
 132377765     w_tlast_all = w_tlast & ~w_tail2_pend & ~w_mid_pend;
          end
        
          assign o_busy         = (reg_fsm_hfeed_current_state != ENUM_ST_IDLE);
          assign o_hs_req       = (reg_fsm_hfeed_current_state != ENUM_ST_IDLE) & (reg_fsm_hfeed_current_state != ENUM_ST_DONE);
          assign o_hs_start     = (reg_fsm_hfeed_current_state == ENUM_ST_START);
          assign o_hs_mode      = reg_mode;
          assign o_hs_outlen    = reg_outlen;
          assign o_hs_out_ready = (reg_fsm_hfeed_current_state == ENUM_ST_OUT);
          assign o_done         = (reg_fsm_hfeed_current_state == ENUM_ST_DONE);
          assign o_digest       = reg_digest;
          assign o_tr_en        = (reg_fsm_hfeed_current_state == ENUM_ST_TRD);
          assign o_tr_addr      = reg_tword;
        
          // Hash input word.
 132377765   always_comb begin : p_com_in
 132377765     o_hs_in_valid = 1'b0;
 132377765     o_hs_in_data  = 64'd0;
 132377765     o_hs_in_nb    = 4'd0;
 132377765     o_hs_in_last  = 1'b0;
 132377765     case (reg_fsm_hfeed_current_state)
~5557336       ENUM_ST_HEAD: begin
~5557336         o_hs_in_valid = 1'b1;
~5557336         o_hs_in_data  = w_hword;
~5557336         o_hs_in_nb    = w_hnb;
~5557336         o_hs_in_last  = w_hlast;
              end
~017023       ENUM_ST_MID: begin
~017023         o_hs_in_valid = 1'b1;
~017023         o_hs_in_data  = w_mword;
~017023         o_hs_in_nb    = w_mnb;
~017023         o_hs_in_last  = w_mlast;
              end
~207995       ENUM_ST_TSND: begin
~207995         o_hs_in_valid = 1'b1;
~207995         o_hs_in_data  = w_tword;
~207995         o_hs_in_nb    = w_tnb;
~207995         o_hs_in_last  = w_tlast_all;
              end
 126612418       default: begin
 126612418         o_hs_in_valid = 1'b0;
              end
            endcase
          end
        
          // Part 1 of the FSM: state register.
 132377761   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_hfeed
 132377737     if (!i_rst_n_core)
 000024       reg_fsm_hfeed_current_state <= ENUM_ST_IDLE;
            else
 132377737       reg_fsm_hfeed_current_state <= w_fsm_hfeed_nxt_state;
          end
        
          // Part 2 of the FSM: next state.
 132377765   always_comb begin : p_com_fsm_nxt
 132377765     w_fsm_hfeed_nxt_state = reg_fsm_hfeed_current_state;
 132377765     case (reg_fsm_hfeed_current_state)
 119044729       ENUM_ST_IDLE: begin
~118926129         if (i_go)
~118600           w_fsm_hfeed_nxt_state = ENUM_ST_GRANT;
              end
~237200       ENUM_ST_GRANT: begin
~118600         if (i_hs_grant)
~118600           w_fsm_hfeed_nxt_state = ENUM_ST_START;
              end
~118600       ENUM_ST_START: begin
~118600         casez ({(reg_head_left != 9'd0), (reg_tail_left != '0), w_mid_pend})
~118600           3'b1??:  w_fsm_hfeed_nxt_state = ENUM_ST_HEAD;
~000175           3'b01?:  w_fsm_hfeed_nxt_state = ENUM_ST_TRD;
~000020           3'b001:  w_fsm_hfeed_nxt_state = ENUM_ST_MID;
%000000           default: w_fsm_hfeed_nxt_state = ENUM_ST_HEAD;
                endcase
              end
~5557336       ENUM_ST_HEAD: begin
~4337784         if (i_hs_in_ready) begin
~111884           if (w_hlast)
~111884             w_fsm_hfeed_nxt_state = ENUM_ST_OUT;
~1100952           else if (reg_head_left <= 9'd8) begin
~006712             if (reg_tail_left != '0)
~006712               w_fsm_hfeed_nxt_state = ENUM_ST_TRD;
                    else
~000188               w_fsm_hfeed_nxt_state = ENUM_ST_MID;
                  end
                end
              end
~069475       ENUM_ST_TRD: w_fsm_hfeed_nxt_state = ENUM_ST_TWT;
~069475       ENUM_ST_TWT: begin
~069475         if (i_tr_valid) begin
~066695           if ((reg_toff != 3'd0) & ~reg_tprev_v)
~002780             w_fsm_hfeed_nxt_state = ENUM_ST_TRD;
                  else
~066695             w_fsm_hfeed_nxt_state = ENUM_ST_TSND;
                end
              end
~265065       ENUM_ST_TSND: begin
~198370         if (i_hs_in_ready) begin
~006716           if (w_tlast_all)
~006716             w_fsm_hfeed_nxt_state = ENUM_ST_OUT;
~062985           else if (w_tlast & w_mid_pend)
~001695             w_fsm_hfeed_nxt_state = ENUM_ST_MID;
                  else
~062985             w_fsm_hfeed_nxt_state = ENUM_ST_TRD;
                end
              end
~029610       ENUM_ST_MID: begin
~021340         if (i_hs_in_ready) begin
~006370           if (reg_mid_left > 9'd8)
~006370             w_fsm_hfeed_nxt_state = ENUM_ST_MID;
~001430           else if (w_tail2_pend)
~001430             w_fsm_hfeed_nxt_state = ENUM_ST_TRD;
                  else
~000470             w_fsm_hfeed_nxt_state = ENUM_ST_OUT;
                end
              end
~6995585       ENUM_ST_OUT: begin
~6876985         if (i_hs_out_valid & i_hs_out_last)
~118600           w_fsm_hfeed_nxt_state = ENUM_ST_DONE;
              end
~118600       ENUM_ST_DONE: w_fsm_hfeed_nxt_state = ENUM_ST_IDLE;
%000000       default:      w_fsm_hfeed_nxt_state = ENUM_ST_IDLE;
            endcase
~130968525     if (i_clr)
~1409240       w_fsm_hfeed_nxt_state = ENUM_ST_IDLE;
          end
        
          // Data registers.
 132377761   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
 000024     if (!i_rst_n_core) begin
 000024       reg_mode      <= 4'd0;
 000024       reg_outlen    <= 16'd0;
 000024       reg_head      <= '0;
 000024       reg_head_left <= 9'd0;
 000024       reg_mid       <= '0;
 000024       reg_mid_left  <= 9'd0;
 000024       reg_tail_left <= '0;
 000024       reg_tail2_left <= '0;
 000024       reg_tail2_addr <= '0;
 000024       reg_tword     <= '0;
 000024       reg_toff      <= 3'd0;
 000024       reg_tprev     <= 64'd0;
 000024       reg_tprev_v   <= 1'b0;
 000024       reg_tcur      <= 64'd0;
 000024       reg_digest    <= '0;
 000024       reg_dcnt      <= 16'd0;
            end
~130968497     else if (i_clr) begin
~1409240       reg_head      <= '0;
~1409240       reg_mid       <= '0;
~1409240       reg_tprev     <= 64'd0;
~1409240       reg_tcur      <= 64'd0;
~1409240       reg_digest    <= '0;
            end
 130968497     else begin
 130968497       case (reg_fsm_hfeed_current_state)
 117635461         ENUM_ST_IDLE: begin
~117516861           if (i_go) begin
~118600             reg_mode      <= i_mode;
~118600             reg_outlen    <= i_outlen;
~118600             reg_head      <= i_head;
~118600             reg_head_left <= i_head_len;
~118600             reg_mid       <= i_mid;
~118600             reg_mid_left  <= i_mid_len;
                    // An empty first tail is replaced by the second one when there is no mid segment.
~118600             reg_tail_left <= ((i_tail_len == '0) & (i_mid_len == 9'd0)) ? i_tail2_len : i_tail_len;
~118600             reg_tail2_left <= ((i_tail_len == '0) & (i_mid_len == 9'd0)) ? '0 : i_tail2_len;
~118600             reg_tail2_addr <= i_tail2_addr;
~118600             reg_tword     <= ((i_tail_len == '0) & (i_mid_len == 9'd0)) ? i_tail2_addr[PARA_TA_W-1:3] : i_tail_addr[PARA_TA_W-1:3];
~118600             reg_toff      <= ((i_tail_len == '0) & (i_mid_len == 9'd0)) ? i_tail2_addr[2:0] : i_tail_addr[2:0];
~118600             reg_tprev_v   <= 1'b0;
~118600             reg_digest    <= '0;
~118600             reg_dcnt      <= 16'd0;
                  end
                end
~5557336         ENUM_ST_HEAD: begin
~4337784           if (i_hs_in_ready) begin
~1219552             reg_head      <= reg_head >> 64;
~1219552             reg_head_left <= (reg_head_left > 9'd8) ? (reg_head_left - 9'd8) : 9'd0;
                  end
                end
~048852         ENUM_ST_TWT: begin
~048852           if (i_tr_valid) begin
~048851             if ((reg_toff != 3'd0) & ~reg_tprev_v) begin
~000556               reg_tprev   <= i_tr_data;
~000556               reg_tprev_v <= 1'b1;
~000556               reg_tword   <= reg_tword + 1'b1;
~048851             end else begin
~048851               reg_tcur <= i_tr_data;
                    end
                  end
                end
~207995         ENUM_ST_TSND: begin
~159144           if (i_hs_in_ready) begin
~000339             if (w_tlast & w_mid_pend) begin
                      // The first tail is finished: the mid segment follows, then the second tail.
~000339               reg_tail_left <= '0;
~048844             end else if (w_tlast & w_tail2_pend) begin
                      // The first tail is finished: the second one starts at its own byte address.
~000086               reg_tail_left  <= reg_tail2_left;
~000086               reg_tail2_left <= '0;
~000086               reg_tword      <= reg_tail2_addr[PARA_TA_W-1:3];
~000086               reg_toff       <= reg_tail2_addr[2:0];
~000086               reg_tprev_v    <= 1'b0;
~048844             end else begin
~048844               reg_tail_left <= (reg_tail_left > {{(PARA_TA_W-4){1'b0}}, 4'd8}) ? (reg_tail_left - 8) : '0;
~048844               reg_tprev     <= reg_tcur;
~048844               reg_tword     <= reg_tword + 1'b1;
                    end
                  end
                end
~017023         ENUM_ST_MID: begin
~014812           if (i_hs_in_ready) begin
~002211             reg_mid      <= reg_mid >> 64;
~002211             reg_mid_left <= (reg_mid_left > 9'd8) ? (reg_mid_left - 9'd8) : 9'd0;
~002127             if ((reg_mid_left <= 9'd8) & w_tail2_pend) begin
~000286               reg_tail_left  <= reg_tail2_left;
~000286               reg_tail2_left <= '0;
~000286               reg_tword      <= reg_tail2_addr[PARA_TA_W-1:3];
~000286               reg_toff       <= reg_tail2_addr[2:0];
~000286               reg_tprev_v    <= 1'b0;
                    end
                  end
                end
~6995585         ENUM_ST_OUT: begin
~6587364           if (i_hs_out_valid) begin
~3265768             for (int k = 0; k < 8; k++) begin
~3265736               if ((k < {28'd0, i_hs_out_nb}) && ((32'(reg_dcnt) + k) < PARA_DIG_BYTES))
~3265736                 reg_digest[8 * (32'(reg_dcnt) + k) +: 8] <= i_hs_out_data[8 * k +: 8];
                    end
~408221             reg_dcnt <= reg_dcnt + {12'd0, i_hs_out_nb};
                  end
                end
~523252         default: begin
~523252           reg_mode <= reg_mode;
                end
              endcase
            end
          end
        
        endmodule
        
