//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-24
         * Description  : Hash arbiter of the digital signature IP (section 10.4, SVA-002). It gives the
         *                hash stream sequencer to one requester at a time. A requester raises its
         *                request and holds it until it has finished with the sequencer (all its jobs);
         *                the grant stays with the owner until its request falls, then the next request
         *                in fixed priority order is granted (index 0 first; in the top: elliptic-curve
         *                engine, lattice engine, hash-based engine, random block). The grant is
         *                registered, so the owner sees it one cycle after its request. The stream
         *                signals of the owner go to the sequencer and the sequencer answers only the
         *                owner. Requirements: SVA-002, OP-008.
         */
        `timescale 1ns/1ps
        
        module m_vlsit_dsig_harb #(
          // Parameter Description: number of requesters.
          // Parameter values: 1 to 8; default is 4.
          // Parameter unit: none
          parameter logic [31:0] PARA_NREQ = 4
        ) (
          // Clock and reset
          input  wire                     i_clk_core,
          input  wire                     i_rst_n_core,
        
          // Requesters: request, job start and input stream, packed one field per requester
          input  wire  [PARA_NREQ-1:0]    i_req,
          input  wire  [PARA_NREQ-1:0]    i_job_start,
          input  wire  [4*PARA_NREQ-1:0]  i_job_mode,
          input  wire  [16*PARA_NREQ-1:0] i_job_outlen,
          input  wire  [PARA_NREQ-1:0]    i_in_valid,
          input  wire  [64*PARA_NREQ-1:0] i_in_data,
          input  wire  [4*PARA_NREQ-1:0]  i_in_nb,
          input  wire  [PARA_NREQ-1:0]    i_in_last,
          input  wire  [PARA_NREQ-1:0]    i_out_ready,
        
          // Requesters: grant and the answers of the sequencer
          output logic [PARA_NREQ-1:0]    o_grant,
          output logic [PARA_NREQ-1:0]    o_in_ready,
          output logic [PARA_NREQ-1:0]    o_out_valid,
          output logic [64*PARA_NREQ-1:0] o_out_data,
          output logic [4*PARA_NREQ-1:0]  o_out_nb,
          output logic [PARA_NREQ-1:0]    o_out_last,
        
          // Sequencer side
          output logic                    o_job_start,
          output logic [3:0]              o_job_mode,
          output logic [15:0]             o_job_outlen,
          output logic                    o_in_valid,
          output logic [63:0]             o_in_data,
          output logic [3:0]              o_in_nb,
          output logic                    o_in_last,
          input  wire                     i_in_ready,
          input  wire                     i_out_valid,
          input  wire  [63:0]             i_out_data,
          input  wire  [3:0]              i_out_nb,
          input  wire                     i_out_last,
          output logic                    o_out_ready
        );
        
          // Internal signal declarations
          logic [PARA_NREQ-1:0] reg_grant;
          logic [PARA_NREQ-1:0] w_first;
          logic                 w_owner_req;
        
          // Request of the owner and the first request in priority order.
 132377765   always_comb begin : p_com_pick
 132377765     w_first     = '0;
 132377765     w_owner_req = 1'b0;
 529511060     for (int i = 0; i < PARA_NREQ; i++) begin
~483227028       if (reg_grant[i] & i_req[i])
~46284032         w_owner_req = 1'b1;
            end
 529511060     for (int i = PARA_NREQ - 1; i >= 0; i--) begin
~483106179       if (i_req[i]) begin
~46404881         w_first    = '0;
~46404881         w_first[i] = 1'b1;
              end
            end
          end
        
          // Grant register: kept while the owner requests, otherwise the first request wins.
 132377761   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_grant
 000024     if (!i_rst_n_core)
 000024       reg_grant <= '0;
~86093705     else if (!w_owner_req)
 86093705       reg_grant <= w_first;
          end
        
          assign o_grant = reg_grant;
        
          // Owner mask: the granted requester that still requests.
          logic [PARA_NREQ-1:0] w_own;
          assign w_own = reg_grant & i_req;
        
          // Function: bitwise OR of the fields of the owner (the other fields are masked off).
 529511060   function automatic logic [63:0] f_sel(input logic [64*PARA_NREQ-1:0] bus, input logic [PARA_NREQ-1:0] own, input integer w);
 529511060     logic [63:0] acc;
 529511060     begin
 529511060       acc = 64'd0;
 2118044240       for (int i = 0; i < PARA_NREQ; i++) begin
~1932908112         if (own[i])
~185136128           acc = acc | (bus[64 * i +: 64] & ((64'd1 << w) - 64'd1));
              end
 529511060       f_sel = acc;
            end
          endfunction
        
          // Packed buses with a narrower field are widened to 64-bit slots for the function.
          logic [64*PARA_NREQ-1:0] w_mode_w;
          logic [64*PARA_NREQ-1:0] w_outlen_w;
          logic [64*PARA_NREQ-1:0] w_nb_w;
          generate
            for (genvar gi = 0; gi < PARA_NREQ; gi++) begin : gen_widen
              assign w_mode_w[64 * gi +: 64]   = {60'd0, i_job_mode[4 * gi +: 4]};
              assign w_outlen_w[64 * gi +: 64] = {48'd0, i_job_outlen[16 * gi +: 16]};
              assign w_nb_w[64 * gi +: 64]     = {60'd0, i_in_nb[4 * gi +: 4]};
            end
          endgenerate
        
          // Towards the sequencer: the signals of the owner.
          logic [63:0] w_sel_mode;
          logic [63:0] w_sel_outlen;
          logic [63:0] w_sel_nb;
          assign w_sel_mode   = f_sel(w_mode_w, w_own, 4);
          assign w_sel_outlen = f_sel(w_outlen_w, w_own, 16);
          assign w_sel_nb     = f_sel(w_nb_w, w_own, 4);
          assign o_job_start  = |(w_own & i_job_start);
          assign o_job_mode   = w_sel_mode[3:0];
          assign o_job_outlen = w_sel_outlen[15:0];
          assign o_in_valid   = |(w_own & i_in_valid);
          assign o_in_data    = f_sel(i_in_data, w_own, 64);
          assign o_in_nb      = w_sel_nb[3:0];
          assign o_in_last    = |(w_own & i_in_last);
          assign o_out_ready  = |(w_own & i_out_ready);
        
          // Answers of the sequencer: only the owner sees them.
          generate
            for (genvar gi = 0; gi < PARA_NREQ; gi++) begin : gen_ans
              assign o_in_ready[gi]            = w_own[gi] & i_in_ready;
              assign o_out_valid[gi]           = w_own[gi] & i_out_valid;
~483227028       assign o_out_data[64 * gi +: 64] = w_own[gi] ? i_out_data : 64'd0;
~483227028       assign o_out_nb[4 * gi +: 4]     = w_own[gi] ? i_out_nb : 4'd0;
              assign o_out_last[gi]            = w_own[gi] & i_out_last;
            end
          endgenerate
        
        endmodule
        
