//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-25
         * Description  : Byte reader of the engines of the digital signature IP. It reads a byte string
         *                of 1 to 72 bytes that starts at any byte address of the buffer (64-bit words,
         *                read data one cycle after the request) and returns it as a vector with byte 0
         *                in bits [7:0]. A read of nine words takes about 18 cycles. o_done is a
         *                one-cycle pulse; o_data stays valid until the next go pulse; i_clr stops the
         *                read and clears the data. Requirements: REQ-IF-002, section 9 (byte order of
         *                the buffer).
         */
        `timescale 1ns/1ps
        
        module m_vlsit_dsig_brd #(
          // Parameter Description: width of the word address of the buffer port.
          // Parameter values: 4 to 16; default is 7.
          // Parameter unit: bit
          parameter logic [31:0] PARA_WA = 7
        ) (
          // Clock and reset
          input  wire                i_clk_core,
          input  wire                i_rst_n_core,
          input  wire                i_clr,
        
          // Request
          input  wire                i_go,
          input  wire  [19:0]        i_addr,
          input  wire  [7:0]         i_len,
          output logic [575:0]       o_data,
          output logic               o_done,
        
          // Buffer read port
          output logic               o_rd_en,
          output logic [PARA_WA-1:0] o_rd_addr,
          input  wire  [63:0]        i_rd_data,
          input  wire                i_rd_valid
        );
        
          // States
          typedef enum logic [2:0] {
            ENUM_ST_IDLE = 3'd0,
            ENUM_ST_REQ  = 3'd1,
            ENUM_ST_WAIT = 3'd2,
            ENUM_ST_DONE = 3'd3
          } brd_state_type_def;
        
          // Internal signal declarations
          brd_state_type_def reg_fsm_brd_current_state;
          brd_state_type_def w_fsm_brd_nxt_state;
          logic [639:0]       reg_acc;
          logic [19:0]        reg_addr;
          logic [7:0]         reg_len;
          logic [3:0]         reg_j;
          logic [3:0]         reg_nw;
          logic [3:0]         w_nw;
        
          // Words needed: the string starts at byte offset addr[2:0] of the first word.
          assign w_nw = 4'(({5'd0, i_addr[2:0]} + i_len + 8'd7) >> 3);
        
          assign o_rd_en   = (reg_fsm_brd_current_state == ENUM_ST_REQ);
          assign o_rd_addr = PARA_WA'(reg_addr[19:3] + 17'(reg_j));
          assign o_done    = (reg_fsm_brd_current_state == ENUM_ST_DONE);
          assign o_data    = 576'(reg_acc >> {reg_addr[2:0], 3'b000});
        
          // Part 1 of the FSM: state register.
 39751532   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_brd
 39751514     if (!i_rst_n_core)
 000018       reg_fsm_brd_current_state <= ENUM_ST_IDLE;
            else
 39751514       reg_fsm_brd_current_state <= w_fsm_brd_nxt_state;
          end
        
          // Part 2 of the FSM: next state.
 39751535   always_comb begin : p_com_fsm_nxt
 39751535     w_fsm_brd_nxt_state = reg_fsm_brd_current_state;
 39751535     case (reg_fsm_brd_current_state)
 39749264       ENUM_ST_IDLE: begin
~39749065         if (i_go)
~000199           w_fsm_brd_nxt_state = ENUM_ST_REQ;
              end
~001036       ENUM_ST_REQ: w_fsm_brd_nxt_state = ENUM_ST_WAIT;
~001036       ENUM_ST_WAIT: begin
~001036         if (i_rd_valid) begin
~000837           if (reg_j + 4'd1 == reg_nw)
~000199             w_fsm_brd_nxt_state = ENUM_ST_DONE;
                  else
~000837             w_fsm_brd_nxt_state = ENUM_ST_REQ;
                end
              end
~000199       ENUM_ST_DONE: w_fsm_brd_nxt_state = ENUM_ST_IDLE;
%000000       default:      w_fsm_brd_nxt_state = ENUM_ST_IDLE;
            endcase
 39751255     if (i_clr)
 131085       w_fsm_brd_nxt_state = ENUM_ST_IDLE;
          end
        
          // Data registers: the words are collected; the output shifts the bytes before the start away.
 39751532   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
 000018     if (!i_rst_n_core) begin
 000018       reg_acc  <= 640'd0;
 000018       reg_addr <= 20'd0;
 000018       reg_len  <= 8'd0;
 000018       reg_j    <= 4'd0;
 000018       reg_nw   <= 4'd0;
            end
 39751234     else if (i_clr) begin
 131085       reg_acc  <= 640'd0;
            end
 39751234     else begin
 39751234       case (reg_fsm_brd_current_state)
 39748963         ENUM_ST_IDLE: begin
~39748764           if (i_go) begin
~000199             reg_addr <= i_addr;
~000199             reg_len  <= i_len;
~000199             reg_j    <= 4'd0;
~000199             reg_nw   <= w_nw;
~000199             reg_acc  <= 640'd0;
                  end
                end
~001036         ENUM_ST_WAIT: begin
~001036           if (i_rd_valid) begin
~001036             reg_acc[64 * reg_j +: 64] <= i_rd_data;
~001036             reg_j <= reg_j + 4'd1;
                  end
                end
~001235         default: begin
~001235           reg_j <= reg_j;
                end
              endcase
            end
          end
        
        endmodule
        
