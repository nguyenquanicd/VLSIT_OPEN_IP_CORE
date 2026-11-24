// tb_checkers.svh - instances of the assertion modules. They observe the ports of the APB4
// completer and the interfaces between the blocks (internal nets of the wrapper by hierarchical
// name: evidence only). Included at the end of module tb_dsig_p1.

  dsig_apb_assert u_apb_chk (
    .i_pclk       (clk_apb),
    .i_presetn    (rst_n_apb),
    .i_psel       (apb_psel),
    .i_penable    (apb_penable),
    .i_pwrite     (apb_pwrite),
    .i_paddr      (apb_paddr),
    .i_pwdata     (apb_pwdata),
    .i_pstrb      (apb_pstrb),
    .i_pprot      (apb_pprot),
    .i_pready     (apb_pready),
    .i_pslverr    (apb_pslverr),
    .i_prdata     (apb_prdata),
    .i_protect_en (protect_en),
    .i_slverr_en  (slverr_en),
    .i_mask       (apb_mask)
  );

  dsig_p1_assert #(
    .PARA_BUF_BYTES (1024)
  ) u_core_chk (
    .i_clk            (clk_core),
    .i_rstn           (rst_n_core),
    .i_state          (dut.u_ctl.reg_fsm_ctl_current_state),
    .i_busy           (dut.w_busy),
    .i_sts            ({dut.w_sts_mlok, dut.w_sts_edok, dut.w_sts_sigok, dut.w_sts_resvld, dut.w_sts_busy}),
    .i_eng_start      (eng_start),
    .i_key_start      (key_start),
    .i_rng_start      (rng_start),
    .i_vas_start      (vas_start),
    .i_zero_req       (zero_req),
    .i_zero_done      (zero_done),
    .i_err_set        (dut.w_err_set),
    .i_alarm_set      (dut.w_alarm_set),
    .i_alg_act        (dut.w_alg_act),
    .i_locked         (dut.w_locked),
    .i_run_alg        (dut.w_run_alg),
    .i_run_op         (dut.w_run_op),
    .i_cnt_ops        (dut.w_cnt_ops),
    .i_cnt_fail       (dut.w_cnt_fail),
    .i_log_locked     (dut.w_log_locked),
    .i_irq            (irq),
    .i_irq_sts        (dut.w_irq_sts),
    .i_irq_raw        (dut.w_irq_raw),
    .i_irq_en         (dut.w_irq_en),
    .i_alarm          (alarm),
    .i_alarm_flags    (dut.w_alarm_flags),
    .i_cmd_start      (dut.w_cmd_start),
    .i_cmd_start_clr  (dut.w_cmd_start_clr),
    .i_cmd_clr_clr    (dut.w_cmd_clr_clr),
    .i_bus_wr_en      (bus_wr_en),
    .i_bus_wr_rej     (bus_wr_rej),
    .i_bus_rd_en      (bus_rd_en),
    .i_bus_rd_rej     (bus_rd_rej),
    .i_buf_err_ovf    (dut.w_buf_err_ovf),
    .i_buf_err_busy   (dut.w_buf_err_busy),
    .i_bus_rd_valid   (bus_rd_valid),
    .i_reg_wr_en      (dut.w_reg_wr_en),
    .i_reg_rd_en      (dut.w_reg_rd_en),
    .i_win_addr       (dut.w_win_addr),
    .i_win_addr_we    (dut.w_win_addr_we),
    .i_win_addr_wdata (dut.w_win_addr_wdata),
    .i_eng_rd_en      (eng_rd_en),
    .i_eng_rd_valid   (eng_rd_valid),
    .i_mask           (core_mask)
  );

  // Names of the figure signals for the waveform scenarios
  dsig_wf_probe u_wf ();
