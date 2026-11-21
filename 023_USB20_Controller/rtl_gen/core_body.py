"""Body of m_usb2_core (used by gen_core.py)."""

BUS_WORDS = ['ctrl', 'dctrl', 'hport', 'hsts', 'dma_cfg', 'dma_hi', 'dma_wbase', 'dma_wlim', 'fifo_hnp', 'fifo_hpt', 'fifo_ctl', 'epi_ctl', 'epi_xfr',
             'epi_dma', 'epi_buf', 'epo_dma', 'hc_ctrl', 'hc_xfer', 'hc_dma', 'dma_map']
CFG = ['dctrl', 'hport', 'phy_acc', 'fifo_ctl', 'lpbk_sts', 'epi_ctl', 'epi_xfr', 'epo_ctl', 'epo_xfr',
       'hc_ctrl', 'hc_xfer', 'hc_cfg', 'ctrl', 'sof_cfg', 'fifo_rx', 'fifo_hnp', 'fifo_hpt', 'lpm_cfg',
       'epi_buf', 'epi_ien', 'epo_ien', 'hc_spl', 'hc_ien']
PUB = ['sts', 'dsts', 'hsts', 'phy_acc', 'lpbk_sts', 'epi_ctl', 'epi_xfr', 'epo_ctl', 'epo_xfr', 'hc_xfer',
       'hc_cfg']
SET = ['irq_raw', 'epi_int', 'epo_int', 'hc_int']
CLR = ['dctrl', 'hport', 'phy_acc', 'fifo_ctl', 'lpbk_sts', 'epi_ctl', 'epo_ctl', 'hc_ctrl']
BANK = {'epi_ctl': 'LPARA_NEP1', 'epi_xfr': 'LPARA_NEP1', 'epi_dma': 'LPARA_NEP1', 'epi_buf': 'LPARA_NEP1',
        'epi_int': 'LPARA_NEP1', 'epi_ien': 'LPARA_NEP1', 'epo_ctl': 'LPARA_NEP1', 'epo_xfr': 'LPARA_NEP1',
        'epo_dma': 'LPARA_NEP1', 'epo_int': 'LPARA_NEP1', 'epo_ien': 'LPARA_NEP1',
        'hc_ctrl': 'PARA_USB2_NUM_HC', 'hc_spl': 'PARA_USB2_NUM_HC', 'hc_xfer': 'PARA_USB2_NUM_HC',
        'hc_dma': 'PARA_USB2_NUM_HC', 'hc_int': 'PARA_USB2_NUM_HC', 'hc_ien': 'PARA_USB2_NUM_HC',
        'hc_cfg': 'PARA_USB2_NUM_HC', 'dma_map': 'PARA_USB2_NUM_DMA_CH'}


def rng(name):
    return f'[{BANK[name]}-1:0][31:0]' if name in BANK else '[31:0]'


def build_body():
    L = []
    def e(t=''):
        L.append(t)

    LOCALS = [
        ('LPARA_NEP1', 'PARA_USB2_NUM_EP + 32\'d1'),
        ('LPARA_NQ', 'PARA_USB2_NUM_EP + 32\'d4'),
        ('LPARA_HQ_NP', 'PARA_USB2_NUM_EP + 32\'d2'),
        ('LPARA_ROW_W', 'PARA_USB2_UTMI_W * 32\'d4'),
        ('LPARA_FIFO_LOG2', '$clog2(PARA_USB2_FIFO_DEPTH)'),
        ('LPARA_CLK_MHZ', '(PARA_USB2_UTMI_W == 32\'d16) ? 32\'d30 : 32\'d60'),
        ('LPARA_W16', '16'),
        ('LPARA_CELL_2FF', '2'),
        ('LPARA_KIND_DATA', '3'),
    ]
    e('  // Internal signal declarations')
    # ---- generic wires
    for n in ['w_cfg_err', 'w_rst_n_phy', 'w_rst_n_core', 'w_rst_n_bus', 'w_soft_req', 'w_phy_hold', 'w_soft_busy',
              'w_soft_clr', 'w_role_bus', 'w_ocur_flag', 'w_oc_evt', 'w_oc_act', 'w_oc_act_phy', 'w_phy_alive',
              'reg_alive', 'w_axi_err', 'w_dma_err', 'w_wake_csr']:
        e(f'  logic {n};')
    for n, w in (('w_ld_addr', '[31:0]'), ('w_ld_epi_we', '[LPARA_NEP1-1:0]'), ('w_ld_epo_we', '[LPARA_NEP1-1:0]'),
                 ('w_ld_hc_we', '[PARA_USB2_NUM_HC-1:0]')):
        e(f'  logic {w + " " if w else ""}{n};')
    for nm in BUS_WORDS:
        e(f'  logic {rng(nm)} w_bus_{nm};')
    for nm in CFG:
        e(f'  logic {rng(nm)} w_ph_{nm};')
    for nm in PUB:
        e(f'  logic {rng(nm)} w_pub_{nm};')
    for nm in SET:
        e(f'  logic {rng(nm)} w_set_{nm};')
    for nm in CLR:
        e(f'  logic {rng(nm)} w_clr_{nm};')
    # phy stream
    for n, w in (('w_phy_rx_data', '[15:0]'), ('w_phy_rx_valid', '[1:0]'), ('w_phy_rx_active', ''),
                 ('w_phy_rx_err', ''), ('w_linestate', '[1:0]'), ('w_phy_tx_data', '[15:0]'),
                 ('w_phy_tx_valid', '[1:0]'), ('w_phy_tx_ready', ''), ('w_phy_tx_abort', ''),
                 ('w_lnk_tx_data', '[15:0]'), ('w_lnk_tx_valid', '[1:0]'), 
                 ('w_hostdisc', ''), ('w_iddig', ''), ('w_avalid', ''), ('w_bvalid', ''), ('w_vbusvalid', ''),
                 ('w_sessend', ''), ('w_xcvr_sel', '[1:0]'), ('w_term_sel', ''), ('w_op_mode', '[1:0]'),
                 ('w_suspend_n', ''), ('w_dp_pd', ''), ('w_dm_pd', ''), ('w_drv_vbus', ''), ('w_chrg_vbus', ''),
                 ('w_dischrg_vbus', ''), ('w_id_pullup', ''), ('w_stp_lp', ''), ('w_lp_active', ''),
                 ('w_wake_evt', ''), ('w_reg_start', ''), ('w_reg_busy', ''), ('w_reg_done', ''),
                 ('w_reg_rdata', '[7:0]'), ('w_link_idle', '')):
        e(f'  logic {w + " " if w else ""}{n};')
    # spd
    for n, w in (('w_ch_data', '[15:0]'), ('w_ch_valid', '[1:0]'), ('w_ch_active', ''), ('w_tp_req', ''),
                 ('w_tp_pid', '[3:0]'), ('w_tp_len', '[11:0]'), ('w_tp_dat', '[15:0]'), ('w_tp_pop', ''),
                 ('w_tp_vld', ''), ('w_role_host', ''), ('w_test_nak', ''), ('w_dev_act', ''), ('w_host_act', ''), ('w_speed', '[1:0]'),
                 ('w_attached', ''), ('w_suspended', ''), ('w_l1_state', ''), ('w_susp_det', ''),
                 ('w_port_en', ''), ('w_evt_rst', ''), ('w_evt_susp', ''), ('w_evt_resume', ''),
                 ('w_evt_conn', ''), ('w_evt_disc', ''), ('w_evt_role', ''), ('w_evt_enum', ''),
                 ('w_clr_rmt_wake', ''), ('w_clr_port_rst', ''), ('w_clr_port_susp', ''), ('w_clr_port_res', ''),
                 ('w_spd_lpm_hird', '[3:0]'), ('w_spd_lpm_rw', '')):
        e(f'  logic {w + " " if w else ""}{n};')
    # link
    for n, w in (('w_tok_vld', ''), ('w_tok_ext', ''), ('w_tok_pid', '[3:0]'), ('w_tok_fld', '[10:0]'),
                 ('w_spl_vld', ''), ('w_spl_fld', '[18:0]'), ('w_hs_vld', ''), ('w_hs_pid', '[3:0]'),
                 ('w_dat_sop', ''), ('w_dat_pid', '[3:0]'), ('w_dat_n', '[1:0]'), ('w_dat_b', '[15:0]'),
                 ('w_dat_end', ''), ('w_dat_ok', ''), ('w_dat_len', '[11:0]'), ('w_err_pid', ''),
                 ('w_err_crc', ''), ('w_err_stuf', ''), ('w_err_babble', ''), ('w_rx_busy', ''),
                 ('w_pkt_end', ''), ('w_tx_busy', ''), ('w_tx_done', ''), ('w_tx_fail', ''),
                 ('w_tx_req', ''), ('w_tx_kind', '[2:0]'), ('w_tx_pid', '[3:0]'), ('w_tx_fld', '[18:0]'),
                 ('w_tx_len', '[11:0]'), ('w_src_dat', '[15:0]'), ('w_src_vld', ''), ('w_src_pop', ''),
                 ('w_lpbk_ok', '[11:0]'), ('w_lpbk_err', '[11:0]'), ):
        e(f'  logic {w + " " if w else ""}{n};')
    # engines
    for pfx in ('dev', 'host'):
        for n, w in (('tx_req', ''), ('tx_kind', '[2:0]'), ('tx_pid', '[3:0]'), ('tx_fld', '[18:0]'),
                     ('tx_len', '[11:0]'), ('rxw_sop', ''), ('rxw_tag', '[4:0]'), ('rxw_n', '[1:0]'),
                     ('rxw_b', '[15:0]'), ('rxw_end', ''), ('rxw_ok', ''), ('rxw_len', '[11:0]'),
                     ('txr_start', ''), ('txr_q', '[4:0]'), ('txr_len', '[11:0]'), ('txr_commit', ''),
                     ('txr_cancel', ''), ('evt_sof', ''), ('evt_xfer', '')):
            e(f'  logic {w + " " if w else ""}w_{pfx}_{n};')
    for n in ('w_dev_epi_ctrl_pub', 'w_dev_epi_xfer_pub', 'w_dev_epo_ctrl_pub', 'w_dev_epo_xfer_pub',
              'w_dev_epi_int_set', 'w_dev_epo_int_set', 'w_dev_epi_ctrl_clr', 'w_dev_epo_ctrl_clr'):
        e(f'  logic [LPARA_NEP1-1:0][31:0] {n};')
    for n in ('w_host_hc_xfer_pub', 'w_host_hc_cfg_pub', 'w_host_hc_int_set', 'w_host_hc_ctrl_clr'):
        e(f'  logic [PARA_USB2_NUM_HC-1:0][31:0] {n};')
    for n, w in (('w_dev_frame', '[10:0]'), ('w_dev_uframe', '[2:0]'), ('w_dev_lpm_vld', ''),
                 ('w_dev_lpm_hird', '[3:0]'), ('w_dev_lpm_rw', ''), ('w_dev_evt_udf', ''),
                 ('w_host_frame', '[13:0]'), ('w_host_busy', ''), ('w_host_lpm_evt', ''), ('w_host_lpm_ack', ''), ('w_host_lpm_clr', '')):
        e(f'  logic {w + " " if w else ""}{n};')
    # fifo
    for n, w in (('w_q_base', '[LPARA_NQ*16-1:0]'), ('w_q_size', '[LPARA_NQ*16-1:0]'), ('w_flush_vld', ''),
                 ('w_flush_q', '[4:0]'), ('w_rxw_sop', ''), ('w_rxw_tag', '[4:0]'), ('w_rxw_n', '[1:0]'),
                 ('w_rxw_b', '[15:0]'), ('w_rxw_end', ''), ('w_rxw_ok', ''), ('w_rxw_len', '[11:0]'),
                 ('w_rx_free', '[16:0]'), ('w_plq_free', ''), ('w_txr_start', ''), ('w_txr_q', '[4:0]'),
                 ('w_txr_len', '[11:0]'), ('w_txr_commit', ''), ('w_txr_cancel', ''), ('w_fifo_src_dat', '[15:0]'),
                 ('w_fifo_src_vld', ''), ('w_fifo_src_pop', ''), ('w_q_cnt', '[LPARA_NQ*17-1:0]'),
                 ('w_bp_vld', ''), ('w_bp_op', '[2:0]'), ('w_bp_q', '[4:0]'), ('w_bp_data', '[LPARA_ROW_W-1:0]'),
                 ('w_bp_rdy', ''), ('w_bp_rsp_vld', ''), ('w_bp_rsp_data', '[LPARA_ROW_W-1:0]'),
                 ('w_fev_vld', ''), ('w_fev_type', '[1:0]'), ('w_fev_q', '[4:0]'), ('w_fev_val', '[16:0]'),
                 ('w_fev_rdy', ''), ('w_fifo_ovf', ''), ('w_fifo_par', ''), ('w_rq_vld', ''), ('w_rq_op', '[2:0]'),
                 ('w_rq_q', '[4:0]'), ('w_rq_data', '[LPARA_ROW_W-1:0]'), ('w_rq_rdy', ''), ('w_rs_vld', ''),
                 ('w_rs_data', '[LPARA_ROW_W-1:0]'), ('w_rs_pop', ''), ('w_bev_vld', ''), ('w_bev_type', '[1:0]'),
                 ('w_bev_q', '[4:0]'), ('w_bev_val', '[16:0]'), ('w_bev_pop', ''), 
                 
                 
                 
                 ('reg_flc_seen', '[1:0]'), ('reg_lpclr_seen', ''), ('reg_acc_seen', ''),
                 ('w_fl_rx', ''), ('w_fl_tx', ''), ('w_acc_edge', ''),
                 ('w_lpclr_edge', ''), ('w_ep_cnt', '[LPARA_NEP1*17-1:0]'), ('w_hq_cnt', '[33:0]')):
        e(f'  logic {w + " " if w else ""}{n};')
    e()

    # ----------------------------------------------------------------- parameter check and resets
    e('  // Elaboration check of the parameters.')
    e('  m_usb2_cfgchk #(')
    e('    .PARA_USB2_ROLE       (PARA_USB2_ROLE),')
    e('    .PARA_USB2_PHY_IF     (PARA_USB2_PHY_IF),')
    e('    .PARA_USB2_UTMI_W     (PARA_USB2_UTMI_W),')
    e('    .PARA_USB2_DATA_IF    (PARA_USB2_DATA_IF),')
    e('    .PARA_USB2_SPLIT_EN   (PARA_USB2_SPLIT_EN),')
    e('    .PARA_USB2_SG_EN      (PARA_USB2_SG_EN),')
    e('    .PARA_USB2_NUM_DMA_CH (PARA_USB2_NUM_DMA_CH),')
    e('    .PARA_USB2_FIFO_DEPTH (PARA_USB2_FIFO_DEPTH),')
    e('    .PARA_USB2_TSCALE     (PARA_USB2_TSCALE),')
    e('    .PARA_USB2_AXI_DATA_W (PARA_USB2_AXI_DATA_W)')
    e('  ) u_cfgchk (')
    e('    .o_cfg_err (w_cfg_err)')
    e('  );')
    e()
    e('  // Reset controller: synchronized releases, soft reset of the engines, reset of the PHY.')
    e('  m_usb2_rst u_rst (')
    e('    .i_clk_phy    (i_clk_phy),')
    e('    .i_rst_n_phy  (i_rst_n_phy),')
    e('    .i_clk_bus    (i_clk_bus),')
    e('    .i_rst_n_bus  (i_rst_n_bus),')
    e('    .i_dft_test_en (i_dft_test_en),')
    e('    .i_soft_req   (w_soft_req),')
    e('    .i_phy_hold   (w_phy_hold),')
    e('    .o_soft_busy  (w_soft_busy),')
    e('    .o_soft_clr   (w_soft_clr),')
    e('    .o_rst_n_phy  (w_rst_n_phy),')
    e('    .o_rst_n_core (w_rst_n_core),')
    e('    .o_rst_n_bus  (w_rst_n_bus),')
    e('    .o_phy_rst_n  (o_phy_rst_n)')
    e('  );')
    e()
    e('  // Over-current protection of the port power in CLK-BUS.')
    e('  m_usb2_ocp u_ocp (')
    e('    .i_clk_bus   (i_clk_bus),')
    e('    .i_rst_n_bus (w_rst_n_bus),')
    e('    .i_ovrcur_n  (i_ovrcur_n),')
    e('    .i_oc_en     (w_bus_hport[22]),')
    e('    .i_vbus_drv  (w_bus_hport[3]),')
    e('    .i_ocur_flag (w_ocur_flag),')
    e('    .o_pwr_en    (o_vbus_pwr_en),')
    e('    .o_oc_evt    (w_oc_evt),')
    e('    .o_oc_act    (w_oc_act)')
    e('  );')
    e()
    e('  // Crossings of single status bits: the over-current state to CLK-PHY, the PHY clock alive flag')
    e('  // (the reset of CLK-PHY is released) to CLK-BUS.')
    e('  m_vlsit_afifo_sync #(')
    e('    .PARA_AFIFO_SYNC_W       (1),')
    e('    .PARA_AFIFO_SYNC_RST_VAL (0),')
    e('    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)')
    e('  ) u_sync_oc (')
    e('    .i_clk_dst   (i_clk_phy),')
    e('    .i_rst_n_dst (w_rst_n_phy),')
    e('    .i_data      (w_oc_act),')
    e('    .o_data      (w_oc_act_phy)')
    e('  );')
    e()
    e('  m_vlsit_afifo_sync #(')
    e('    .PARA_AFIFO_SYNC_W       (1),')
    e('    .PARA_AFIFO_SYNC_RST_VAL (0),')
    e('    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)')
    e('  ) u_sync_alive (')
    e('    .i_clk_dst   (i_clk_bus),')
    e('    .i_rst_n_dst (w_rst_n_bus),')
    e('    .i_data      (reg_alive),')
    e('    .o_data      (w_phy_alive)')
    e('  );')
    e()
    e('  // PHY clock alive flag in CLK-PHY.')
    e('  always_ff @(posedge i_clk_phy, negedge w_rst_n_phy) begin : p_ff_alive')
    e('    if (!w_rst_n_phy)')
    e("      reg_alive <= 1'b0;")
    e('    else')
    e("      reg_alive <= 1'b1;")
    e('  end')
    e()

    # ----------------------------------------------------------------- csr integration
    e('  // CSR integration: CSR, register crossing and interrupt block.')
    e('  m_usb2_regs #(')
    e('    .PARA_USB2_NEP1       (LPARA_NEP1),')
    e('    .PARA_USB2_NHC        (PARA_USB2_NUM_HC),')
    e('    .PARA_USB2_NUM_DMA_CH (PARA_USB2_NUM_DMA_CH),')
    e('    .PARA_USB2_ROLE_CFG   (PARA_USB2_ROLE),')
    e('    .PARA_USB2_PHY_ULPI   (PARA_USB2_PHY_IF),')
    e('    .PARA_USB2_UTMI_16    ((PARA_USB2_UTMI_W == LPARA_W16) ? 32\'d1 : 32\'d0),')
    e('    .PARA_USB2_AXI_SLAVE  (PARA_USB2_DATA_IF),')
    e('    .PARA_USB2_LPM_CFG    (PARA_USB2_LPM_EN),')
    e('    .PARA_USB2_SPLIT_CFG  (PARA_USB2_SPLIT_EN),')
    e('    .PARA_USB2_FIFO_LOG2  (LPARA_FIFO_LOG2),')
    e('    .PARA_USB2_SG_CFG     (PARA_USB2_SG_EN),')
    e('    .PARA_USB2_DBUF_CFG   (PARA_USB2_DBUF_EN),')
    e('    .PARA_USB2_PAR_CFG    (PARA_USB2_RAM_PAR_EN),')
    e('    .PARA_USB2_PIPE_XREG  (PARA_USB2_PIPE_XREG)')
    e('  ) u_regs (')
    c = ['    .i_clk_bus     (i_clk_bus)', '    .i_rst_n_bus   (w_rst_n_bus)', '    .i_clk_phy     (i_clk_phy)',
         '    .i_rst_n_phy   (w_rst_n_phy)']
    for n in ('psel', 'penable', 'pwrite', 'paddr', 'pwdata', 'pstrb', 'pprot'):
        c.append(f'    .i_apb_{n} (i_apb_{n})')
    c += ['    .o_apb_pready  (o_apb_pready)', '    .o_apb_pslverr (o_apb_pslverr)', '    .o_apb_prdata  (o_apb_prdata)',
          '    .i_protect_en  (i_protect_en)', '    .i_slverr_en   (i_slverr_en)', '    .o_int_usb     (o_int_usb)',
          '    .i_phy_alive   (w_phy_alive)', '    .i_soft_busy   (w_soft_busy)', '    .i_oc_act      (w_oc_act)',
          '    .i_evt_ocur    (w_oc_evt)', '    .i_evt_axi_err (w_axi_err)', '    .i_evt_dma_err (w_dma_err)',
          '    .o_role_host   (w_role_bus)', '    .o_ocur_flag   (w_ocur_flag)', '    .o_soft_req    (w_soft_req)',
          '    .o_phy_hold    (w_phy_hold)', '    .i_soft_clr    (w_soft_clr)', '    .i_ld_addr     (w_ld_addr)',
          '    .i_ld_epi_we   (w_ld_epi_we)', '    .i_ld_epo_we   (w_ld_epo_we)', '    .i_ld_hc_we    (w_ld_hc_we)']
    for nm in BUS_WORDS:
        c.append(f'    .o_bus_{nm} (w_bus_{nm})')
    for nm in CFG:
        c.append(f'    .o_ph_{nm} (w_ph_{nm})')
    for nm in PUB:
        c.append(f'    .i_ph_pub_{nm} (w_pub_{nm})')
    for nm in SET:
        c.append(f'    .i_ph_set_{nm} (w_set_{nm})')
    for nm in CLR:
        c.append(f'    .i_ph_clr_{nm} (w_clr_{nm})')
    e(',\n'.join(c))
    e('  );')
    e()

    # ----------------------------------------------------------------- phy interface
    e('  // PHY interface: UTMI+ or ULPI adapter with the same stream interface to the link.')
    e('  generate')
    e('    if (PARA_USB2_PHY_IF == 32\'d0) begin : gen_utmi')
    e('      m_usb2_phyif_utmi #(')
    e('        .PARA_USB2_UTMI_W      (PARA_USB2_UTMI_W),')
    e('        .PARA_USB2_PIPE_PHY_IN (PARA_USB2_PIPE_PHY_IN)')
    e('      ) u_phyif (')
    e('        .i_clk_phy            (i_clk_phy),')
    e('        .i_rst_n_phy          (w_rst_n_core),')
    for n in ('o_utmi_dataout', 'o_utmi_txvalid', 'o_utmi_txvalidh', 'i_utmi_txready', 'i_utmi_datain',
              'i_utmi_rxvalid', 'i_utmi_rxvalidh', 'i_utmi_rxactive', 'i_utmi_rxerror', 'i_utmi_linestate',
              'o_utmi_opmode', 'o_utmi_xcvrsel', 'o_utmi_termsel', 'o_utmi_suspend_n', 'o_utmi_databus16_8',
              'o_utmi_bitstuff_en', 'o_utmi_bitstuff_en_h', 'o_utmi_dppulldown', 'o_utmi_dmpulldown',
              'o_utmi_drvvbus', 'o_utmi_chrgvbus', 'o_utmi_dischrgvbus', 'o_utmi_idpullup', 'i_utmi_hostdisc',
              'i_utmi_iddig', 'i_utmi_avalid', 'i_utmi_bvalid', 'i_utmi_vbusvalid', 'i_utmi_sessend'):
        e(f'        .{n} ({n}),')
    e('        .i_tx_data            (w_phy_tx_data),')
    e('        .i_tx_valid           (w_phy_tx_valid),')
    e('        .o_tx_ready           (w_phy_tx_ready),')
    e('        .o_rx_data            (w_phy_rx_data),')
    e('        .o_rx_valid           (w_phy_rx_valid),')
    e('        .o_rx_active          (w_phy_rx_active),')
    e('        .o_rx_err             (w_phy_rx_err),')
    e('        .o_linestate          (w_linestate),')
    e('        .i_xcvr_sel           (w_xcvr_sel),')
    e('        .i_term_sel           (w_term_sel),')
    e('        .i_op_mode            (w_op_mode),')
    e('        .i_suspend_n          (w_suspend_n),')
    e('        .i_dp_pd              (w_dp_pd),')
    e('        .i_dm_pd              (w_dm_pd),')
    e('        .i_drv_vbus           (w_drv_vbus),')
    e('        .i_chrg_vbus          (w_chrg_vbus),')
    e('        .i_dischrg_vbus       (w_dischrg_vbus),')
    e('        .i_id_pullup          (w_id_pullup),')
    e('        .o_hostdisc           (w_hostdisc),')
    e('        .o_iddig              (w_iddig),')
    e('        .o_avalid             (w_avalid),')
    e('        .o_bvalid             (w_bvalid),')
    e('        .o_vbusvalid          (w_vbusvalid),')
    e('        .o_sessend            (w_sessend)')
    e('      );')
    e("      assign o_ulpi_stp     = 1'b0;")
    e("      assign o_ulpi_data    = 8'h00;")
    e("      assign o_ulpi_data_oe = 1'b0;")
    e("      assign w_stp_lp       = 1'b0;")
    e("      assign w_lp_active    = 1'b0;")
    e("      assign w_wake_evt     = 1'b0;")
    e("      assign w_reg_busy     = 1'b0;")
    e("      assign w_reg_done     = w_reg_start;")
    e("      assign w_reg_rdata    = 8'h00;")
    e("      assign w_phy_tx_abort = 1'b0;")
    e('    end else begin : gen_ulpi')
    e('      m_usb2_phyif_ulpi u_phyif (')
    e('        .i_clk_phy       (i_clk_phy),')
    e('        .i_rst_n_phy     (w_rst_n_core),')
    e('        .i_ulpi_dir      (i_ulpi_dir),')
    e('        .i_ulpi_nxt      (i_ulpi_nxt),')
    e('        .i_ulpi_data     (i_ulpi_data),')
    e('        .o_ulpi_stp      (o_ulpi_stp),')
    e('        .o_ulpi_data     (o_ulpi_data),')
    e('        .o_ulpi_data_oe  (o_ulpi_data_oe),')
    e('        .i_stp_lp        (w_stp_lp),')
    e('        .o_lp_active     (w_lp_active),')
    e('        .i_tx_data       (w_phy_tx_data),')
    e('        .i_tx_valid      (w_phy_tx_valid),')
    e('        .o_tx_ready      (w_phy_tx_ready),')
    e('        .o_tx_abort      (w_phy_tx_abort),')
    e('        .i_link_idle     (w_link_idle),')
    e('        .o_rx_data       (w_phy_rx_data),')
    e('        .o_rx_valid      (w_phy_rx_valid),')
    e('        .o_rx_active     (w_phy_rx_active),')
    e('        .o_rx_err        (w_phy_rx_err),')
    e('        .o_linestate     (w_linestate),')
    e('        .i_xcvr_sel      (w_xcvr_sel),')
    e('        .i_term_sel      (w_term_sel),')
    e('        .i_op_mode       (w_op_mode),')
    e('        .i_suspend_n     (w_suspend_n),')
    e('        .i_dp_pd         (w_dp_pd),')
    e('        .i_dm_pd         (w_dm_pd),')
    e('        .i_drv_vbus      (w_drv_vbus),')
    e('        .i_chrg_vbus     (w_chrg_vbus),')
    e('        .i_dischrg_vbus  (w_dischrg_vbus),')
    e('        .i_id_pullup     (w_id_pullup),')
    e('        .o_hostdisc      (w_hostdisc),')
    e('        .o_iddig         (w_iddig),')
    e('        .o_avalid        (w_avalid),')
    e('        .o_bvalid        (w_bvalid),')
    e('        .o_vbusvalid     (w_vbusvalid),')
    e('        .o_sessend       (w_sessend),')
    e('        .i_reg_start     (w_reg_start),')
    e('        .i_reg_wr        (w_ph_phy_acc[24]),')
    e('        .i_reg_addr      (w_ph_phy_acc[7:0]),')
    e('        .i_reg_wdata     (w_ph_phy_acc[15:8]),')
    e('        .o_reg_busy      (w_reg_busy),')
    e('        .o_reg_done      (w_reg_done),')
    e('        .o_reg_rdata     (w_reg_rdata)')
    e('      );')
    e('      m_usb2_ulpilp u_ulpilp (')
    e('        .i_clk_bus   (i_clk_bus),')
    e('        .i_rst_n_bus (w_rst_n_bus),')
    e('        .i_ulpi_dir  (i_ulpi_dir),')
    e('        .i_lp_active (w_lp_active),')
    e('        .i_wake_req  (w_wake_csr),')
    e('        .o_stp_lp    (w_stp_lp),')
    e('        .o_wake_evt  (w_wake_evt),')
    e('        .o_lp_sync   ()')
    e('      );')
    for n in ('o_utmi_dataout', 'o_utmi_opmode', 'o_utmi_xcvrsel'):
        w = {'o_utmi_dataout': "16'h0000", 'o_utmi_opmode': "2'b00", 'o_utmi_xcvrsel': "2'b00"}[n]
        e(f'      assign {n} = {w};')
    for n in ('o_utmi_txvalid', 'o_utmi_txvalidh', 'o_utmi_termsel', 'o_utmi_suspend_n', 'o_utmi_databus16_8',
              'o_utmi_bitstuff_en', 'o_utmi_bitstuff_en_h', 'o_utmi_dppulldown', 'o_utmi_dmpulldown',
              'o_utmi_drvvbus', 'o_utmi_chrgvbus', 'o_utmi_dischrgvbus', 'o_utmi_idpullup'):
        e(f"      assign {n} = 1'b0;")
    e('    end')
    e('  endgenerate')
    e()
    from core_body2 import part2
    part2(e)
    return L, LOCALS
