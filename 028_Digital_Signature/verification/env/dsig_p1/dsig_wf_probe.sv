// dsig_wf_probe.sv - names of the signals of the waveform figures of the specification (section
// 10.3.1), taken from the simulation nets by hierarchical name. Only the VCD dump of a waveform
// scenario uses it (evidence for the comparison with the specification figure). Test code only.
`timescale 1ns/1ps

module dsig_wf_probe;

  wire        i_clk_core                 = tb_dsig_p1.clk_core;
  wire        o_dsig_cmd_start           = tb_dsig_p1.dut.w_cmd_start;
  wire        i_hw_clr_dsig_cmd_start    = tb_dsig_p1.dut.w_cmd_start_clr;
  wire        o_dsig_cmd_abort           = tb_dsig_p1.dut.w_cmd_abort;
  wire        i_hw_clr_dsig_cmd_abort    = tb_dsig_p1.dut.w_cmd_abort_clr;
  wire [3:0]  reg_fsm_ctl_current_state  = tb_dsig_p1.dut.u_ctl.reg_fsm_ctl_current_state;
  wire        i_dsig_sts_busy            = tb_dsig_p1.dut.w_sts_busy;
  wire        i_dsig_sts_resvld          = tb_dsig_p1.dut.w_sts_resvld;
  wire        i_dsig_sts_sigok           = tb_dsig_p1.dut.w_sts_sigok;
  wire        i_dsig_sts_edok            = tb_dsig_p1.dut.w_sts_edok;
  wire        i_dsig_sts_mlok            = tb_dsig_p1.dut.w_sts_mlok;
  wire        o_irq                      = tb_dsig_p1.irq;
  wire        o_alarm                    = tb_dsig_p1.alarm;
  wire        i_hw_we_dsig_err_algdis    = tb_dsig_p1.dut.w_err_set[0];
  wire        o_dsig_err_algdis          = tb_dsig_p1.dut.u_csr.o_dsig_err_algdis;
  wire        i_hw_we_dsig_err_vasmis    = tb_dsig_p1.dut.w_err_set[9];
  wire        i_hw_we_dsig_alarm_fault   = tb_dsig_p1.dut.w_alarm_set[0];
  wire        o_dsig_alarm_fault         = tb_dsig_p1.dut.w_alarm_flags[0];
  wire        w_vas_ok                   = tb_dsig_p1.vas_ok;
  wire        w_key_nonzero              = tb_dsig_p1.w_keys_nz;
  wire        i_hw_clr_dsig_key_0_data   = tb_dsig_p1.zero_req;
  wire [3:0]  o_dsig_op_alg              = tb_dsig_p1.dut.w_op_alg;
  wire [1:0]  o_dsig_op_hybpol           = tb_dsig_p1.dut.w_op_hybpol;
  wire        o_reg_wr_en                = tb_dsig_p1.dut.w_reg_wr_en;
  wire [15:0] o_reg_wr_addr              = tb_dsig_p1.dut.w_reg_wr_addr;
  wire [31:0] o_dsig_win_wr_data         = tb_dsig_p1.dut.w_win_wr_data;
  wire [16:0] o_dsig_win_addr_addr       = tb_dsig_p1.dut.w_win_addr;
  wire        i_hw_we_dsig_win_addr_addr = tb_dsig_p1.dut.w_win_addr_we;
  wire        o_reg_rd_en                = tb_dsig_p1.dut.w_reg_rd_en;
  wire [31:0] i_dsig_win_rd_data         = tb_dsig_p1.dut.w_win_rd_data;
  wire        i_apb_psel                 = tb_dsig_p1.apb_psel;
  wire        i_apb_penable              = tb_dsig_p1.apb_penable;
  wire        i_apb_pwrite               = tb_dsig_p1.apb_pwrite;
  wire [15:0] i_apb_paddr                = tb_dsig_p1.apb_paddr;
  wire [31:0] i_apb_pwdata               = tb_dsig_p1.apb_pwdata;
  wire [2:0]  i_apb_pprot                = tb_dsig_p1.apb_pprot;
  wire        o_apb_pready               = tb_dsig_p1.apb_pready;
  wire        o_apb_pslverr              = tb_dsig_p1.apb_pslverr;
  wire [31:0] o_apb_prdata               = tb_dsig_p1.apb_prdata;
  wire        i_protect_en               = tb_dsig_p1.protect_en;
  wire        i_slverr_en                = tb_dsig_p1.slverr_en;
  wire        o_dsig_alg_en_ed25519      = tb_dsig_p1.dut.w_alg_en[0];

endmodule
