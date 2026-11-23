"""Figure configurations of WF-007 to WF-017 (legal scale). Imported by wf_figures.py."""
FIG2 = {
    "wf_007_mask_change": dict(clk="dut.i_bclk_rx", grid="bit", anchor=("dut.i_ws_rx", "1", 1), cell=2, ncell=72, rows=[
        ("i_bclk_rx", "CLK", ""), ("i_ws_rx", "dut.i_ws_rx", "b"), ("i_sdi_0", "dut.i_sdi_0", "b"),
        ("w_mask_apb", "dut.u_csr_i2s.o_i2s_rx_mask_mask", "h"),
        ("w_mask_eff", "dut.gen_rx.u_frame_1.w_mask_eff", "h"), ("w_rx_push", "dut.gen_rx.u_rxdes.o_wr_en", "u")],
        head="WF-007 OP-006 Slot mask change at a frame boundary (corner)",
        foot="Cell = one bit clock, TDM slave with four 8-bit slots. The mask written during frame 1 (w_mask_apb, the CSR field) becomes the effective mask w_mask_eff at the start of frame 2: slot 1 is then skipped and no word is pushed for it."),
    "wf_008_unit_start": dict(clk="clk_mclk", anchor=("dut.u_csr_i2s.o_i2s_tx_ctrl_en", "1", 1), cell=2, ncell=44, rows=[
        ("i_clk_mclk", "CLK", ""), ("i2s_tx_ctrl.en", "dut.u_csr_i2s.o_i2s_tx_ctrl_en", "b"),
        ("w_snap_valid", "dut.gen_tx.u_frame_0.i_snap_valid", "b"), ("w_en_s", "dut.gen_tx.w_en_s", "b"),
        ("w_fsm_frame_state", "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state", "s"),
        ("i2s_sts.tx_busy", "dut.u_csr_i2s.i_i2s_tx_sts_busy", "b"), ("o_bclk_tx_oe", "dut.o_bclk_tx_oe", "b"),
        ("o_bclk_tx", "dut.o_bclk_tx", "b"), ("o_ws_tx", "dut.o_ws_tx", "b")],
        head="WF-008 OP-001 Unit start: snapshot and first frame (success)",
        foot="Cell = one master clock cycle (the enable bit is written in the APB domain and sampled here). The rising enable sends one configuration snapshot to the master domain; the engine goes to ARM, then RUN, the bit clock output is enabled and the frame sync falls."),
    "wf_009_tx_underrun_auto": dict(clk="dut.o_bclk_tx", grid="bit", anchor=("dut.gen_tx.w_und", "1", 1), cell=18, ncell=75, rows=[
        ("o_bclk_tx", "CLK", ""), ("o_ws_tx", "dut.o_ws_tx", "b"),
        ("w_fsm_frame_state", "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state", "s"), ("w_tx_level", "dut.w_tx_level", "n"),
        ("w_und", "dut.gen_tx.w_und", "u"), ("i2s_irq_raw.tx_und", "dut.u_csr_i2s.o_i2s_irq_raw_tx_und", "b"), ("o_sdo_0", "dut.o_sdo_0", "b")],
        head="WF-009 OP-007 Transmit underrun with automatic restart (error)",
        foot="Cell = one bit clock, auto restart on, 8-bit slots. The FIFO holds one frame (two words); when it is empty at the start of the next frame, zeros are sent, the cause tx_und is set, the unit leaves the frame and waits in ARM; two words written later restart it at a frame boundary."),
    "wf_010_rx_overrun_err": dict(clk="dut.i_bclk_rx", grid="bit", anchor=("dut.gen_rx.w_ovr", "1", 1), cell=24, ncell=60, rows=[
        ("i_bclk_rx", "CLK", ""), ("w_rx_push_try", "dut.gen_rx.u_rxdes.w_push_ev", "u"), ("w_rx_level", "dut.w_rx_level", "n"),
        ("w_ovr", "dut.gen_rx.w_ovr", "u"), ("w_fsm_frame_state", "dut.gen_rx.u_frame_1.reg_fsm_frame_current_state", "s"),
        ("i2s_irq_raw.rx_ovr", "dut.u_csr_i2s.o_i2s_irq_raw_rx_ovr", "b"), ("w_flush", "dut.gen_rx.w_flush_ev", "u")],
        head="WF-010 OP-008 Receive overrun with auto restart off (error)",
        foot="Cell = one bit clock, 8-bit slots, FIFO of 16 words. The word that finds the FIFO full is dropped, the cause rx_ovr is set and the unit enters ERR; the flush returns the unit to a clean state."),
    "wf_011_ondemand": dict(clk="dut.o_bclk_tx", grid="bit", anchor=("dut.o_ws_tx", "0", 1), cell=2, ncell=75, rows=[
        ("o_bclk_tx", "CLK", ""), ("w_tx_level", "dut.w_tx_level", "n"), ("w_ready_ok", "dut.gen_tx.u_frame_0.w_ready_ok", "b"),
        ("w_fsm_frame_state", "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state", "s"), ("o_ws_tx", "dut.o_ws_tx", "b"), ("o_sdo_0", "dut.o_sdo_0", "b")],
        head="WF-011 OP-009 On-demand frame start (corner)",
        foot="Cell = one bit clock, master with on-demand, 8-bit slots. After the frame the FIFO is empty, so the frame sync stays inactive and no frame starts until two words are written; the next frame then starts at a frame boundary."),
    "wf_012_sync_hung": dict(clk="dut.i_bclk_rx", grid="bit", anchor=("dut.gen_rx.u_frame_1.o_ev_sync", "1", 1), cell=20, ncell=105, rows=[
        ("i_bclk_rx", "CLK", ""), ("i_ws_rx", "dut.i_ws_rx", "b"), ("w_fsm_frame_state", "dut.gen_rx.u_frame_1.reg_fsm_frame_current_state", "s"),
        ("w_ev_sync", "dut.gen_rx.u_frame_1.o_ev_sync", "u"), ("i2s_irq_raw.sync", "dut.u_csr_i2s.o_i2s_irq_raw_sync", "b"),
        ("w_hung", "dut.gen_rx.u_frame_1.w_hung_pulse", "u"), ("i2s_irq_raw.hung", "dut.u_csr_i2s.o_i2s_irq_raw_hung", "b")],
        head="WF-012 OP-010 Frame sync error and hung clock, slave (error)",
        foot="Cell = one bit clock, slave with a timeout. A frame sync pulse inside a frame is ignored and sets the sync cause; later the bit clock stops and the timeout (timeout x 256 master clocks) sets the hung cause."),
    "wf_013_dma_burst": dict(clk="clk_apb", anchor=("dma_tx_req", "1", 1), cell=2, ncell=16, rows=[
        ("i_clk_apb", "CLK", ""), ("o_dma_tx_req", "dut.o_dma_tx_req", "b"), ("i_dma_tx_ack", "dut.i_dma_tx_ack", "b"),
        ("o_dma_tx_single", "dut.o_dma_tx_single", "b"), ("w_fsm_dmahs_state", "dut.gen_dma_tx.u_dmahs_tx.reg_fsm_dmahs_current_state", "d")],
        head="WF-013 OP-012 DMA burst handshake (success)",
        foot="Four-phase handshake on the APB clock: request, acknowledge, request low one cycle after the acknowledge rises, acknowledge low, request again two cycles after the acknowledge falls while the condition still holds."),
    "wf_014_dma_single": dict(clk="clk_apb", anchor=("dma_rx_ack", "1", 1), cell=2, ncell=24, rows=[
        ("i_clk_apb", "CLK", ""), ("w_rx_level", "dut.w_rx_level", "n"), ("o_dma_rx_req", "dut.o_dma_rx_req", "b"),
        ("o_dma_rx_single", "dut.o_dma_rx_single", "b"), ("i_dma_rx_ack", "dut.i_dma_rx_ack", "b")],
        head="WF-014 OP-013 DMA single transactions (success)",
        foot="Three words are in the receive FIFO, fewer than the burst length: only the single signal is high and the request stays low. The single falls one cycle after the acknowledge rises and returns after it falls while words remain."),
    "wf_015_irq_four": dict(clk="clk_apb", anchor=("dut.u_csr_i2s.o_i2s_irq_raw_tx_und", "1", 1), cell=6, ncell=42, rows=[
        ("i_clk_apb", "CLK", ""), ("w_und", "dut.gen_tx.w_und", "u"), ("i2s_irq_raw.tx_und", "dut.u_csr_i2s.o_i2s_irq_raw_tx_und", "b"),
        ("i2s_irq_en.tx_und", "dut.u_csr_i2s.o_i2s_irq_en_tx_und", "b"), ("i2s_irq_inj.tx_und", "dut.u_csr_i2s.o_i2s_irq_inj_tx_und", "b"),
        ("i2s_irq_sts.tx_und", "dut.u_csr_i2s.i_i2s_irq_sts_tx_und", "b"), ("o_int_i2s", "dut.o_int_i2s", "b")],
        head="WF-015 OP-014 Interrupt cause through raw, enable, injection and masked status (success)",
        foot="APB clock, cause tx_und from a real transmit underrun. The cause is set while masked; enabling it raises the output; a write of 1 clears the raw bit; an injection (its rising edge) sets it again; a clear while the injection bit is still high clears it and it stays clear."),
    "wf_016_stop_flush": dict(clk="clk_mclk", anchor=("dut.gen_tx.w_en_s", "0", 1), cell=4, ncell=130, rows=[
        ("i_clk_mclk", "CLK", ""), ("w_en_s", "dut.gen_tx.w_en_s", "b"),
        ("w_fsm_frame_state", "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state", "s"),
        ("i2s_sts.tx_busy", "dut.u_csr_i2s.i_i2s_tx_sts_busy", "b"), ("w_flush_ev", "dut.gen_tx.w_flush_ev", "u"),
        ("w_tx_level", "dut.w_tx_level", "n")],
        head="WF-016 OP-002 and OP-015 Unit stop, busy and flush (corner)",
        foot="Cell = one master clock cycle. Clearing the enable finishes the running frame (STOP), busy falls at its end, and a flush empties the FIFO; busy is high again while the flush is pending (ASM-019)."),
    "wf_017_reset": dict(clk="clk_apb", anchor=("rst_n_apb", "0", 1), cell=0, ncell=18, rows=[
        ("i_clk_apb", "CLK", ""), ("i_rst_n_apb", "dut.i_rst_n_apb", "b"), ("w_rst_n_apb", "dut.w_rst_n_apb", "b"),
        ("i_rst_n_mclk", "dut.i_rst_n_mclk", "b"), ("w_rst_n_mclk", "dut.w_rst_n_mclk", "b"),
        ("o_bclk_tx", "dut.o_bclk_tx", "b"), ("o_sdo_0", "dut.o_sdo_0", "b")],
        head="WF-017 OP-017 Reset assertion and release on both domains (corner)",
        foot="Cells are APB clock cycles (13 ns); the master clock is 10 ns. Assertion is asynchronous; each internal reset releases on the second clock edge of its domain. Outputs are low while the reset is active."),
}
