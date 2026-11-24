// dsig_apb_assert.sv - protocol assertions of the APB4 port of the CSR.
// Source of every rule: AMBA APB Protocol Specification IHI 0024D (converted file
// vlsit_apb_amba_apb_ihi0024d.md of the skill vlsit-asic-ip-microspec): clause 3.1 write transfers,
// 3.2 write strobes, 3.3 read transfers, 3.4 error response, 3.5 protection, 4.1 operating states,
// appendix A signal validity; and section 11.4 of the specification (APB access behavior of the CSR).
// Rules that bind the requester (the testbench master model) are marked REQ-SIDE; a test that
// breaks one on purpose masks exactly that assertion with i_mask (bit = assertion id).
`timescale 1ns/1ps

module dsig_apb_assert (
  input  wire        i_pclk,
  input  wire        i_presetn,
  input  wire        i_psel,
  input  wire        i_penable,
  input  wire        i_pwrite,
  input  wire [15:0] i_paddr,
  input  wire [31:0] i_pwdata,
  input  wire [3:0]  i_pstrb,
  input  wire [2:0]  i_pprot,
  input  wire        i_pready,
  input  wire        i_pslverr,
  input  wire [31:0] i_prdata,
  input  wire        i_protect_en,
  input  wire        i_slverr_en,
  input  wire [63:0] i_mask
);

  `include "tb_chk.svh"

  // Registers of the CSR that return 0 on a read (all fields write-only or reserved): section 11.4
  // "Read of a wo field" (dsig_cmd 0x70, dsig_win_wr 0x94, dsig_key 0x100 to 0x140).
  function automatic logic f_wo_only(input logic [15:0] a);
    begin
      f_wo_only = (a == 16'h070) | (a == 16'h094) | ((a >= 16'h100) & (a <= 16'h140));
    end
  endfunction

  // Aligned address that is not a register (section 11.4, "Aligned address that is not a register")
  function automatic logic f_unmapped(input logic [15:0] a);
    begin
      f_unmapped = (a[1:0] == 2'b00) & ((a > 16'h144) | ((a > 16'h0AC) & (a < 16'h100)) |
                   ((a > 16'h02C) & (a < 16'h040)) | ((a > 16'h0A4) & (a < 16'h0A8)));
    end
  endfunction

  reg        r_psel, r_penable, r_pwrite, r_pready;
  reg [15:0] r_paddr;
  reg [31:0] r_pwdata;
  reg [3:0]  r_pstrb;
  reg [2:0]  r_pprot;
  integer    acc_cnt;
  wire       w_last = i_psel & i_penable & i_pready;

  localparam integer LIMIT_WAIT = 64;

  initial begin
    r_psel = 0; r_penable = 0; r_pwrite = 0; r_pready = 0;
    r_paddr = 0; r_pwdata = 0; r_pstrb = 0; r_pprot = 0; acc_cnt = 0;
    as_reg(1,  "APB-01 PENABLE high only with PSEL high (IHI0024D 4.1)");
    as_reg(2,  "APB-02 SETUP lasts one cycle, PENABLE high next (IHI0024D 4.1)");
    as_reg(3,  "APB-03 ACCESS follows SETUP or ACCESS (IHI0024D 3.1.1, 4.1)");
    as_reg(4,  "APB-04 PADDR stable while PREADY low (IHI0024D 3.1.2)");
    as_reg(5,  "APB-05 PWRITE stable while PREADY low (IHI0024D 3.1.2)");
    as_reg(6,  "APB-06 PWDATA stable on a stalled write (IHI0024D 3.1.2)");
    as_reg(7,  "APB-07 PSTRB stable while PREADY low (IHI0024D 3.2)");
    as_reg(8,  "APB-08 PPROT stable while PREADY low (IHI0024D 3.1.2, 3.5)");
    as_reg(9,  "APB-09 PSEL and PENABLE held until PREADY (IHI0024D 4.1)");
    as_reg(10, "APB-10 REQ-SIDE PSTRB all low on a read (IHI0024D 3.2)");
    as_reg(11, "APB-11 PADDR not X while PSEL (IHI0024D App A)");
    as_reg(12, "APB-12 PWRITE not X while PSEL (IHI0024D App A)");
    as_reg(13, "APB-13 PWDATA not X on a write transfer (IHI0024D App A)");
    as_reg(14, "APB-14 PSTRB not X while PSEL (IHI0024D App A)");
    as_reg(15, "APB-15 PPROT not X while PSEL (IHI0024D App A)");
    as_reg(16, "APB-16 PREADY not X in ACCESS (IHI0024D App A)");
    as_reg(17, "APB-17 PSLVERR not X in the last cycle (IHI0024D 3.4)");
    as_reg(18, "APB-18 PRDATA not X in the last cycle of a read (IHI0024D App A)");
    as_reg(19, "APB-19 after the last cycle PENABLE low for the next transfer (IHI0024D 4.1)");
    as_reg(20, "APB-20 bounded progress: PREADY within 64 PCLK (REQ-IF-001)");
    as_reg(21, "APB-21 non-secure access with protect and slverr enabled gives PSLVERR (11.4, 3.5)");
    as_reg(22, "APB-22 write with PSTRB not all ones gives PSLVERR (11.4, DEC-024, 3.2)");
    as_reg(23, "APB-23 unaligned PADDR gives PSLVERR (11.4)");
    as_reg(24, "APB-24 aligned secure full-strobe access to a register is OKAY (11.4, 3.4)");
    as_reg(25, "APB-25 read of a write-only register returns 0 (11.4, REQ-SEC-001)");
    as_reg(26, "APB-26 read of an aligned non-register returns 0 and is OKAY (11.4)");
    as_reg(27, "APB-27 read of dsig_version returns 0x00010000 (REQ-REG-003)");
    as_reg(28, "APB-28 PSLVERR low when slverr is disabled (11.4, 3.4)");
    as_reg(29, "APB-29 PREADY not X while presetn is high and PSEL is high (IHI0024D App A)");
  end

  always @(posedge i_pclk) begin
    if (i_presetn === 1'b1) begin
      as_chk(1,  i_penable & ~i_mask[1],                           i_psel);
      as_chk(2,  r_psel & ~r_penable & ~i_mask[2],                 i_penable & i_psel);
      as_chk(3,  i_psel & i_penable & ~i_mask[3],                  r_psel);
      as_chk(4,  r_psel & r_penable & ~r_pready & ~i_mask[4],      i_paddr == r_paddr);
      as_chk(5,  r_psel & r_penable & ~r_pready & ~i_mask[5],      i_pwrite == r_pwrite);
      as_chk(6,  r_psel & r_penable & ~r_pready & r_pwrite & ~i_mask[6], i_pwdata == r_pwdata);
      as_chk(7,  r_psel & r_penable & ~r_pready & ~i_mask[7],      i_pstrb == r_pstrb);
      as_chk(8,  r_psel & r_penable & ~r_pready & ~i_mask[8],      i_pprot == r_pprot);
      as_chk(9,  r_psel & r_penable & ~r_pready & ~i_mask[9],      i_psel & i_penable);
      as_chk(10, i_psel & ~i_pwrite & ~i_mask[10],                 i_pstrb == 4'h0);
      as_chk(11, i_psel & ~i_mask[11],                             ~(^i_paddr === 1'bx));
      as_chk(12, i_psel & ~i_mask[12],                             ~(^i_pwrite === 1'bx));
      as_chk(13, i_psel & i_pwrite & ~i_mask[13],                  ~(^i_pwdata === 1'bx));
      as_chk(14, i_psel & ~i_mask[14],                             ~(^i_pstrb === 1'bx));
      as_chk(15, i_psel & ~i_mask[15],                             ~(^i_pprot === 1'bx));
      as_chk(16, i_psel & i_penable & ~i_mask[16],                 ~(^i_pready === 1'bx));
      as_chk(17, w_last & ~i_mask[17],                             ~(^i_pslverr === 1'bx));
      as_chk(18, w_last & ~i_pwrite & ~i_mask[18],                 ~(^i_prdata === 1'bx));
      as_chk(19, r_psel & r_penable & r_pready & i_psel & ~i_mask[19], ~i_penable);
      as_chk(20, i_psel & i_penable & ~i_mask[20],                 acc_cnt <= LIMIT_WAIT);
      as_chk(21, w_last & i_pprot[1] & i_protect_en & i_slverr_en & ~i_mask[21], i_pslverr);
      as_chk(22, w_last & i_pwrite & (i_pstrb != 4'hF) & ~i_pprot[1] & i_slverr_en & ~i_mask[22],
                 i_pslverr);
      as_chk(23, w_last & (i_paddr[1:0] != 2'b00) & i_slverr_en & ~i_mask[23], i_pslverr);
      as_chk(24, w_last & (i_paddr[1:0] == 2'b00) & ~i_pprot[1] & (~i_pwrite | (i_pstrb == 4'hF)) &
                 (i_paddr <= 16'h144) & ~i_mask[24],               ~i_pslverr);
      as_chk(25, w_last & ~i_pwrite & f_wo_only(i_paddr) & (i_paddr[1:0] == 2'b00) & ~i_pprot[1] &
                 ~i_mask[25],                                      i_prdata == 32'h0);
      as_chk(26, w_last & ~i_pwrite & f_unmapped(i_paddr) & ~i_pprot[1] & ~i_mask[26],
                 (i_prdata == 32'h0) & ~i_pslverr);
      as_chk(27, w_last & ~i_pwrite & (i_paddr == 16'h000) & ~i_pprot[1] & ~i_mask[27],
                 i_prdata == 32'h0001_0000);
      as_chk(28, w_last & ~i_slverr_en & ~i_mask[28],              ~i_pslverr);
      as_chk(29, i_psel & i_penable & ~i_mask[29],                 ~(^i_pready === 1'bx));
      if (i_psel & i_penable & ~i_pready) acc_cnt <= acc_cnt + 1; else acc_cnt <= 0;
    end else begin
      acc_cnt <= 0;
    end
    r_psel    <= i_psel;
    r_penable <= i_penable;
    r_pwrite  <= i_pwrite;
    r_pready  <= i_pready;
    r_paddr   <= i_paddr;
    r_pwdata  <= i_pwdata;
    r_pstrb   <= i_pstrb;
    r_pprot   <= i_pprot;
  end

endmodule
