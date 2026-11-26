//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-09
         * Description  : SHA-224 and SHA-256 compression core (FIPS 180-4 section 6.2). One block of 64
         *                bytes is processed in 64 / PARA_UNR clock cycles after the start pulse. The block
         *                arrives with message byte 0 in bits [7:0]; the core converts each 4-byte group to
         *                a big-endian word. The result is the input state plus the working variables.
         *                Decisions: DEC-006, DEC-019, DEC-021 (clear input).
         */
        `timescale 1ns/1ps
        
        module m_vlsit_sha_core256 #(
          // Parameter Description: rounds computed in one clock cycle; shall divide 64.
          // Parameter values: 1, 2, 4, 8, 16, 32 or 64; default is 1.
          // Parameter unit: count
          parameter logic [31:0] PARA_UNR = 1,
          // Parameter Description: parity of the state registers (REQ-SEC-002, DEC-035).
          // Parameter values: 0 or 1; default is 0.
          // Parameter unit: flag
          parameter logic [31:0] PARA_PAR = 0,
          localparam logic [31:0] LPARA_CYC_N = 64 / PARA_UNR,
          localparam logic [31:0] LPARA_CNT_W = $clog2(64 / PARA_UNR + 1),
          localparam logic [31:0] LPARA_WIN_N = 16 + PARA_UNR
        ) (
          // Clock and reset
          input  wire          i_clk_core,
          input  wire          i_rst_n_core,
        
          // Control
          input  wire          i_start,
          input  wire          i_clr,
          output logic         o_done,
        
          // Block and state
          input  wire  [511:0] i_block,
          input  wire  [255:0] i_state,
          output logic [255:0] o_result,
          output logic         o_par_err
        );
        
          // Internal signal declarations
          logic [255:0] reg_v;
          logic [255:0] reg_s0;
          logic [511:0] reg_w;
          logic [LPARA_CNT_W-1:0] reg_cnt;
          logic reg_run;
          logic reg_done;
        
          logic [255:0] w_v_nxt;
          logic [511:0] w_w_nxt;
          logic [255:0] w_vs [PARA_UNR:0];
          logic [LPARA_WIN_N-1:0][31:0] w_win;
          logic [31:0] w_k;
          logic [6:0] w_kidx;
          logic [LPARA_CNT_W-1:0] w_cnt_nxt;
          logic w_last;
        
          // Round constants K0 to K63 of FIPS 180-4 section 4.2.2.
 132377765   function automatic logic [31:0] f_k(input logic [5:0] i_idx);
 132377765     case (i_idx)
 122625554       6'd0: f_k = 32'h428a2f98;
~154797       6'd1: f_k = 32'h71374491;
~154797       6'd2: f_k = 32'hb5c0fbcf;
~154797       6'd3: f_k = 32'he9b5dba5;
~154797       6'd4: f_k = 32'h3956c25b;
~154797       6'd5: f_k = 32'h59f111f1;
~154797       6'd6: f_k = 32'h923f82a4;
~154797       6'd7: f_k = 32'hab1c5ed5;
~154797       6'd8: f_k = 32'hd807aa98;
~154797       6'd9: f_k = 32'h12835b01;
~154797       6'd10: f_k = 32'h243185be;
~154797       6'd11: f_k = 32'h550c7dc3;
~154797       6'd12: f_k = 32'h72be5d74;
~154797       6'd13: f_k = 32'h80deb1fe;
~154797       6'd14: f_k = 32'h9bdc06a7;
~154797       6'd15: f_k = 32'hc19bf174;
~154797       6'd16: f_k = 32'he49b69c1;
~154797       6'd17: f_k = 32'hefbe4786;
~154797       6'd18: f_k = 32'h0fc19dc6;
~154797       6'd19: f_k = 32'h240ca1cc;
~154797       6'd20: f_k = 32'h2de92c6f;
~154797       6'd21: f_k = 32'h4a7484aa;
~154797       6'd22: f_k = 32'h5cb0a9dc;
~154797       6'd23: f_k = 32'h76f988da;
~154797       6'd24: f_k = 32'h983e5152;
~154797       6'd25: f_k = 32'ha831c66d;
~154797       6'd26: f_k = 32'hb00327c8;
~154797       6'd27: f_k = 32'hbf597fc7;
~154797       6'd28: f_k = 32'hc6e00bf3;
~154797       6'd29: f_k = 32'hd5a79147;
~154797       6'd30: f_k = 32'h06ca6351;
~154797       6'd31: f_k = 32'h14292967;
~154797       6'd32: f_k = 32'h27b70a85;
~154797       6'd33: f_k = 32'h2e1b2138;
~154797       6'd34: f_k = 32'h4d2c6dfc;
~154797       6'd35: f_k = 32'h53380d13;
~154797       6'd36: f_k = 32'h650a7354;
~154797       6'd37: f_k = 32'h766a0abb;
~154797       6'd38: f_k = 32'h81c2c92e;
~154797       6'd39: f_k = 32'h92722c85;
~154797       6'd40: f_k = 32'ha2bfe8a1;
~154797       6'd41: f_k = 32'ha81a664b;
~154797       6'd42: f_k = 32'hc24b8b70;
~154797       6'd43: f_k = 32'hc76c51a3;
~154797       6'd44: f_k = 32'hd192e819;
~154797       6'd45: f_k = 32'hd6990624;
~154797       6'd46: f_k = 32'hf40e3585;
~154797       6'd47: f_k = 32'h106aa070;
~154797       6'd48: f_k = 32'h19a4c116;
~154797       6'd49: f_k = 32'h1e376c08;
~154797       6'd50: f_k = 32'h2748774c;
~154797       6'd51: f_k = 32'h34b0bcb5;
~154797       6'd52: f_k = 32'h391c0cb3;
~154797       6'd53: f_k = 32'h4ed8aa4a;
~154797       6'd54: f_k = 32'h5b9cca4f;
~154797       6'd55: f_k = 32'h682e6ff3;
~154797       6'd56: f_k = 32'h748f82ee;
~154797       6'd57: f_k = 32'h78a5636f;
~154797       6'd58: f_k = 32'h84c87814;
~154797       6'd59: f_k = 32'h8cc70208;
~154797       6'd60: f_k = 32'h90befffa;
~154797       6'd61: f_k = 32'ha4506ceb;
~154797       6'd62: f_k = 32'hbef9a3f7;
~154797       6'd63: f_k = 32'hc67178f2;
%000000       default: f_k = '0;
            endcase
          endfunction
        
          // Rotate right of a 32-bit word by a constant amount.
 1323777650   function automatic logic [31:0] f_rotr(input logic [31:0] i_x, input logic [5:0] i_n);
 1323777650     f_rotr = (i_x >> i_n) | (i_x << (6'd32 - i_n));
          endfunction
        
          // Byte reversal of a 32-bit word: converts the little-endian packing of the block to the
          // big-endian message word of the standard.
~2476752   function automatic logic [31:0] f_swap(input logic [31:0] i_x);
~2476752     f_swap = {i_x[7:0], i_x[15:8], i_x[23:16], i_x[31:24]};
          endfunction
        
          // Message schedule sigma0 of FIPS 180-4 section 4.1.2.
 132377765   function automatic logic [31:0] f_sig0(input logic [31:0] i_x);
 132377765     f_sig0 = f_rotr(i_x, 6'd7) ^ f_rotr(i_x, 6'd18) ^ (i_x >> 3);
          endfunction
        
          // Message schedule sigma1 of FIPS 180-4 section 4.1.2.
 132377765   function automatic logic [31:0] f_sig1(input logic [31:0] i_x);
 132377765     f_sig1 = f_rotr(i_x, 6'd17) ^ f_rotr(i_x, 6'd19) ^ (i_x >> 10);
          endfunction
        
          // Round function: the next working variables a..h (a in bits [31:0]) from the current ones, the
          // round constant and the message word (FIPS 180-4 section 6.2.2 step 3).
 132377765   function automatic logic [255:0] f_round(input logic [255:0] i_v, input logic [31:0] i_kw);
 132377765     logic [31:0] ra;
 132377765     logic [31:0] rb;
 132377765     logic [31:0] rc;
 132377765     logic [31:0] rd;
 132377765     logic [31:0] re;
 132377765     logic [31:0] rf;
 132377765     logic [31:0] rg;
 132377765     logic [31:0] rh;
 132377765     logic [31:0] t1;
 132377765     logic [31:0] t2;
 132377765     begin
 132377765       ra = i_v[31:0];
 132377765       rb = i_v[63:32];
 132377765       rc = i_v[95:64];
 132377765       rd = i_v[127:96];
 132377765       re = i_v[159:128];
 132377765       rf = i_v[191:160];
 132377765       rg = i_v[223:192];
 132377765       rh = i_v[255:224];
 132377765       t1 = rh + (f_rotr(re, 6'd6) ^ f_rotr(re, 6'd11) ^ f_rotr(re, 6'd25))
 132377765          + ((re & rf) ^ (~re & rg)) + i_kw;
 132377765       t2 = (f_rotr(ra, 6'd2) ^ f_rotr(ra, 6'd13) ^ f_rotr(ra, 6'd22))
 132377765          + ((ra & rb) ^ (ra & rc) ^ (rb & rc));
 132377765       f_round = {rg, rf, re, rd + t1, rc, rb, ra, t1 + t2};
            end
          endfunction
        
          // Message schedule window and rounds of one clock cycle. w_win[0..15] is the current window
          // W[t] .. W[t+15]; the next PARA_UNR words are derived from it. Round j of the cycle uses
          // w_win[j] and the constant K[cnt x PARA_UNR + j]. The window then moves by PARA_UNR words.
 132377765   always_comb begin : p_com_round
 132377765     w_k = '0;
 132377765     w_kidx = '0;
 132377765     w_w_nxt = '0;
 132377765     w_win = '0;
 132377765     w_vs[0] = reg_v;
 2118044240     for (int idx = 0; idx < 16; idx++)
 2118044240       w_win[idx] = reg_w[32*idx +: 32];
 132377765     for (int idx = 0; idx < PARA_UNR; idx++)
 132377765       w_win[16+idx] = f_sig1(w_win[14+idx]) + w_win[9+idx] + f_sig0(w_win[1+idx]) + w_win[idx];
 132377765     for (int idx = 0; idx < PARA_UNR; idx++) begin
 132377765       w_kidx = $bits(w_kidx)'(reg_cnt * PARA_UNR + idx);
 132377765       w_k = f_k(w_kidx[5:0]);
 132377765       w_vs[idx+1] = f_round(w_vs[idx], w_k + w_win[idx]);
            end
 132377765     w_v_nxt = w_vs[PARA_UNR];
 2118044240     for (int idx = 0; idx < 16; idx++)
 2118044240       w_w_nxt[32*idx +: 32] = w_win[idx+PARA_UNR];
 132377765     w_last = (reg_cnt == LPARA_CNT_W'(LPARA_CYC_N - 1));
 132377765     w_cnt_nxt = reg_cnt + 1'b1;
          end
        
          // Control state: running and done flags are reset; the datapath registers below are resetless
          // because the result is only used while o_done is 1 (SEQ-04).
 132377761   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_ctrl
 132377737     if (!i_rst_n_core) begin
 000024       reg_run  <= 1'b0;
 000024       reg_done <= 1'b0;
 000024       reg_cnt  <= '0;
 132377737     end else begin
 132377737       casez ({i_start, i_clr, reg_run})
~154797         3'b1??: begin
~154797           reg_run  <= 1'b1;
~154797           reg_done <= 1'b0;
~154797           reg_cnt  <= '0;
                end
~1409240         3'b01?: begin
~1409240           reg_run  <= 1'b0;
~1409240           reg_done <= 1'b0;
~1409240           reg_cnt  <= '0;
                end
~9907008         3'b001: begin
~9907008           reg_cnt <= w_cnt_nxt;
~9752211           if (w_last) begin
~154797             reg_run  <= 1'b0;
~154797             reg_done <= 1'b1;
                  end
                end
 120906692         default: begin
                  // Idle: the flags and the counter keep their values.
                end
              endcase
            end
          end
        
          // Datapath registers: loaded at start, advanced while running, zeroed by the clear input.
 132377761   always_ff @(posedge i_clk_core) begin : p_ff_data
 132377761     casez ({i_start, i_clr, reg_run})
~154797       3'b1??: begin
~154797         reg_v  <= i_state;
~154797         reg_s0 <= i_state;
~2476752         for (int idx = 0; idx < 16; idx++)
~2476752           reg_w[32*idx +: 32] <= f_swap(i_block[32*idx +: 32]);
              end
~1409240       3'b01?: begin
~1409240         reg_v  <= '0;
~1409240         reg_s0 <= '0;
~1409240         reg_w  <= '0;
              end
~9907008       3'b001: begin
~9907008         reg_v <= w_v_nxt;
~9907008         reg_w <= w_w_nxt;
              end
 120906716       default: begin
                // Idle: the datapath registers keep their values.
              end
            endcase
          end
        
          // Result: intermediate hash value plus the working variables, word by word.
 000004   always_comb begin : p_com_result
 000004     o_result = '0;
 000032     for (int idx = 0; idx < 8; idx++)
 000032       o_result[32*idx +: 32] = reg_s0[32*idx +: 32] + reg_v[32*idx +: 32];
          end
        
          // The done flag is the registered end of the last round.
          assign o_done = reg_done;
        
        
          // Parity of the state registers (PARA_PAR = 1): one even-parity bit per 32 bits of reg_v, reg_w,
          // generated from the next value and checked while the core runs. A flipped bit of a register
          // gives a mismatch in the cycle in which it is read (REQ-SEC-002, DEC-035). The parity bits are
          // resetless like the data registers.
          logic [7:0]  reg_pv;
          logic [15:0] reg_pw;
        
 10061809   function automatic logic [7:0] f_parv(input logic [255:0] i_d);
 80494472     for (int idx = 0; idx < 8; idx++)
 80494472       f_parv[idx] = ^i_d[32*idx +: 32];
          endfunction
        
 10061809   function automatic logic [15:0] f_parw(input logic [511:0] i_d);
 160988944     for (int idx = 0; idx < 16; idx++)
 160988944       f_parw[idx] = ^i_d[32*idx +: 32];
          endfunction
        
 132377761   always_ff @(posedge i_clk_core) begin : p_ff_par
 132377761     casez ({i_start, i_clr, reg_run})
~154797       3'b1??: begin
~154797         reg_pv <= f_parv(i_state);
~154797         reg_pw <= f_parw(i_block);
              end
~1409240       3'b01?: begin
~1409240         reg_pv <= '0;
~1409240         reg_pw <= '0;
              end
~9907008       3'b001: begin
~9907008         reg_pv <= f_parv(w_v_nxt);
~9907008         reg_pw <= f_parw(w_w_nxt);
              end
 120906716       default: begin
                // Idle: the parity bits keep their values.
              end
            endcase
          end
        
 000004   always_comb begin : p_com_par
 000004     o_par_err = (PARA_PAR != 32'd0) & reg_run & ((f_parv(reg_v) != reg_pv) | (f_parw(reg_w) != reg_pw));
          end
        
        endmodule
        
