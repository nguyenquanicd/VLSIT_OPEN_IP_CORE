#!/usr/bin/env python3
"""Injected-bug (mutation) copies of the RTL for the testbench evidence (R-088).
  mutate.py make   : write verification/mutants/<id>/rtl (copy of rtl/ with one injected bug and a filelist.f with absolute paths)
  mutate.py list   : print the table of injected bugs
The testbench then runs against each copy (run_mutants.sh); a bug is caught when the run fails or does not finish."""
import os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
V = os.path.dirname(HERE)
RTL = os.path.abspath(os.path.join(V, "..", "rtl"))
OUT = os.path.join(V, "mutants")

# id, file, old text, new text, requirement the bug breaks
MUT = [
    ("M01", "m_vlsit_i2s_frame.sv", "LPARA_FMT_I2S[2:0]:    begin w_early = 1'b1;", "LPARA_FMT_I2S[2:0]:    begin w_early = 1'b0;", "REQ-FUNC-005 I2S frame sync one bit before the MSB"),
    ("M02", "m_vlsit_i2s_frame.sv", "LPARA_FMT_LJ[2:0]:     begin w_early = 1'b0;", "LPARA_FMT_LJ[2:0]:     begin w_early = 1'b1;", "REQ-FUNC-006 left-justified frame sync with the MSB"),
    ("M03", "m_vlsit_i2s_irq.sv", "assign o_sts = i_raw & i_en;", "assign o_sts = i_raw | i_en;", "REQ-IF-010 masked status is raw AND enable"),
    ("M04", "m_vlsit_i2s_rxdes.sv", "assign o_ovr   = reg_push & (|i_wr_full);", "assign o_ovr   = 1'b0;", "REQ-FUNC-015 receive overrun cause"),
    ("M05", "m_vlsit_i2s_txser.sv", "assign o_und      = w_und;", "assign o_und      = 1'b0;", "REQ-FUNC-014 transmit underrun cause"),
    ("M06", "m_vlsit_i2s_txser.sv", "(PARA_I2S_TRI_EN != 32'd0) & i_tri & i_nx_active", "1'b0 & i_tri & i_nx_active", "REQ-FUNC-020 masked slot releases the line with tri-state"),
    ("M07", "m_vlsit_i2s_frame.sv", "assign w_div_m1 = (reg_div == 16'd0) ? 16'd0 : (reg_div - 16'd1);", "assign w_div_m1 = reg_div;", "REQ-FUNC-017 bit clock half period equals the divider"),
    ("M08", "m_vlsit_i2s_dmahs.sv", "if (i_dma_en && i_wm_cond && !i_dma_ack)", "if (i_dma_en && i_wm_cond)", "REQ-FUNC-028 request not raised while acknowledged"),
    ("M09", "m_vlsit_i2s_regctl.sv", "(o_tx_level <= i_tx_wm)", "(o_tx_level < i_tx_wm)", "REQ-FUNC-016 transmit watermark at or below"),
    ("M10", "m_vlsit_i2s_regctl.sv", "(o_rx_level >= i_rx_wm)", "(o_rx_level > i_rx_wm)", "REQ-FUNC-016 receive watermark at or above"),
    ("M11", "m_vlsit_i2s_txser.sv", "assign w_half = i_nx_pack_hi ? w_src[LPARA_WORD_W-1 -: LPARA_HALF_W] : w_src[LPARA_HALF_W-1:0];",
     "assign w_half = i_nx_pack_hi ? w_src[LPARA_HALF_W-1:0] : w_src[LPARA_WORD_W-1 -: LPARA_HALF_W];", "REQ-FUNC-010 packing order of the halves"),
    ("M12", "m_vlsit_i2s_frame.sv", "assign o_align    = reg_align;", "assign o_align    = ~reg_align;", "REQ-FUNC-010 alignment of the sample in the word"),
    ("M13", "m_vlsit_i2s_frame.sv", "reg_ev_sync <= w_miss | w_unexp;", "reg_ev_sync <= w_miss;", "REQ-FUNC-022 frame sync inside a frame"),
    ("M14", "m_vlsit_i2s_frame.sv", "~reg_hung_lat & (reg_tmo_pre == 8'hFF) &\n                        ((reg_tmo_cnt", "~reg_hung_lat & (reg_tmo_pre == 8'h7F) &\n                        ((reg_tmo_cnt", "REQ-FUNC-023 timeout of 256 master clocks per unit"),
    ("M15", "m_vlsit_i2s_regctl.sv", "(i_tx_en | i_tx_busy_s | reg_tx_pend)", "(i_tx_en | i_tx_busy_s)", "ASM-019 busy includes the pending flush"),
    ("M16", "m_vlsit_i2s_irq.sv", "assign o_irq_any = |o_sts;", "assign o_irq_any = |i_raw;", "REQ-IF-010 pin is the OR of the masked status"),
    ("M17", "m_vlsit_i2s_regctl.sv", "assign o_tx_full  = (o_tx_level >= LPARA_TX_CAP[LPARA_LVL_W-1:0]);", "assign o_tx_full  = (o_tx_level > LPARA_TX_CAP[LPARA_LVL_W-1:0]);", "REQ-FUNC-030 full flag of the transmit FIFO"),
]


def absolute_filelist(dst_dir):
    out = []
    for line in open(os.path.join(RTL, "filelist.f"), encoding="utf-8"):
        t = line.strip()
        if not t or t.startswith("//"): continue
        src = os.path.normpath(os.path.join(RTL, t))
        mut = os.path.join(dst_dir, t)
        out.append((mut if os.path.exists(mut) else src).replace("\\", "/"))
    return out


def make():
    shutil.rmtree(OUT, ignore_errors=True)
    for mid, fname, old, new, req in MUT:
        d = os.path.join(OUT, mid, "rtl")
        os.makedirs(d)
        shutil.copy(os.path.join(RTL, fname), os.path.join(d, fname))
        p = os.path.join(d, fname)
        s = open(p, encoding="utf-8", newline="").read()
        if s.count(old) != 1:
            print(mid, "ERROR: pattern found %d times in %s" % (s.count(old), fname)); continue
        open(p, "w", encoding="utf-8", newline="").write(s.replace(old, new))
        with open(os.path.join(d, "filelist.f"), "w") as f:
            for l in absolute_filelist(d): f.write(l + "\n")
        print(mid, "ok", fname)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "list":
        for m in MUT: print("| %s | %s | %s |" % (m[0], m[1], m[4]))
    else:
        make()
