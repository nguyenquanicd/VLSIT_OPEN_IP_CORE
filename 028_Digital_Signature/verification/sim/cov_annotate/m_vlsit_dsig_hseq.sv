//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-24
         * Description  : Hash stream sequencer of the digital signature IP (OP-008). A requester starts
         *                a job (mode and output length), writes the message as 64-bit words with a byte
         *                count and a last flag, and reads the digest or the XOF output as 64-bit words.
         *                The block is collected here, padded with the padder of the SHA2/SHA3 IP 019,
         *                run through the block engine m_vlsit_sha_eng, chained, and squeezed. Byte 0 of
         *                a word is bits [7:0]. Modes (codes of the padder of 019): 1 SHA-256, 2 SHA-384,
         *                3 SHA-512, 9 SHA3-256, 10 SHA3-384, 11 SHA3-512, 12 SHAKE128, 13 SHAKE256. The
         *                digest length is fixed for the SHA modes; the SHAKE modes return i_job_outlen
         *                bytes (at least one). Input stream: i_in_valid with o_in_ready, i_in_nb valid
         *                bytes (0 to 8, low lanes) and i_in_last on the last word (an empty message is
         *                one word with nb 0 and last 1). Output stream: o_out_valid with i_out_ready,
         *                o_out_nb bytes, o_out_last on the last. i_clr empties the job and the hash
         *                state (secret clearing). Requirements: OP-008, REQ-FUNC-011, section 10.4.
         */
        `timescale 1ns/1ps
        
        module m_vlsit_dsig_hseq #(
          // Parameter Description: build the SHA-256 core.
          // Parameter values: 0 or 1; default is 1.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_S256 = 1,
          // Parameter Description: build the SHA-512 core.
          // Parameter values: 0 or 1; default is 1.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_S512 = 1,
          // Parameter Description: build the Keccak core.
          // Parameter values: 0 or 1; default is 1.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_KECCAK = 1,
          // Parameter Description: rounds of SHA-256 per clock cycle.
          // Parameter values: divisors of 64; default is 1.
          // Parameter unit: round
          parameter logic [31:0] PARA_S256_UNR = 1,
          // Parameter Description: rounds of SHA-512 per clock cycle.
          // Parameter values: divisors of 80; default is 1.
          // Parameter unit: round
          parameter logic [31:0] PARA_S512_UNR = 1,
          // Parameter Description: Keccak rounds per clock cycle.
          // Parameter values: divisors of 24; default is 1.
          // Parameter unit: round
          parameter logic [31:0] PARA_KEC_UNR = 1,
          localparam logic [31:0] LPARA_M_S256 = 1,
          localparam logic [31:0] LPARA_M_S384 = 2,
          localparam logic [31:0] LPARA_M_S512 = 3,
          localparam logic [31:0] LPARA_M_H256 = 9,
          localparam logic [31:0] LPARA_M_H384 = 10,
          localparam logic [31:0] LPARA_M_H512 = 11,
          localparam logic [31:0] LPARA_M_SK128 = 12,
          localparam logic [31:0] LPARA_M_SK256 = 13,
          localparam logic [31:0] LPARA_FAM_S256 = 0,
          localparam logic [31:0] LPARA_FAM_S512 = 1,
          localparam logic [31:0] LPARA_FAM_KEC = 2
        ) (
          // Clock, reset and secret clearing
          input  wire         i_clk_core,
          input  wire         i_rst_n_core,
          input  wire         i_clr,
        
          // Job and input stream
          input  wire         i_job_start,
          input  wire  [3:0]  i_job_mode,
          input  wire  [15:0] i_job_outlen,
          input  wire         i_in_valid,
          input  wire  [63:0] i_in_data,
          input  wire  [3:0]  i_in_nb,
          input  wire         i_in_last,
          output logic        o_in_ready,
        
          // Output stream
          output logic        o_out_valid,
          output logic [63:0] o_out_data,
          output logic [3:0]  o_out_nb,
          output logic        o_out_last,
          input  wire         i_out_ready,
        
          // Status
          output logic        o_busy
        );
        
          // States of the sequencer
          typedef enum logic [3:0] {
            ENUM_ST_IDLE   = 4'd0,
            ENUM_ST_FILL   = 4'd1,
            ENUM_ST_ABS_ST = 4'd2,
            ENUM_ST_ABS_WT = 4'd3,
            ENUM_ST_PAD_ST = 4'd4,
            ENUM_ST_PAD_WT = 4'd5,
            ENUM_ST_OUT    = 4'd6,
            ENUM_ST_SQ_ST  = 4'd7,
            ENUM_ST_SQ_WT  = 4'd8
          } hseq_state_type_def;
        
          // Internal signal declarations
          hseq_state_type_def reg_fsm_hseq_current_state;
          hseq_state_type_def w_fsm_hseq_nxt_state;
        
          logic [3:0]     reg_mode;
          logic [15:0]    reg_outlen;
          logic [1343:0]  reg_blk;
          logic [7:0]     reg_cnt;
          logic [63:0]    reg_tot;
          logic [1599:0]  reg_state;
          logic [63:0]    reg_rem;
          logic [3:0]     reg_rem_nb;
          logic           reg_last_pend;
          logic           reg_empty_fin;
          logic           reg_second;
          logic [15:0]    reg_out_cnt;
          logic [7:0]     reg_sq_pos;
        
          logic [7:0]     w_blkb;
          logic [1:0]     w_fam;
          logic [15:0]    w_dlen;
          logic [7:0]     w_room;
          logic [3:0]     w_take;
          logic [7:0]     w_cnt_nxt;
          logic [3:0]     w_rem_nb_nxt;
          logic           w_acc;
          logic           w_full;
          logic [1343:0]  w_blk_ins;
          logic [63:0]    w_rem_data;
          logic [1343:0]  w_pad_blk;
          logic           w_two;
          logic           w_eng_start;
          logic [1343:0]  w_eng_block;
          logic [1599:0]  w_eng_state;
          logic           w_eng_done;
          logic [1599:0]  w_eng_result;
          logic [63:0]    w_oword;
          logic [3:0]     w_onb;
          logic [15:0]    w_orem;
          logic           w_olast;
          logic           w_oacc;
          logic           w_need_sq;
          logic           w_is_keccak;
        
          // Block size in bytes, family and digest length of the selected mode.
 132377765   always_comb begin : p_com_mode
 132377765     w_blkb = 8'd64;
 132377765     w_fam  = LPARA_FAM_S256[1:0];
 132377765     w_dlen = 16'd32;
 132377765     case ({28'd0, reg_mode})
~33258249       LPARA_M_S256:  begin w_blkb = 8'd64;  w_fam = LPARA_FAM_S256[1:0]; w_dlen = 16'd32; end
~4046815       LPARA_M_S384:  begin w_blkb = 8'd128; w_fam = LPARA_FAM_S512[1:0]; w_dlen = 16'd48; end
~19086150       LPARA_M_S512:  begin w_blkb = 8'd128; w_fam = LPARA_FAM_S512[1:0]; w_dlen = 16'd64; end
~013912       LPARA_M_H256:  begin w_blkb = 8'd136; w_fam = LPARA_FAM_KEC[1:0];  w_dlen = 16'd32; end
~002825       LPARA_M_H384:  begin w_blkb = 8'd104; w_fam = LPARA_FAM_KEC[1:0];  w_dlen = 16'd48; end
~016719       LPARA_M_H512:  begin w_blkb = 8'd72;  w_fam = LPARA_FAM_KEC[1:0];  w_dlen = 16'd64; end
~25111107       LPARA_M_SK128: begin w_blkb = 8'd168; w_fam = LPARA_FAM_KEC[1:0];  w_dlen = reg_outlen; end
~74002175       LPARA_M_SK256: begin w_blkb = 8'd136; w_fam = LPARA_FAM_KEC[1:0];  w_dlen = reg_outlen; end
 033123       default:       begin w_blkb = 8'd64;  w_fam = LPARA_FAM_S256[1:0]; w_dlen = 16'd32; end
            endcase
 132377765     w_is_keccak = (w_fam == LPARA_FAM_KEC[1:0]);
          end
        
          // Initial hash value of the SHA-2 modes (FIPS 180-4 sections 5.3.3 to 5.3.5); Keccak starts at 0.
~120849   function automatic logic [1599:0] f_iv(input logic [3:0] i_m);
~120849     logic [1599:0] w_ivv;
~120849     begin
~120849       w_ivv = 1600'd0;
~120849       case ({28'd0, i_m})
~085499         LPARA_M_S256: w_ivv = 1600'h5be0cd191f83d9ab9b05688c510e527fa54ff53a3c6ef372bb67ae856a09e667;
~000075         LPARA_M_S384: w_ivv = 1600'h47b5481dbefa4fa4db0c2e0d64f98fa78eb44a876858151167332667ffc00b31152fecd8f70e59399159015a3070dd17629a292a367cd507cbbb9d5dc1059ed8;
~000259         LPARA_M_S512: w_ivv = 1600'h5be0cd19137e21791f83d9abfb41bd6b9b05688c2b3e6c1f510e527fade682d1a54ff53a5f1d36f13c6ef372fe94f82bbb67ae8584caa73b6a09e667f3bcc908;
~035350         default:      w_ivv = 1600'd0;
              endcase
~120849       return w_ivv;
            end
          endfunction
        
          // Input word insertion: take as many bytes as fit into the block, keep the rest as remainder.
          assign w_room       = w_blkb - reg_cnt;
~127850391   assign w_take       = ({4'd0, i_in_nb} > w_room) ? w_room[3:0] : i_in_nb;
          assign w_cnt_nxt    = reg_cnt + {4'd0, w_take};
          assign w_rem_nb_nxt = i_in_nb - w_take;
          assign w_rem_data   = i_in_data >> {w_take, 3'b000};
          assign w_acc        = i_in_valid & o_in_ready;
          assign w_full       = (w_cnt_nxt == w_blkb);
        
 132377765   always_comb begin : p_com_ins
 132377765     w_blk_ins = reg_blk;
 1059022120     for (int l = 0; l < 8; l++) begin
~1015820208       if (l < {28'd0, w_take})
~43201912         w_blk_ins[8 * (32'(reg_cnt) + l) +: 8] = i_in_data[8 * l +: 8];
            end
          end
        
          // Padding of the last block with the padder of the SHA2/SHA3 IP 019.
          m_vlsit_sha_pad #(
            .PARA_MAXB (32'd168)
          ) u_pad (
            .i_alg    (reg_mode),
            .i_blk    (reg_blk),
            .i_n      (reg_cnt),
            .i_second (reg_second),
            .i_tot    (reg_tot),
            .o_blk    (w_pad_blk),
            .o_two    (w_two)
          );
        
          // Block engine.
          m_vlsit_sha_eng #(
            .PARA_EN_S256  (PARA_EN_S256),
            .PARA_EN_S512  (PARA_EN_S512),
            .PARA_EN_KECCAK(PARA_EN_KECCAK),
            .PARA_S256_UNR (PARA_S256_UNR),
            .PARA_S512_UNR (PARA_S512_UNR),
            .PARA_KEC_UNR  (PARA_KEC_UNR)
          ) u_eng (
            .i_clk_core   (i_clk_core),
            .i_rst_n_core (i_rst_n_core),
            .i_start      (w_eng_start),
            .i_clr        (i_clr),
            .i_fam        (w_fam),
            .i_block      (w_eng_block),
            .i_state      (w_eng_state),
            .o_done       (w_eng_done),
            .o_result     (w_eng_result)
          );
        
          // Engine request: a full block, the padded block, or a zero block for the next squeeze.
 132377765   always_comb begin : p_com_eng
 132377765     w_eng_start = (reg_fsm_hseq_current_state == ENUM_ST_ABS_ST) |
 132377765                   (reg_fsm_hseq_current_state == ENUM_ST_PAD_ST) |
                          (reg_fsm_hseq_current_state == ENUM_ST_SQ_ST);
 132377765     w_eng_block = reg_blk;
 132377765     w_eng_state = reg_state;
 132377765     case (reg_fsm_hseq_current_state)
              ENUM_ST_PAD_ST,
~6562034       ENUM_ST_PAD_WT: w_eng_block = w_pad_blk;
              ENUM_ST_SQ_ST,
~980850       ENUM_ST_SQ_WT:  w_eng_block = 1344'd0;
 124834881       default:        w_eng_block = reg_blk;
            endcase
          end
        
          // Output word: the next bytes of the digest, SHA-2 words big-endian, Keccak lanes little-endian.
 132377765   always_comb begin : p_com_out
 132377765     w_oword = 64'd0;
 1059022120     for (int k = 0; k < 8; k++) begin
~792906256       if (w_is_keccak)
~792906256         w_oword[8 * k +: 8] = reg_state[8 * (32'(reg_sq_pos) + k) +: 8];
~266115864       else if (w_fam == LPARA_FAM_S256[1:0])
 266115864         w_oword[8 * k +: 8] = reg_state[32 * ((32'(reg_out_cnt) + k) / 4) + 8 * (3 - ((32'(reg_out_cnt) + k) % 4)) +: 8];
              else
~185063720         w_oword[8 * k +: 8] = reg_state[64 * ((32'(reg_out_cnt) + k) / 8) + 8 * (7 - ((32'(reg_out_cnt) + k) % 8)) +: 8];
            end
 132377765     w_orem = w_dlen - reg_out_cnt;
~132377765     w_onb  = (w_orem > 16'd8) ? 4'd8 : w_orem[3:0];
 132377765     w_olast = (w_orem <= 16'd8);
 132377765     w_oacc  = o_out_valid & i_out_ready;
 132377765     w_need_sq = w_is_keccak & ((reg_sq_pos + 8'd8) >= w_blkb);
          end
        
          assign o_out_valid = (reg_fsm_hseq_current_state == ENUM_ST_OUT) & (w_dlen != 16'd0);
          assign o_out_data  = w_oword;
          assign o_out_nb    = w_onb;
          assign o_out_last  = w_olast;
          assign o_in_ready  = (reg_fsm_hseq_current_state == ENUM_ST_FILL);
          assign o_busy      = (reg_fsm_hseq_current_state != ENUM_ST_IDLE);
        
          // Part 1 of the FSM: state register.
 132377761   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_hseq
 132377737     if (!i_rst_n_core)
 000024       reg_fsm_hseq_current_state <= ENUM_ST_IDLE;
            else
 132377737       reg_fsm_hseq_current_state <= w_fsm_hseq_nxt_state;
          end
        
          // Part 2 of the FSM: next state.
 132377765   always_comb begin : p_com_fsm_nxt
 132377765     w_fsm_hseq_nxt_state = reg_fsm_hseq_current_state;
 132377765     case (reg_fsm_hseq_current_state)
 86375667       ENUM_ST_IDLE: begin
~86254818         if (i_job_start)
~120849           w_fsm_hseq_nxt_state = ENUM_ST_FILL;
              end
~20449261       ENUM_ST_FILL: begin
~18931806         if (w_acc) begin
~1517455           casez ({(w_rem_nb_nxt != 4'd0), i_in_last, w_full})
~001464             3'b1??:  w_fsm_hseq_nxt_state = ENUM_ST_ABS_ST;
~001143             3'b011:  w_fsm_hseq_nxt_state = ENUM_ST_ABS_ST;
~119575             3'b010:  w_fsm_hseq_nxt_state = ENUM_ST_PAD_ST;
~068470             3'b001:  w_fsm_hseq_nxt_state = ENUM_ST_ABS_ST;
~1326969             default: w_fsm_hseq_nxt_state = w_fsm_hseq_nxt_state;
                  endcase
                end
              end
~070911       ENUM_ST_ABS_ST: w_fsm_hseq_nxt_state = ENUM_ST_ABS_WT;
~4544695       ENUM_ST_ABS_WT: begin
~4473784         if (w_eng_done)
~070911         begin
~069637           if (reg_empty_fin | reg_last_pend)
~001274             w_fsm_hseq_nxt_state = ENUM_ST_PAD_ST;
                  else
~069637             w_fsm_hseq_nxt_state = ENUM_ST_FILL;
                end
              end
~120849       ENUM_ST_PAD_ST: w_fsm_hseq_nxt_state = ENUM_ST_PAD_WT;
~6441185       ENUM_ST_PAD_WT: begin
~6320336         if (w_eng_done)
~120849         begin
~120849           if (w_two & ~reg_second)
~000068             w_fsm_hseq_nxt_state = ENUM_ST_PAD_ST;
                  else
~120849             w_fsm_hseq_nxt_state = ENUM_ST_OUT;
                end
              end
~13394347       ENUM_ST_OUT: begin
%000000         if (w_dlen == 16'd0)
%000000           w_fsm_hseq_nxt_state = ENUM_ST_IDLE;
~12165460         else if (w_oacc) begin
~120849           if (w_olast)
~120849             w_fsm_hseq_nxt_state = ENUM_ST_IDLE;
~1070313           else if (w_need_sq)
~037725             w_fsm_hseq_nxt_state = ENUM_ST_SQ_ST;
                end
              end
~037725       ENUM_ST_SQ_ST: w_fsm_hseq_nxt_state = ENUM_ST_SQ_WT;
~943125       ENUM_ST_SQ_WT: begin
~905400         if (w_eng_done)
~037725           w_fsm_hseq_nxt_state = ENUM_ST_OUT;
              end
%000000       default: w_fsm_hseq_nxt_state = ENUM_ST_IDLE;
            endcase
~130968525     if (i_clr)
~1409240       w_fsm_hseq_nxt_state = ENUM_ST_IDLE;
          end
        
          // Data registers: job parameters, block, chaining state, remainder and output counters.
 132377761   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
 000024     if (!i_rst_n_core) begin
 000024       reg_mode      <= 4'd0;
 000024       reg_outlen    <= 16'd0;
 000024       reg_blk       <= 1344'd0;
 000024       reg_cnt       <= 8'd0;
 000024       reg_tot       <= 64'd0;
 000024       reg_state     <= 1600'd0;
 000024       reg_rem       <= 64'd0;
 000024       reg_rem_nb    <= 4'd0;
 000024       reg_last_pend <= 1'b0;
 000024       reg_empty_fin <= 1'b0;
 000024       reg_second    <= 1'b0;
 000024       reg_out_cnt   <= 16'd0;
 000024       reg_sq_pos    <= 8'd0;
            end
~130968497     else if (i_clr) begin
~1409240       reg_blk       <= 1344'd0;
~1409240       reg_cnt       <= 8'd0;
~1409240       reg_tot       <= 64'd0;
~1409240       reg_state     <= 1600'd0;
~1409240       reg_rem       <= 64'd0;
~1409240       reg_rem_nb    <= 4'd0;
~1409240       reg_last_pend <= 1'b0;
~1409240       reg_empty_fin <= 1'b0;
~1409240       reg_second    <= 1'b0;
~1409240       reg_out_cnt   <= 16'd0;
~1409240       reg_sq_pos    <= 8'd0;
            end
 130968497     else begin
 130968497       case (reg_fsm_hseq_current_state)
 84966399         ENUM_ST_IDLE: begin
~84845550           if (i_job_start) begin
~120849             reg_mode      <= i_job_mode;
~120849             reg_outlen    <= (i_job_outlen == 16'd0) ? 16'd1 : i_job_outlen;
~120849             reg_state     <= f_iv(i_job_mode);
~120849             reg_blk       <= 1344'd0;
~120849             reg_cnt       <= 8'd0;
~120849             reg_tot       <= 64'd0;
~120849             reg_rem_nb    <= 4'd0;
~120849             reg_last_pend <= 1'b0;
~120849             reg_empty_fin <= 1'b0;
~120849             reg_second    <= 1'b0;
~120849             reg_out_cnt   <= 16'd0;
~120849             reg_sq_pos    <= 8'd0;
                  end
                end
~20449261         ENUM_ST_FILL: begin
~18931806           if (w_acc) begin
~1517455             reg_blk    <= w_blk_ins;
~1517455             reg_cnt    <= w_cnt_nxt;
~1517455             reg_tot    <= reg_tot + {60'd0, i_in_nb};
~1517455             reg_rem    <= w_rem_data;
~1517455             reg_rem_nb <= w_rem_nb_nxt;
~1517455             reg_last_pend <= i_in_last;
~1517455             reg_empty_fin <= i_in_last & (w_rem_nb_nxt == 4'd0) & w_full;
                  end
                end
~070911         ENUM_ST_ABS_ST: begin
~070911           reg_second <= 1'b0;
                end
~4544695         ENUM_ST_ABS_WT: begin
~4473784           if (w_eng_done) begin
~070911             reg_state     <= w_eng_result;
~070911             reg_blk       <= {1280'd0, reg_rem};
~070911             reg_cnt       <= {4'd0, reg_rem_nb};
~070911             reg_rem_nb    <= 4'd0;
~070911             reg_rem       <= 64'd0;
~069768             if (reg_empty_fin) begin
~001143               reg_blk     <= 1344'd0;
~001143               reg_cnt     <= 8'd0;
~001143               reg_empty_fin <= 1'b0;
                    end
                  end
                end
~6441185         ENUM_ST_PAD_WT: begin
~6320336           if (w_eng_done) begin
~120849             reg_state <= w_eng_result;
~120849             if (w_two & ~reg_second)
~000068               reg_second <= 1'b1;
~120849             else begin
~120849               reg_out_cnt <= 16'd0;
~120849               reg_sq_pos  <= 8'd0;
                    end
                  end
                end
~13394347         ENUM_ST_OUT: begin
~12165460           if (w_oacc) begin
~1228887             reg_out_cnt <= reg_out_cnt + {12'd0, w_onb};
~1228887             reg_sq_pos  <= w_need_sq ? 8'd0 : (reg_sq_pos + 8'd8);
                  end
                end
~943125         ENUM_ST_SQ_WT: begin
~905400           if (w_eng_done)
~037725             reg_state <= w_eng_result;
                end
~158574         default: begin
~158574           reg_mode <= reg_mode;
                end
              endcase
            end
          end
        
        endmodule
        
