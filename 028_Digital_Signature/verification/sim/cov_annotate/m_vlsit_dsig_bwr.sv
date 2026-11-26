//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-25
         * Description  : Byte writer of the engines of the digital signature IP. It writes a byte string
         *                of 1 to 72 bytes (byte 0 in bits [7:0] of i_data) to any byte address of the
         *                buffer, one 64-bit word per cycle with byte strobes, so the bytes around the
         *                string keep their value. o_done is a one-cycle pulse after the last word. i_clr
         *                stops the write. Requirements: REQ-IF-002, section 9 (byte order of the
         *                buffer).
         */
        `timescale 1ns/1ps
        
        module m_vlsit_dsig_bwr #(
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
          input  wire  [575:0]       i_data,
          output logic               o_done,
        
          // Buffer write port
          output logic               o_wr_en,
          output logic [PARA_WA-1:0] o_wr_addr,
          output logic [63:0]        o_wr_data,
          output logic [7:0]         o_wr_strb
        );
        
          // States
          typedef enum logic [1:0] {
            ENUM_ST_IDLE = 2'd0,
            ENUM_ST_WR   = 2'd1,
            ENUM_ST_DONE = 2'd2
          } bwr_state_type_def;
        
          // Internal signal declarations
          bwr_state_type_def reg_fsm_bwr_current_state;
          bwr_state_type_def w_fsm_bwr_nxt_state;
          logic [639:0]       reg_data;
          logic [79:0]        reg_strb;
          logic [19:0]        reg_addr;
          logic [3:0]         reg_j;
          logic [3:0]         reg_nw;
          logic [79:0]        w_strb_new;
          logic [3:0]         w_nw;
          logic [2:0]         w_off;
        
          assign w_off      = i_addr[2:0];
          assign w_nw       = 4'(({5'd0, w_off} + i_len + 8'd7) >> 3);
          // One strobe bit per byte: len ones moved to the byte offset of the first word.
          assign w_strb_new = ((80'd1 << i_len) - 80'd1) << w_off;
        
          assign o_wr_en   = (reg_fsm_bwr_current_state == ENUM_ST_WR);
          assign o_wr_addr = PARA_WA'(reg_addr[19:3] + 17'(reg_j));
          assign o_wr_data = reg_data[63:0];
          assign o_wr_strb = reg_strb[7:0];
          assign o_done    = (reg_fsm_bwr_current_state == ENUM_ST_DONE);
        
          // Part 1 of the FSM: state register.
 39751532   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_bwr
 39751514     if (!i_rst_n_core)
 000018       reg_fsm_bwr_current_state <= ENUM_ST_IDLE;
            else
 39751514       reg_fsm_bwr_current_state <= w_fsm_bwr_nxt_state;
          end
        
          // Part 2 of the FSM: next state.
 39751535   always_comb begin : p_com_fsm_nxt
 39751535     w_fsm_bwr_nxt_state = reg_fsm_bwr_current_state;
 39751535     case (reg_fsm_bwr_current_state)
 39751010       ENUM_ST_IDLE: begin
~39750927         if (i_go)
~000083           w_fsm_bwr_nxt_state = ENUM_ST_WR;
              end
~000442       ENUM_ST_WR: begin
~000359         if (reg_j + 4'd1 == reg_nw)
~000083           w_fsm_bwr_nxt_state = ENUM_ST_DONE;
              end
~000083       ENUM_ST_DONE: w_fsm_bwr_nxt_state = ENUM_ST_IDLE;
%000000       default:      w_fsm_bwr_nxt_state = ENUM_ST_IDLE;
            endcase
 39751255     if (i_clr)
 131085       w_fsm_bwr_nxt_state = ENUM_ST_IDLE;
          end
        
          // Data registers: data and strobes are shifted by one word after every write.
 39751532   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
 000018     if (!i_rst_n_core) begin
 000018       reg_data <= 640'd0;
 000018       reg_strb <= 80'd0;
 000018       reg_addr <= 20'd0;
 000018       reg_j    <= 4'd0;
 000018       reg_nw   <= 4'd0;
            end
 39751234     else if (i_clr) begin
 131085       reg_data <= 640'd0;
 131085       reg_strb <= 80'd0;
            end
 39751234     else begin
 39751234       case (reg_fsm_bwr_current_state)
 39750709         ENUM_ST_IDLE: begin
~39750626           if (i_go) begin
~000083             reg_data <= {64'd0, i_data} << {w_off, 3'b000};
~000083             reg_strb <= w_strb_new;
~000083             reg_addr <= i_addr;
~000083             reg_j    <= 4'd0;
~000083             reg_nw   <= w_nw;
                  end
                end
~000442         ENUM_ST_WR: begin
~000442           reg_data <= reg_data >> 64;
~000442           reg_strb <= reg_strb >> 8;
~000442           reg_j    <= reg_j + 4'd1;
                end
~000083         default: begin
~000083           reg_j <= reg_j;
                end
              endcase
            end
          end
        
        endmodule
        
