`timescale 1ns/1ps
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary 
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Do Luong Minh Hoang
// Email           : hoangdlm2@fpt.com
// Created Date    : 20 Oct 2026
// Description     : 
//    - Detailed description of the module's functionality.
//    - This is a AXi-APB bridge supports the full AXI4 and APB4.
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author           Description
// 2026-10-20   1.0        Hoang            Initial creation.
// 2026-11-07   1.1        Hoang            WD_CNT_CTRL: add CNT_EN [2],
//                                          DBGEN moved to [3], RESDIV to [7:4].
//
// This section is not intended for routine updates or minor design changes. 
// A new version is strictly reserved for major architectural shifts 
// that require software modifications across different chip generations.
//------------------------------------------------------------------------------
//Partner
//--------------------------------------
//--------------------------------------------------------------------
// Project: APB-CSR-Generator
// Generator: hoangdlm2
// Date and time: 2026-10-20 08:35:48.063589
// Module: m_vlsit_wdt_csr
// Function: Control & Status register via APB interface
// Page: VLSI Technology
//--------------------------------------------------------------------
module m_vlsit_wdt_csr # (
  localparam PARA_VERSION_OFFSET = 16'h0000,
  localparam PARA_WD_CNT_LD_OFFSET = 16'h1004,
  localparam PARA_WD_CNT_VAL_OFFSET = 16'h1008,
  localparam PARA_WD_CNT_CTRL_OFFSET = 16'h100C,
  localparam PARA_WD_INT_RAW_STAT_OFFSET = 16'h1010,
  localparam PARA_WD_INT_MASK_STAT_OFFSET = 16'h1014,
  localparam PARA_WD_INT_CLR_OFFSET = 16'h1018,
  localparam PARA_WD_DBG_STAT_OFFSET = 16'h101C

)(
  input i_bus_clk,
  input i_bus_rstn,
  input [15:0] i_paddr,
  input i_protect_en,
  input i_slverr_en,
  input [2:0] i_pprot,
  input [31:0] i_pwdata,
  input i_pwrite,
  input i_penable,
  input i_psel,
  input [3:0] i_pstrb,
  input i_unlock,
  output o_pslverr,
  output o_pready,
  output [31:0] o_prdata,
  input i_reg_clk,
  input i_reg_rstn,
  input [15:0] i_version_major,
  input [15:0] i_version_minor,
  output [31:0] o_wd_cnt_ld_ld_val,
  input [31:0] i_wd_cnt_val_cnt_val,
  output [3:0] o_wd_cnt_ctrl_resdiv,
  output o_wd_cnt_ctrl_dbgen,
  output o_wd_cnt_ctrl_cnt_en,
  output o_wd_cnt_ctrl_inten,
  output o_wd_cnt_ctrl_resen,
  input i_wd_int_raw_stat_timeout_seen,
  input i_wd_int_mask_stat_wdogmis,
  input i_wd_dbg_stat_dbg_stat,
  output o_ld_write,
  output o_int_clr
  );

  //Logic signal declaration
  logic apb_setup;
  logic apb_protect;
  logic apb_slverr;
  logic apb_complete;
  logic apb_write;
  logic apb_read;
  logic [15:0] reg_address;
  logic [31:0] reg_pwdata;
  logic reg_slverr;
  logic apb_read_en;
  logic apb_write_en;
  logic [31:0] nxt_prdata;
  logic reg_pready;
  logic [31:0] reg_prdata;
  logic read_ack;
  logic read_ack_bus_clk;
  logic reg_read_req;
  logic reg_read_ack_reg_clk_dly;
  logic read_aclk_bus_clk_falling;
  logic write_ack;
  logic write_ack_bus_clk;
  logic reg_write_req;
  logic reg_write_ack_reg_clk_dly;
  logic write_aclk_bus_clk_falling;
  logic read_req_reg_clk;
  logic reg_read_req_reg_clk_dly;
  logic write_req_reg_clk;
  logic reg_write_req_reg_clk_dly;
  logic reg_read_ack_bus_clk_dly;
  logic reg_write_ack_bus_clk_dly;
  logic [31:0] version_value;
  logic we_wd_cnt_ld;
  logic [31:0] reg_wd_cnt_ld_ld_val;
  logic [31:0] nxt_wd_cnt_ld_ld_val;
  logic [31:0] wd_cnt_ld_value;
  logic [31:0] wd_cnt_val_value;
  logic we_wd_cnt_ctrl;
  logic [3:0] reg_wd_cnt_ctrl_resdiv;
  logic [3:0] nxt_wd_cnt_ctrl_resdiv;
  logic reg_wd_cnt_ctrl_dbgen;
  logic nxt_wd_cnt_ctrl_dbgen;
  logic reg_wd_cnt_ctrl_cnt_en;
  logic nxt_wd_cnt_ctrl_cnt_en;
  logic reg_wd_cnt_ctrl_inten;
  logic nxt_wd_cnt_ctrl_inten;
  logic reg_wd_cnt_ctrl_resen;
  logic nxt_wd_cnt_ctrl_resen;
  logic [31:0] wd_cnt_ctrl_value;
  logic we_wd_int_raw_stat;
  logic [31:0] wd_int_raw_stat_value;
  logic we_wd_int_mask_stat;
  logic [31:0] wd_int_mask_stat_value;
  logic we_wd_int_clr;
  logic [31:0] wd_int_clr_value;
  logic we_wd_dbg_stat;
  logic [31:0] wd_dbg_stat_value;
  logic reg_ld_write;
  logic reg_int_clr;
  logic unlock;
  //end of logic signal declaration

  // Synchronize i_unlock to APB
  m_vlsit_lib_sync_rising_edge_async_reset_n u_vlsit_lib_sync_unlock (
    .i_clk           (i_reg_clk),
    .i_async_reset_n (i_reg_rstn),
    .i_async         (i_unlock),
    .o_sync          (unlock)
  );

  //APB general access phase assignment - START
  assign apb_setup = i_psel & ~i_penable;
  assign apb_protect = i_protect_en ? ~i_pprot[1] : 1'b1;
  assign apb_slverr = i_slverr_en ? (~apb_protect      //error in protection
                      | (|i_paddr[1:0]) //error in address 
                      | (~&i_pstrb & i_pwrite)) : 1'b0;    //error in pstrb signal
  assign apb_complete = apb_setup & (~apb_slverr);
  assign apb_write = i_pwrite & apb_complete;
  assign apb_read = ~i_pwrite & apb_complete; 
  
  //APB capture FF phase
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //address capture FF
    if(!i_bus_rstn) 
      reg_address <= '0;
    else if (apb_complete)
      reg_address <= i_paddr;
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //write data capture FF
    if(!i_bus_rstn) 
      reg_pwdata <= '0;
    else if (apb_write)
      reg_pwdata <= i_pwdata;
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //slverr output FF
    if(!i_bus_rstn) 
      reg_slverr <= '0;
    else if (apb_setup & i_slverr_en)
      reg_slverr <= apb_slverr;
  end
  assign o_pslverr = reg_slverr;
  //--------------------------------------------------------------------
  assign we_wd_cnt_ld = apb_write_en & (reg_address == PARA_WD_CNT_LD_OFFSET) & unlock;
  assign we_wd_cnt_ctrl = apb_write_en & (reg_address == PARA_WD_CNT_CTRL_OFFSET) & unlock;
  assign we_wd_int_raw_stat = apb_write_en & (reg_address == PARA_WD_INT_RAW_STAT_OFFSET) & unlock;
  assign we_wd_int_mask_stat = apb_write_en & (reg_address == PARA_WD_INT_MASK_STAT_OFFSET) & unlock;
  assign we_wd_int_clr = apb_write_en & (reg_address == PARA_WD_INT_CLR_OFFSET) & unlock;
  assign we_wd_dbg_stat = apb_write_en & (reg_address == PARA_WD_DBG_STAT_OFFSET) & unlock;

  // pulses from CSR to core
  always_ff @(posedge i_reg_clk, negedge i_reg_rstn)
  if (!i_reg_rstn) begin 
    reg_ld_write <= 1'b0; 
    reg_int_clr <= 1'b0;
  end
  else begin 
    reg_ld_write <= we_wd_cnt_ld; 
    reg_int_clr <= we_wd_int_clr; 
  end

  assign o_ld_write = reg_ld_write;
  assign o_int_clr  = reg_int_clr;


  //APB handshake synchronization (appear when option Async is selected) - START
  //--------------------------------------------------------------------
  //Bus clock - reading phase
  //--------------------------------------------------------------------
  m_vlsit_lib_sync_rising_edge_async_reset_n u_read_ack_reg2bus (
    .i_clk           (i_bus_clk),
    .i_async_reset_n (i_bus_rstn),
    .i_async         (read_ack),
    .o_sync          (read_ack_bus_clk)
  );
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_read_req <= '0;
    else begin
      casez ({read_ack_bus_clk, apb_read})
        2'b1?: reg_read_req <= '0;
        2'b01: reg_read_req <= '1;
        2'b00: reg_read_req <= reg_read_req;
        default: reg_read_req <= 'x;
      endcase
    end
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_read_ack_bus_clk_dly <= '0;
    else
      reg_read_ack_bus_clk_dly <= read_ack_bus_clk;
  end
  assign read_aclk_bus_clk_falling = reg_read_ack_bus_clk_dly & ~read_ack_bus_clk;

  //--------------------------------------------------------------------
  //Bus clock - writing phase
  //--------------------------------------------------------------------
  m_vlsit_lib_sync_rising_edge_async_reset_n u_write_ack_reg2bus (
    .i_clk (i_bus_clk),
    .i_async_reset_n (i_bus_rstn),
    .i_async (write_ack),
    .o_sync  (write_ack_bus_clk)
  );
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_write_req <= '0;
    else begin
      casez ({write_ack_bus_clk, apb_write})
        2'b1?: reg_write_req <= '0;
        2'b01: reg_write_req <= '1;
        2'b00: reg_write_req <= reg_write_req;
        default: reg_write_req <= 'x;
      endcase
    end
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_write_ack_bus_clk_dly <= '0;
    else
      reg_write_ack_bus_clk_dly <= write_ack_bus_clk;
  end
  assign write_aclk_bus_clk_falling = reg_write_ack_bus_clk_dly & ~write_ack_bus_clk;

  //--------------------------------------------------------------------
  //Reg clock - reading handshake
  //--------------------------------------------------------------------
  m_vlsit_lib_sync_rising_edge_async_reset_n u_rd_req_reg2bus (
    .i_clk (i_reg_clk),
    .i_async_reset_n (i_reg_rstn),
    .i_async (reg_read_req),
    .o_sync (read_req_reg_clk)
  );
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin
    if(!i_reg_rstn) 
      reg_read_req_reg_clk_dly <= '0;
    else
      reg_read_req_reg_clk_dly <= read_req_reg_clk;
  end
  assign apb_read_en = ~reg_read_req_reg_clk_dly & read_req_reg_clk;
  assign read_ack = reg_read_req_reg_clk_dly;

  //--------------------------------------------------------------------
  //Reg clock - writing handshake
  //--------------------------------------------------------------------
  m_vlsit_lib_sync_rising_edge_async_reset_n u_wr_req_reg2bus (
    .i_clk (i_reg_clk),
    .i_async_reset_n (i_reg_rstn),
    .i_async (reg_write_req),
    .o_sync (write_req_reg_clk)
  );
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin
    if(!i_reg_rstn) 
      reg_write_req_reg_clk_dly <= '0;
    else
      reg_write_req_reg_clk_dly <= write_req_reg_clk;
  end
  assign apb_write_en = ~reg_write_req_reg_clk_dly & write_req_reg_clk;
  assign write_ack = reg_write_req_reg_clk_dly;

  //--------------------------------------------------------------------
  //PREADY phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_pready <= '0;
    else
      reg_pready <= read_aclk_bus_clk_falling // reading complete
                | write_aclk_bus_clk_falling // writing complete
                | (apb_slverr & apb_setup);//slverr assert
  end
  assign o_pready = reg_pready;
  //--------------------------------------------------------------------


  //--------------------------------------------------------------------
  //Combine the value of version
  //--------------------------------------------------------------------
  always_comb begin
    version_value[31:16] = i_version_major;
    version_value[15:0] = i_version_minor;
  end  //Assignment for next value of wd_cnt_ld_ld_val rw
  assign nxt_wd_cnt_ld_ld_val = (we_wd_cnt_ld) ? reg_pwdata[31:0] : reg_wd_cnt_ld_ld_val;
  //FF for bit wd_cnt_ld_ld_val
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
      reg_wd_cnt_ld_ld_val <= 32'hFFFFFFFF;
    else
      reg_wd_cnt_ld_ld_val <= nxt_wd_cnt_ld_ld_val;
  end 
  assign o_wd_cnt_ld_ld_val = reg_wd_cnt_ld_ld_val;

  //--------------------------------------------------------------------
  //Combine the value of wd_cnt_ld
  //--------------------------------------------------------------------
  always_comb begin
    wd_cnt_ld_value[31:0] = reg_wd_cnt_ld_ld_val;
  end
  //--------------------------------------------------------------------
  //Combine the value of wd_cnt_val
  //--------------------------------------------------------------------
  always_comb begin
    wd_cnt_val_value[31:0] = i_wd_cnt_val_cnt_val;
  end  //Assignment for next value of wd_cnt_ctrl_resdiv rw
  assign nxt_wd_cnt_ctrl_resdiv = (we_wd_cnt_ctrl) ? reg_pwdata[7:4] : reg_wd_cnt_ctrl_resdiv;
  //FF for bit wd_cnt_ctrl_resdiv
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
      reg_wd_cnt_ctrl_resdiv <= 4'h0;
    else
      reg_wd_cnt_ctrl_resdiv <= nxt_wd_cnt_ctrl_resdiv;
  end 
  assign o_wd_cnt_ctrl_resdiv = reg_wd_cnt_ctrl_resdiv;
  //Assignment for next value of wd_cnt_ctrl_dbgen rw
  assign nxt_wd_cnt_ctrl_dbgen = (we_wd_cnt_ctrl) ? reg_pwdata[3] : reg_wd_cnt_ctrl_dbgen;
  //FF for bit wd_cnt_ctrl_dbgen
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
      reg_wd_cnt_ctrl_dbgen <= 1'h0;
    else
      reg_wd_cnt_ctrl_dbgen <= nxt_wd_cnt_ctrl_dbgen;
  end 
  assign o_wd_cnt_ctrl_dbgen = reg_wd_cnt_ctrl_dbgen;
  //Assignment for next value of wd_cnt_ctrl_cnt_en rw
  assign nxt_wd_cnt_ctrl_cnt_en = (we_wd_cnt_ctrl) ? reg_pwdata[2] : reg_wd_cnt_ctrl_cnt_en;
  //FF for bit wd_cnt_ctrl_cnt_en
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
      reg_wd_cnt_ctrl_cnt_en <= 1'h0;
    else
      reg_wd_cnt_ctrl_cnt_en <= nxt_wd_cnt_ctrl_cnt_en;
  end 
  assign o_wd_cnt_ctrl_cnt_en = reg_wd_cnt_ctrl_cnt_en;
  //Assignment for next value of wd_cnt_ctrl_inten rw
  assign nxt_wd_cnt_ctrl_inten = (we_wd_cnt_ctrl) ? reg_pwdata[1] : reg_wd_cnt_ctrl_inten;
  //FF for bit wd_cnt_ctrl_inten
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
      reg_wd_cnt_ctrl_inten <= 1'h0;
    else
      reg_wd_cnt_ctrl_inten <= nxt_wd_cnt_ctrl_inten;
  end 
  assign o_wd_cnt_ctrl_inten = reg_wd_cnt_ctrl_inten;
  //Assignment for next value of wd_cnt_ctrl_resen rw
  assign nxt_wd_cnt_ctrl_resen = (we_wd_cnt_ctrl) ? reg_pwdata[0] : reg_wd_cnt_ctrl_resen;
  //FF for bit wd_cnt_ctrl_resen
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
      reg_wd_cnt_ctrl_resen <= 1'h1;
    else
      reg_wd_cnt_ctrl_resen <= nxt_wd_cnt_ctrl_resen;
  end 
  assign o_wd_cnt_ctrl_resen = reg_wd_cnt_ctrl_resen;

  //--------------------------------------------------------------------
  //Combine the value of wd_cnt_ctrl
  //--------------------------------------------------------------------
  always_comb begin
    wd_cnt_ctrl_value[31:8] = '0;
    wd_cnt_ctrl_value[7:4] = reg_wd_cnt_ctrl_resdiv;
    wd_cnt_ctrl_value[3] = reg_wd_cnt_ctrl_dbgen;
    wd_cnt_ctrl_value[2] = reg_wd_cnt_ctrl_cnt_en;
    wd_cnt_ctrl_value[1] = reg_wd_cnt_ctrl_inten;
    wd_cnt_ctrl_value[0] = reg_wd_cnt_ctrl_resen;
  end
  //--------------------------------------------------------------------
  //Combine the value of wd_int_raw_stat
  //--------------------------------------------------------------------
  always_comb begin
    wd_int_raw_stat_value[31:1] = '0;
    wd_int_raw_stat_value[0] = i_wd_int_raw_stat_timeout_seen;
  end
  //--------------------------------------------------------------------
  //Combine the value of wd_int_mask_stat
  //--------------------------------------------------------------------
  always_comb begin
    wd_int_mask_stat_value[31:1] = '0;
    wd_int_mask_stat_value[0] = i_wd_int_mask_stat_wdogmis;
  end
  //--------------------------------------------------------------------
  //Combine the value of wd_int_clr
  //--------------------------------------------------------------------
  always_comb begin
    wd_int_clr_value[31:0] = '0;
  end
  //--------------------------------------------------------------------
  //Combine the value of wd_dbg_stat
  //--------------------------------------------------------------------
  always_comb begin
    wd_dbg_stat_value[31:1] = '0;
    wd_dbg_stat_value[0] = i_wd_dbg_stat_dbg_stat;
  end
  //--------------------------------------------------------------------
  //O_PRDATA phase
  //--------------------------------------------------------------------
  always_comb begin
    case (reg_address)
      PARA_VERSION_OFFSET: nxt_prdata = version_value;
      PARA_WD_CNT_LD_OFFSET: nxt_prdata = wd_cnt_ld_value;
      PARA_WD_CNT_VAL_OFFSET: nxt_prdata = wd_cnt_val_value;
      PARA_WD_CNT_CTRL_OFFSET: nxt_prdata = wd_cnt_ctrl_value;
      PARA_WD_INT_RAW_STAT_OFFSET: nxt_prdata = wd_int_raw_stat_value;
      PARA_WD_INT_MASK_STAT_OFFSET: nxt_prdata = wd_int_mask_stat_value;
      PARA_WD_INT_CLR_OFFSET: nxt_prdata = wd_int_clr_value;
      PARA_WD_DBG_STAT_OFFSET: nxt_prdata = wd_dbg_stat_value;
      default nxt_prdata = '0;
    endcase
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_prdata <= '0;
    else if (apb_read_en)
      reg_prdata <= nxt_prdata;
  end
  assign o_prdata = reg_prdata;

endmodule: m_vlsit_wdt_csr
//-----------------------------------------------------------------
// EOFNEWLINE
//-----------------------------------------------------------------