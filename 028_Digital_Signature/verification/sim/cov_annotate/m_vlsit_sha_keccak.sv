//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-09
         * Description  : Keccak-f[1600] permutation core for SHA-3 and SHAKE (FIPS 202 section 3). At the
         *                start pulse the block (zero extended to 1344 bits, message byte 0 in bits [7:0])
         *                is XORed into the input state, then PARA_UNR of the 24 rounds are computed in each
         *                clock cycle. Lane (x, y) is bits [64 x (x + 5 y) +: 64] of the state, which is the
         *                bit order of FIPS 202 section 3.1.2 and appendix B.1.
         *                Decisions: DEC-006, DEC-019, DEC-021 (clear input).
         */
        `timescale 1ns/1ps
        
        module m_vlsit_sha_keccak #(
          // Parameter Description: rounds computed in one clock cycle; shall divide 24.
          // Parameter values: 1, 2, 3, 4, 6, 8, 12 or 24; default is 1.
          // Parameter unit: count
          parameter logic [31:0] PARA_UNR = 1,
          // Parameter Description: parity of the state registers (REQ-SEC-002, DEC-035).
          // Parameter values: 0 or 1; default is 0.
          // Parameter unit: flag
          parameter logic [31:0] PARA_PAR = 0,
          localparam logic [31:0] LPARA_CYC_N = 24 / PARA_UNR,
          localparam logic [31:0] LPARA_CNT_W = $clog2(24 / PARA_UNR + 1)
        ) (
          // Clock and reset
          input  wire           i_clk_core,
          input  wire           i_rst_n_core,
        
          // Control
          input  wire           i_start,
          input  wire           i_clr,
          output logic          o_done,
        
          // Block and state
          input  wire  [1343:0] i_block,
          input  wire  [1599:0] i_state,
          output logic [1599:0] o_result,
          output logic          o_par_err
        );
        
          // Internal signal declarations
          logic [1599:0] reg_st;
          logic [LPARA_CNT_W-1:0] reg_cnt;
          logic reg_run;
          logic reg_done;
        
          logic [1599:0] w_st_nxt;
          logic [1599:0] w_ss [PARA_UNR:0];
          logic [4:0] w_ridx;
          logic [LPARA_CNT_W-1:0] w_cnt_nxt;
          logic w_last;
        
          // Round constants RC[0] to RC[23] of FIPS 202 section 3.2.5.
 132377765   function automatic logic [63:0] f_rc(input logic [4:0] i_idx);
 132377765     case (i_idx)
 34822326       5'd0: f_rc = 64'h0000000000000001;
~074688       5'd1: f_rc = 64'h0000000000008082;
~074688       5'd2: f_rc = 64'h800000000000808a;
~074688       5'd3: f_rc = 64'h8000000080008000;
~074688       5'd4: f_rc = 64'h000000000000808b;
~074688       5'd5: f_rc = 64'h0000000080000001;
~074688       5'd6: f_rc = 64'h8000000080008081;
~074688       5'd7: f_rc = 64'h8000000000008009;
~074688       5'd8: f_rc = 64'h000000000000008a;
~074688       5'd9: f_rc = 64'h0000000000000088;
~074688       5'd10: f_rc = 64'h0000000080008009;
~074688       5'd11: f_rc = 64'h000000008000000a;
~074688       5'd12: f_rc = 64'h000000008000808b;
~074688       5'd13: f_rc = 64'h800000000000008b;
~074688       5'd14: f_rc = 64'h8000000000008089;
~074688       5'd15: f_rc = 64'h8000000000008003;
~074688       5'd16: f_rc = 64'h8000000000008002;
~074688       5'd17: f_rc = 64'h8000000000000080;
~074688       5'd18: f_rc = 64'h000000000000800a;
~074688       5'd19: f_rc = 64'h800000008000000a;
~074688       5'd20: f_rc = 64'h8000000080008081;
~074688       5'd21: f_rc = 64'h8000000000008080;
~074688       5'd22: f_rc = 64'h0000000080000001;
~074688       5'd23: f_rc = 64'h8000000080008008;
~95837615       default: f_rc = '0;
            endcase
          endfunction
        
          // Rotation offsets of FIPS 202 section 3.2.2 for lane x + 5 y.
 3309444125   function automatic logic [5:0] f_rot(input logic [4:0] i_idx);
 3309444125     case (i_idx)
 132377765       5'd0: f_rot = 6'h00;
 132377765       5'd1: f_rot = 6'h01;
 132377765       5'd2: f_rot = 6'h3e;
 132377765       5'd3: f_rot = 6'h1c;
 132377765       5'd4: f_rot = 6'h1b;
 132377765       5'd5: f_rot = 6'h24;
 132377765       5'd6: f_rot = 6'h2c;
 132377765       5'd7: f_rot = 6'h06;
 132377765       5'd8: f_rot = 6'h37;
 132377765       5'd9: f_rot = 6'h14;
 132377765       5'd10: f_rot = 6'h03;
 132377765       5'd11: f_rot = 6'h0a;
 132377765       5'd12: f_rot = 6'h2b;
 132377765       5'd13: f_rot = 6'h19;
 132377765       5'd14: f_rot = 6'h27;
 132377765       5'd15: f_rot = 6'h29;
 132377765       5'd16: f_rot = 6'h2d;
 132377765       5'd17: f_rot = 6'h0f;
 132377765       5'd18: f_rot = 6'h15;
 132377765       5'd19: f_rot = 6'h08;
 132377765       5'd20: f_rot = 6'h12;
 132377765       5'd21: f_rot = 6'h02;
 132377765       5'd22: f_rot = 6'h3d;
 132377765       5'd23: f_rot = 6'h38;
 132377765       5'd24: f_rot = 6'h0e;
%000000       default: f_rot = '0;
            endcase
          endfunction
        
          // Rotate left of a 64-bit lane by an offset of 0 to 63.
 3971332950   function automatic logic [63:0] f_rotl(input logic [63:0] i_x, input logic [6:0] i_n);
 3971332950     f_rotl = (i_x << i_n) | (i_x >> (7'd64 - i_n));
          endfunction
        
          // One round of Keccak-f[1600]: theta, rho, pi, chi, iota in this order (FIPS 202 section 3.3).
          // Lane (x, y) is the 64 bits at index x + 5 y of the lane array.
 132377765   function automatic logic [1599:0] f_round(input logic [1599:0] i_s, input logic [63:0] i_rc);
 132377765     logic [63:0] a [24:0];
 132377765     logic [63:0] b [24:0];
 132377765     logic [63:0] c [4:0];
 132377765     logic [63:0] d [4:0];
 132377765     logic [1599:0] r;
 132377765     begin
 3309444125       for (int lane = 0; lane < 25; lane++)
 3309444125         a[lane] = i_s[64*lane +: 64];
              // Theta: column parities and their diffusion into every lane.
 661888825       for (int x = 0; x < 5; x++)
 661888825         c[x] = a[x] ^ a[x+5] ^ a[x+10] ^ a[x+15] ^ a[x+20];
 661888825       for (int x = 0; x < 5; x++)
 661888825         d[x] = c[(x+4)%5] ^ f_rotl(c[(x+1)%5], 7'd1);
 661888825       for (int y = 0; y < 5; y++)
 3309444125         for (int x = 0; x < 5; x++)
 3309444125           a[x+5*y] = a[x+5*y] ^ d[x];
              // Rho and pi: rotate each lane and move it to lane (y, 2x + 3y).
 661888825       for (int y = 0; y < 5; y++)
 3309444125         for (int x = 0; x < 5; x++)
 3309444125           b[y+5*((2*x+3*y)%5)] = f_rotl(a[x+5*y], {1'b0, f_rot(5'(x+5*y))});
              // Chi: the only non-linear step, row by row.
 661888825       for (int y = 0; y < 5; y++)
 3309444125         for (int x = 0; x < 5; x++)
 3309444125           a[x+5*y] = b[x+5*y] ^ (~b[((x+1)%5)+5*y] & b[((x+2)%5)+5*y]);
              // Iota: round constant into lane (0, 0).
 132377765       a[0] = a[0] ^ i_rc;
 3309444125       for (int lane = 0; lane < 25; lane++)
 3309444125         r[64*lane +: 64] = a[lane];
 132377765       f_round = r;
            end
          endfunction
        
          // Rounds of one clock cycle: PARA_UNR rounds in series, with round constant index
          // cnt x PARA_UNR + j for round j of the cycle.
 132377765   always_comb begin : p_com_round
 132377765     w_ridx = '0;
 132377765     w_ss[0] = reg_st;
 132377765     for (int idx = 0; idx < PARA_UNR; idx++) begin
 132377765       w_ridx = $bits(w_ridx)'(reg_cnt * PARA_UNR + idx);
 132377765       w_ss[idx+1] = f_round(w_ss[idx], f_rc(w_ridx));
            end
 132377765     w_st_nxt = w_ss[PARA_UNR];
 132377765     w_last = (reg_cnt == LPARA_CNT_W'(LPARA_CYC_N - 1));
 132377765     w_cnt_nxt = reg_cnt + 1'b1;
          end
        
          // Control state: running and done flags are reset; the state register is resetless because
          // the result is only used while o_done is 1 (SEQ-04).
 132377761   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_ctrl
 132377737     if (!i_rst_n_core) begin
 000024       reg_run  <= 1'b0;
 000024       reg_done <= 1'b0;
 000024       reg_cnt  <= '0;
 132377737     end else begin
 132377737       casez ({i_start, i_clr, reg_run})
~074688         3'b1??: begin
~074688           reg_run  <= 1'b1;
~074688           reg_done <= 1'b0;
~074688           reg_cnt  <= '0;
                end
~1409240         3'b01?: begin
~1409240           reg_run  <= 1'b0;
~1409240           reg_done <= 1'b0;
~1409240           reg_cnt  <= '0;
                end
~1792512         3'b001: begin
~1792512           reg_cnt <= w_cnt_nxt;
~1717824           if (w_last) begin
~074688             reg_run  <= 1'b0;
~074688             reg_done <= 1'b1;
                  end
                end
 129101297         default: begin
                  // Idle: the flags and the counter keep their values.
                end
              endcase
            end
          end
        
          // State register: absorbs the block at start, advances while running, zeroed by the clear input.
 132377761   always_ff @(posedge i_clk_core) begin : p_ff_data
 132377761     casez ({i_start, i_clr, reg_run})
~074688       3'b1??:  reg_st <= i_state ^ {256'b0, i_block};
~1409240       3'b01?:  reg_st <= '0;
~1792512       3'b001:  reg_st <= w_st_nxt;
 129101321       default: reg_st <= reg_st;
            endcase
          end
        
          // The result is the state register; the done flag is the registered end of the last round.
          assign o_result = reg_st;
          assign o_done   = reg_done;
        
        
          // Parity of the state register (PARA_PAR = 1): one even-parity bit per 32 bits of reg_st,
          // from the next value and checked while the core runs (DEC-035). Resetless like reg_st.
          logic [49:0] reg_ps;
        
 1867204   function automatic logic [49:0] f_pars(input logic [1599:0] i_d);
 93360200     for (int idx = 0; idx < 50; idx++)
 93360200       f_pars[idx] = ^i_d[32*idx +: 32];
          endfunction
        
 132377761   always_ff @(posedge i_clk_core) begin : p_ff_par
 132377761     casez ({i_start, i_clr, reg_run})
~074688       3'b1??:  reg_ps <= f_pars(i_state ^ {256'b0, i_block});
~1409240       3'b01?:  reg_ps <= '0;
~1792512       3'b001:  reg_ps <= f_pars(w_st_nxt);
 129101321       default: reg_ps <= reg_ps;
            endcase
          end
        
 000004   always_comb begin : p_com_par
 000004     o_par_err = (PARA_PAR != 32'd0) & reg_run & (f_pars(reg_st) != reg_ps);
          end
        
        endmodule
        
