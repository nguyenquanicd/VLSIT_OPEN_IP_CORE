//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Opus 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-26
         * Description  : Digit-serial Montgomery multiplier of the elliptic-curve engine (PARA_MUL_W,
         *                REQ-PARAM-002, REQ-PERF-001, REQ-PERF-002). For an odd modulus m < 2^(w nd) and
         *                operands a, b < m it returns r = a b 2^(-w nd) mod m, with w = PARA_MUL_W and nd =
         *                i_nd digits. One digit of a per cycle (CIOS form): t = (t + a_i b + q m) / 2^w
         *                with q = ((t + a_i b) mod 2^w) m' mod 2^w, where m' = -m^(-1) mod 2^w (i_mp); a
         *                last cycle subtracts m when t >= m. The cycle count is nd + 1 whatever the operand
         *                values (the last subtraction is a selection, REQ-SEC-002). i_start is a one-cycle
         *                pulse; o_done is a one-cycle pulse with o_r valid in the same cycle. Deviation
         *                from MOD-02 (SHOULD): none. The two w x 576 products are combinational: timing at
         *                the target frequency depends on PARA_MUL_W and is not claimed (section 17).
         */
        `timescale 1ns/1ps
        
        module m_vlsit_dsig_mmul #(
          // Parameter Description: digit width of the multiplier.
          // Parameter values: 32, 64 or 128; default is 64.
          // Parameter unit: bit
          parameter logic [31:0] PARA_MUL_W = 64
        ) (
          // Clock, reset and clearing
          input  wire          i_clk_core,
          input  wire          i_rst_n_core,
          input  wire          i_clr,
        
          // Operation
          input  wire          i_start,
          input  wire  [575:0] i_a,
          input  wire  [575:0] i_b,
          input  wire  [575:0] i_m,
          input  wire  [127:0] i_mp,
          input  wire  [4:0]   i_nd,
          output logic         o_done,
          output logic [575:0] o_r
        );
        
          // Internal signal declarations
          logic [583:0]             reg_a;
          logic [575:0]             reg_b;
          logic [575:0]             reg_m;
          logic [PARA_MUL_W-1:0]    reg_mp;
          logic [577:0]             reg_t;
          logic [4:0]               reg_cnt;
          logic                     reg_run;
          logic                     reg_fin;
          logic [PARA_MUL_W-1:0]    w_ai;
          logic [575+PARA_MUL_W:0]  w_ab;
          logic [576+PARA_MUL_W:0]  w_s;
          logic [PARA_MUL_W-1:0]    w_q;
          logic [575+PARA_MUL_W:0]  w_qm;
          logic [577+PARA_MUL_W:0]  w_u;
          logic [577:0]             w_t_nxt;
          logic [578:0]             w_sub;
        
          // One digit step: s = t + a_i b, q = (s mod 2^w) m' mod 2^w, t' = (s + q m) / 2^w
          assign w_ai    = reg_a[PARA_MUL_W-1:0];
          assign w_ab    = {{PARA_MUL_W{1'b0}}, reg_b} * {{576{1'b0}}, w_ai};
          assign w_s     = {{(PARA_MUL_W - 1){1'b0}}, reg_t} + {1'b0, w_ab};
          assign w_q     = PARA_MUL_W'(w_s[PARA_MUL_W-1:0] * reg_mp);
          assign w_qm    = {{PARA_MUL_W{1'b0}}, reg_m} * {{576{1'b0}}, w_q};
          assign w_u     = {1'b0, w_s} + {2'b00, w_qm};
          assign w_t_nxt = w_u[577+PARA_MUL_W:PARA_MUL_W];
        
          // Final correction: t - m when t >= m (t < 2m)
          assign w_sub   = {1'b0, reg_t} - {3'b000, reg_m};
~36126167   assign o_r     = w_sub[578] ? reg_t[575:0] : w_sub[575:0];
          assign o_done  = reg_fin;
        
 39751532   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_mmul
 000018     if (!i_rst_n_core) begin
 000018       reg_a   <= 584'd0;
 000018       reg_b   <= 576'd0;
 000018       reg_m   <= 576'd0;
 000018       reg_mp  <= '0;
 000018       reg_t   <= 578'd0;
 000018       reg_cnt <= 5'd0;
 000018       reg_run <= 1'b0;
 000018       reg_fin <= 1'b0;
            end
 39751234     else if (i_clr) begin
 131085       reg_a   <= 584'd0;
 131085       reg_b   <= 576'd0;
 131085       reg_m   <= 576'd0;
 131085       reg_mp  <= '0;
 131085       reg_t   <= 578'd0;
 131085       reg_cnt <= 5'd0;
 131085       reg_run <= 1'b0;
 131085       reg_fin <= 1'b0;
            end
 39751234     else begin
 39751234       reg_fin <= 1'b0;
~4552588       if (i_start) begin
~4552588         reg_a   <= {8'd0, i_a};
~4552588         reg_b   <= i_b;
~4552588         reg_m   <= i_m;
~4552588         reg_mp  <= i_mp[PARA_MUL_W-1:0];
~4552588         reg_t   <= 578'd0;
~4552588         reg_cnt <= i_nd;
~4552588         reg_run <= 1'b1;
~24800398       end else if (reg_run) begin
~24800398         reg_t   <= w_t_nxt;
~24800398         reg_a   <= reg_a >> PARA_MUL_W;
~24800398         reg_cnt <= reg_cnt - 5'd1;
~20247810         if (reg_cnt == 5'd1) begin
~4552588           reg_run <= 1'b0;
~4552588           reg_fin <= 1'b1;
                end
              end
            end
          end
        
        endmodule
        
