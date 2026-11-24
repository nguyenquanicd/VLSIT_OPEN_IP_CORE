/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Poly1305 multiply-accumulate, architecture 0 (PARA_POLY_ARCH = 0): product
 *                scanning with one 32 by 32 bit multiplier. The sum s = acc + n (131 bits, five
 *                32-bit limbs) times the clamped r (four limbs) gives 20 limb products, formed one
 *                per cycle in eight columns k = 0 to 7 (limb i of s times limb k - i of r). A
 *                column accumulates its products; at the last product of the column the low 32 bits
 *                shift into the 256-bit product register and the rest carries into the next column.
 *                One more cycle folds the product modulo 2^130 - 5. A block takes 22 cycles: the
 *                start cycle, 20 product cycles and the fold cycle. The accumulator is a secret
 *                datapath register without reset: the parent clears it with i_clr. With
 *                PARA_PIPE_POLY = 1 the product is registered before the column sum, one drain
 *                cycle follows the last product, and a block takes 23 cycles (DEC-036).
 * Decisions    : DEC-025, DEC-036
 */
`timescale 1ns/1ps

module m_chacha_pmac_s32 #(
  // Parameter Description: 1 registers the 32 by 32 product before the column sum, so a block
  // takes one cycle more (block interval 23).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_POLY = 32'd0
) (
  // Clock and reset
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,

  // Clear of the accumulator
  input  wire          i_clr,

  // Clamped multiplier r and one block
  input  wire  [127:0] i_r,
  input  wire          i_start,
  input  wire  [127:0] i_blk,

  // Status and accumulator
  output logic         o_rdy,
  output logic [130:0] o_acc
);

  // FSM states: IDLE accepts a block, MUL forms the 20 limb products, DRN (PARA_PIPE_POLY = 1
  // only) adds the last registered product to the column sum, FOLD reduces the product.
  typedef enum logic [1:0] {
    ENUM_ST_IDLE = 2'b00,
    ENUM_ST_MUL  = 2'b01,
    ENUM_ST_FOLD = 2'b10,
    ENUM_ST_DRN  = 2'b11
  } pmac_state_type_def;

  // Internal signal declarations
  pmac_state_type_def reg_fsm_pmac_current_state;
  pmac_state_type_def w_fsm_pmac_nxt_state;
  logic [130:0]       reg_acc;
  logic [130:0]       reg_s;
  logic [2:0]         reg_k;
  logic [2:0]         reg_i;
  logic [79:0]        reg_col;
  logic [255:0]       reg_p;
  logic [63:0]        reg_pr;
  logic               reg_pv;
  logic               reg_ce;
  logic [63:0]        w_pr;
  logic               w_pv;
  logic               w_ce;
  logic [31:0]        w_limb_s;
  logic [31:0]        w_limb_r;
  logic [63:0]        w_prod;
  logic [79:0]        w_col_sum;
  logic [2:0]         w_j;
  logic [2:0]         w_i_max;
  logic [2:0]         w_i_min_nxt;
  logic               w_col_end;
  logic               w_last;
  logic               w_go;
  logic [130:0]       w_sum;
  logic [130:0]       w_fold;

  // A block is accepted in IDLE only.
  assign o_rdy = (reg_fsm_pmac_current_state == ENUM_ST_IDLE);
  assign w_go  = i_start & o_rdy;

  // Sum of the accumulator and the block with its added bit 2^128.
  assign w_sum = $bits(w_sum)'(reg_acc + {3'b001, i_blk});

  // Index of the limb of r that pairs with limb i of s in column k.
  assign w_j = $bits(w_j)'(reg_k - reg_i);

  // Limb i of s (five limbs, the top limb has three bits) and limb j of r (four limbs).
  always_comb begin : p_com_limb
    w_limb_s = reg_s[31:0];
    case (reg_i)
      3'd1:    w_limb_s = reg_s[63:32];
      3'd2:    w_limb_s = reg_s[95:64];
      3'd3:    w_limb_s = reg_s[127:96];
      3'd4:    w_limb_s = {29'd0, reg_s[130:128]};
      default: w_limb_s = reg_s[31:0];
    endcase
    w_limb_r = i_r[31:0];
    case (w_j[1:0])
      2'd1:    w_limb_r = i_r[63:32];
      2'd2:    w_limb_r = i_r[95:64];
      2'd3:    w_limb_r = i_r[127:96];
      default: w_limb_r = i_r[31:0];
    endcase
  end

  // The one 32 by 32 bit multiplier and the column sum.
  assign w_prod    = $bits(w_prod)'($bits(w_prod)'(w_limb_s) * $bits(w_prod)'(w_limb_r));
  // The column sum takes the product of this cycle, or with PARA_PIPE_POLY = 1 the registered
  // product of the previous cycle with its column-end flag.
  assign w_pr      = (PARA_PIPE_POLY == 32'd1) ? reg_pr : w_prod;
  assign w_pv      = (PARA_PIPE_POLY == 32'd1) ? reg_pv : (reg_fsm_pmac_current_state == ENUM_ST_MUL);
  assign w_ce      = (PARA_PIPE_POLY == 32'd1) ? reg_ce : w_col_end;
  assign w_col_sum = $bits(w_col_sum)'(reg_col + $bits(w_col_sum)'(w_pr));

  // Column bounds. Column k pairs limbs i from max(0, k - 3) to min(4, k) of s; the column ends at
  // the largest i, and the next column starts at its smallest i.
  always_comb begin : p_com_bound
    w_i_max     = 3'd4;
    w_i_min_nxt = 3'd0;
    case (reg_k)
      3'd0:    w_i_max = 3'd0;
      3'd1:    w_i_max = 3'd1;
      3'd2:    w_i_max = 3'd2;
      3'd3:    w_i_max = 3'd3;
      default: w_i_max = 3'd4;
    endcase
    case (reg_k)
      3'd3:    w_i_min_nxt = 3'd1;
      3'd4:    w_i_min_nxt = 3'd2;
      3'd5:    w_i_min_nxt = 3'd3;
      3'd6:    w_i_min_nxt = 3'd4;
      default: w_i_min_nxt = 3'd0;
    endcase
  end

  // The column ends at its last product; the scan ends at the last product of column 7.
  assign w_col_end = (reg_i == w_i_max);
  assign w_last    = w_col_end & (reg_k == 3'd7);

  // Reduction of the 256-bit product modulo 2^130 - 5.
  m_chacha_pfold u_pfold (
    .i_prod ({3'b000, reg_p}),
    .o_acc  (w_fold)
  );

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_pmac
    if (!i_rst_n_core)
      reg_fsm_pmac_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_pmac_current_state <= w_fsm_pmac_nxt_state;
  end

  // Part 2 of the FSM: IDLE goes to MUL when a block starts, MUL to FOLD after the last product,
  // FOLD to IDLE after one cycle; a clear returns to IDLE at once.
  always_comb begin : p_com_fsm_nxt
    w_fsm_pmac_nxt_state = reg_fsm_pmac_current_state;
    case (reg_fsm_pmac_current_state)
      ENUM_ST_IDLE: begin
        if (w_go)
          w_fsm_pmac_nxt_state = ENUM_ST_MUL;
      end
      ENUM_ST_MUL: begin
        if (w_last) begin
          if (PARA_PIPE_POLY == 32'd1)
            w_fsm_pmac_nxt_state = ENUM_ST_DRN;
          else
            w_fsm_pmac_nxt_state = ENUM_ST_FOLD;
        end
      end
      ENUM_ST_DRN:  w_fsm_pmac_nxt_state = ENUM_ST_FOLD;
      ENUM_ST_FOLD: w_fsm_pmac_nxt_state = ENUM_ST_IDLE;
      default:      w_fsm_pmac_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_pmac_nxt_state = ENUM_ST_IDLE;
  end

  // Pipeline flags of the registered product (PARA_PIPE_POLY = 1): control state with reset.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_pv
    if (!i_rst_n_core) begin
      reg_pv <= 1'b0;
      reg_ce <= 1'b0;
    end else begin
      reg_pv <= (reg_fsm_pmac_current_state == ENUM_ST_MUL) & ~i_clr;
      reg_ce <= w_col_end;
    end
  end

  // Secret datapath registers (no reset, qualified by the state): the sum, the scan position, the
  // column accumulator, the product and the accumulator.
  always_ff @(posedge i_clk_core) begin : p_ff_data
    if (i_clr) begin
      reg_acc <= '0;
      reg_s   <= '0;
      reg_k   <= '0;
      reg_i   <= '0;
      reg_col <= '0;
      reg_p   <= '0;
      reg_pr  <= '0;
    end else begin
      if (w_go) begin
        reg_s   <= w_sum;
        reg_k   <= 3'd0;
        reg_i   <= 3'd0;
        reg_col <= '0;
      end
      // Scan position: one step per product while the products are issued.
      if (reg_fsm_pmac_current_state == ENUM_ST_MUL) begin
        reg_pr <= w_prod;
        if (w_col_end) begin
          reg_k <= $bits(reg_k)'(reg_k + 3'd1);
          reg_i <= w_i_min_nxt;
        end else begin
          reg_i <= $bits(reg_i)'(reg_i + 3'd1);
        end
      end
      // Column sum: one product per cycle; a finished column shifts its low 32 bits into the
      // product register.
      if (w_pv) begin
        if (w_ce) begin
          reg_p   <= {w_col_sum[31:0], reg_p[255:32]};
          reg_col <= {32'd0, w_col_sum[79:32]};
        end else begin
          reg_col <= w_col_sum;
        end
      end
      if (reg_fsm_pmac_current_state == ENUM_ST_FOLD)
        reg_acc <= w_fold;
    end
  end

  // Output mapping of the accumulator.
  assign o_acc = reg_acc;

endmodule
