"""Generates the WaveJSON files of the USB 2.0 controller waveform plan (section 10.3)."""
import json, os, sys

OUT = sys.argv[1]
WFS = {}


def row(name, n, ch, gaps=(), data=None):
    s = ["."] * n
    for i, c in ch.items():
        assert 0 <= i < n, (name, i, n)
        s[i] = c
    for g in gaps:
        s[g] = "|"
    r = {"name": name, "wave": "".join(s)}
    if data is not None:
        need = sum(1 for c in s if c == "=")
        assert need == len(data), (name, need, data)
        r["data"] = data
    return r


def clk(name, n, gaps=()):
    s = ["p"] + ["."] * (n - 1)
    for g in gaps:
        s[g] = "|"
    return {"name": name, "wave": "".join(s)}


def seg_rows(prefix_rx, prefix_tx, n, rx, tx, gaps, valid_data=True):
    """UTMI+ rows from receive and transmit segments [(start, [labels])]."""
    rows = []
    act, val, dat, dl = {0: "0"}, {0: "0"}, {0: "x"}, []
    for st, labs in rx:
        act[st] = "1"; val[st] = "1"
        for k in range(len(labs)):
            dat[st + k] = "="
        act[st + len(labs)] = "0"; val[st + len(labs)] = "0"; dat[st + len(labs)] = "x"
    dl = [l for st, labs in sorted(rx) for l in labs]
    tv, tr, to = {0: "0"}, {0: "0"}, {0: "x"}
    for st, labs in tx:
        tv[st] = "1"; tr[st] = "1"
        for k in range(len(labs)):
            to[st + k] = "="
        tv[st + len(labs)] = "0"; tr[st + len(labs)] = "0"; to[st + len(labs)] = "x"
    tl = [l for st, labs in sorted(tx) for l in labs]
    rows.append(["PHY to link", row("i_utmi_rxactive", n, act, gaps), row("i_utmi_rxvalid", n, val, gaps), row("i_utmi_datain", n, dat, gaps, dl)])
    rows.append(["Link to PHY", row("o_utmi_txvalid", n, tv, gaps), row("i_utmi_txready", n, tr, gaps), row("o_utmi_dataout", n, to, gaps, tl)])
    return rows


def add(wid, title, n, signals, foot, hscale=1):
    WFS[wid] = {"signal": signals, "head": {"text": "%s: %s" % (wid, title)}, "foot": {"text": foot}, "config": {"hscale": hscale}}


TOK = lambda p: [p, "ADDR", "EP,C5"]
DATA = lambda pid, a="D0", b="D1": [pid, a, b, "CRCL", "CRCH"]

# WF-001 device chirp, success --------------------------------------------------------------------
n, g = 12, (2, 4)
add("WF-001", "device reset and chirp to high-speed (OP-001, success)", n, [
    clk("i_clk_phy", n, g),
    row("i_utmi_linestate", n, {0: "=", 1: "=", 3: "=", 5: "=", 6: "=", 7: "=", 8: "=", 9: "=", 10: "=", 11: "="}, g,
        ["J", "SE0", "K", "K", "J", "K", "J", "K", "J", "SE0"]),
    row("o_utmi_txvalid", n, {0: "0", 3: "1", 5: "0"}, g),
    row("o_utmi_xcvrsel", n, {0: "=", 11: "="}, g, ["FS", "HS"]),
    row("o_utmi_termsel", n, {0: "1", 11: "0"}, g),
    row("u2_irq_raw.enum", n, {0: "0", 11: "1"}, g)],
    "Not to scale. Cycle 1: bus reset starts (T0). Cycle 3: device Chirp K (1 to 7 ms). Cycles 5 to 10: hub K-J-K-J-K-J. Cycle 11: high-speed termination on, enum flag set.")

# WF-002 chirp fail -----------------------------------------------------------------------------
n, g = 10, (2, 5)
add("WF-002", "no hub chirp, device falls back to full-speed (OP-001, corner)", n, [
    clk("i_clk_phy", n, g),
    row("i_utmi_linestate", n, {0: "=", 1: "=", 3: "=", 4: "=", 6: "=", 7: "="}, g, ["J", "SE0", "K", "SE0", "SE0", "J"]),
    row("o_utmi_txvalid", n, {0: "0", 3: "1", 4: "0"}, g),
    row("o_utmi_xcvrsel", n, {0: "="}, g, ["FS"]),
    row("o_utmi_termsel", n, {0: "1"}, g),
    row("u2_irq_raw.enum", n, {0: "0", 7: "1"}, g)],
    "Not to scale. The device sends Chirp K (cycle 3), sees no K-J-K-J-K-J within 1.0 to 2.5 ms (gap), and stays full-speed with the pull-up on.")

# WF-003 device OUT ACK ---------------------------------------------------------------------------
n = 16
add("WF-003", "device OUT data packet accepted with ACK (OP-002, success)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("OUT")), (6, DATA("DATA0"))], [(13, ["ACK"])], ()) +
    [row("u2_epo_int.done", n, {0: "0", 14: "1"})],
    "UTMI+ 8-bit, one byte per CLK-PHY cycle in high-speed. Token, data packet, then ACK within the turn-around time.")

# WF-004 device OUT CRC error ---------------------------------------------------------------------
add("WF-004", "device OUT data with CRC error, no handshake (OP-002, error)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("OUT")), (6, DATA("DATA0"))], [], ()) +
    [row("u2_irq_raw.crc_err", n, {0: "0", 12: "1"})],
    "The CRC16 residual does not match: the packet is ignored, no handshake is sent, and the crc_err flag is set (REQ-ERR-001).")

# WF-005 PING and NYET ----------------------------------------------------------------------------
n = 24
add("WF-005", "PING answered with ACK, then OUT data answered with NYET (OP-004, success)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("PING")), (9, TOK("OUT")), (13, DATA("DATA0"))], [(6, ["ACK"]), (20, ["NYET"])], ()) +
    [row("w_ep_space_one_pkt", n, {0: "1", 19: "0"})],
    "High-speed bulk OUT endpoint. PING finds space (ACK); the data packet fills the last space, so the handshake is NYET.")

# WF-006 device IN success -----------------------------------------------------------------------
n = 16
add("WF-006", "device IN data packet, host ACK (OP-003, success)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("IN")), (13, ["ACK"])], [(5, DATA("DATA1"))], ()) +
    [row("u2_epi_int.done", n, {0: "0", 15: "1"})],
    "Token, data packet with the DATA1 toggle PID, host ACK; the toggle then changes.")

# WF-007 IN NAK ----------------------------------------------------------------------------------
n = 9
add("WF-007", "device IN with no data ready, NAK (OP-003, error)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("IN"))], [(5, ["NAK"])], ()) +
    [row("u2_epi_int.nak", n, {0: "0", 7: "1"})],
    "The IN endpoint FIFO is empty or the endpoint is not armed, so the device answers NAK and the nak flag is set.")

# WF-008 SETUP -----------------------------------------------------------------------------------
n = 17
add("WF-008", "control SETUP transaction (OP-002, success)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("SETUP")), (6, ["DATA0", "B0", "B1", "B7", "CRCL", "CRCH"])], [(14, ["ACK"])], ()) +
    [row("u2_epo_int.setup", n, {0: "0", 15: "1"})],
    "SETUP data stage is always DATA0 and is ACKed; the sequence bits of host and device are equal afterwards.")

# WF-009 host reset and chirp ----------------------------------------------------------------------
n, g = 14, (3, 6, 10)
add("WF-009", "host port reset and chirp handshake (OP-005, success)", n, [
    clk("i_clk_phy", n, g),
    row("u2_hport.port_rst", n, {0: "0", 1: "1", 13: "0"}, g),
    row("i_utmi_linestate", n, {0: "=", 1: "=", 2: "=", 4: "=", 5: "=", 7: "=", 8: "=", 9: "=", 11: "=", 12: "=", 13: "="}, g,
        ["J", "SE0", "SE0", "K", "K", "K", "J", "K", "J", "SE0", "SE0"]),
    row("o_utmi_txvalid", n, {0: "0", 7: "1", 12: "0"}, g),
    row("o_utmi_xcvrsel", n, {0: "=", 13: "="}, g, ["FS", "HS"]),
    row("u2_hsts.port_en", n, {0: "0", 13: "1"}, g),
    row("u2_irq_raw.enum", n, {0: "0", 13: "1"}, g)],
    "Not to scale. Host drives SE0 for at least 50 ms; device Chirp K is seen (cycles 4 and 5); the host sends alternating K and J chirps (cycles 7 to 11), then the port is enabled at high-speed.")

# WF-010 SOF sequence -----------------------------------------------------------------------------
n, g = 16, (5, 6, 7, 8, 9, 10)
add("WF-010", "host start-of-frame every microframe (OP-006, success)", n, [
    clk("i_clk_phy", n, g),
    row("o_utmi_txvalid", n, {0: "0", 1: "1", 4: "0", 11: "1", 14: "0"}, g),
    row("i_utmi_txready", n, {0: "0", 1: "1", 4: "0", 11: "1", 14: "0"}, g),
    row("o_utmi_dataout", n, {0: "x", 1: "=", 2: "=", 3: "=", 4: "x", 11: "=", 12: "=", 13: "=", 14: "x"}, g,
        ["SOF", "FN,FN", "FN,C5", "SOF", "FN", "FN,C5"]),
    row("u2_irq_raw.sof", n, {0: "0", 2: "1"}, g)],
    "Not to scale. SOF every 125 us (+/- 0.0625 us) with the same frame number eight times, then the next frame number.")

# WF-011 host OUT and IN -------------------------------------------------------------------------
n, g = 35, (5, 6, 7, 17, 18, 24)
add("WF-011", "host OUT transaction then IN transaction (OP-007, success)", n,
    [clk("i_clk_phy", n, g)] + seg_rows("rx", "tx", n,
        [(15, ["ACK"]), (26, ["DATA1", "D0", "CRCL", "CRCH"])],
        [(1, ["OUT", "ADDR", "EP,C5"]), (8, ["DATA0", "D0", "D1", "CRCL", "CRCH"]), (20, ["IN", "ADDR", "EP,C5"]), (32, ["ACK"])], g) +
    [row("u2_hc_int.done", n, {0: "0", 34: "1"}, g)],
    "Not to scale. OUT token, at least 88 bit times (gap), data, device ACK; then IN token, device data, host ACK.", 1)

# WF-012 host timeout -----------------------------------------------------------------------------
n, g = 12, (5, 6, 7)
add("WF-012", "host IN token with no response, time-out (OP-007, error)", n,
    [clk("i_clk_phy", n, g)] + seg_rows("rx", "tx", n, [], [(1, ["IN", "ADDR", "EP,C5"])], g) +
    [row("w_turnaround_expired", n, {0: "0", 8: "1", 9: "0"}, g), row("u2_hc_int.timeout", n, {0: "0", 9: "1"}, g)],
    "Not to scale. The device does not answer within the bus turn-around time; the channel sets the timeout flag and software decides the retry.")

# WF-013 split ------------------------------------------------------------------------------------
n, g = 37, (5, 6, 7, 16, 17, 18, 24, 30)
add("WF-013", "start-split and complete-split bulk IN through a hub (OP-008, success)", n, [clk("i_clk_phy", n, g)] +
    seg_rows("rx", "tx", n, [(14, ["ACK"]), (31, ["DATA0", "D0", "CRCL", "CRCH"])],
             [(1, ["SPLIT", "HUB,SC0", "PORT"]), (9, ["IN", "ADDR", "EP,C5"]), (20, ["SPLIT", "HUB,SC1", "PORT"]), (26, ["IN", "ADDR", "EP,C5"])], g) +
    [row("u2_hc_int.done", n, {0: "0", 36: "1"}, g)],
    "Not to scale. Start-split: SPLIT token then IN token, hub ACK. Later complete-split: SPLIT token then IN token, and the hub returns the data.", 1)

# WF-014 suspend and remote wakeup ---------------------------------------------------------------
n, g = 14, (3, 9)
add("WF-014", "device suspend and remote wakeup (OP-009, success)", n, [
    clk("i_clk_phy", n, g),
    row("i_utmi_linestate", n, {0: "=", 1: "=", 4: "=", 6: "=", 7: "=", 8: "=", 10: "=", 11: "=", 12: "=", 13: "="}, g,
        ["J", "J", "J", "K", "K", "J", "K", "K", "J", "J"]),
    row("o_utmi_suspend_n", n, {0: "1", 2: "0", 6: "1"}, g),
    row("u2_dctrl.rmt_wake", n, {0: "0", 5: "1", 10: "0"}, g),
    row("u2_dsts.susp_det", n, {0: "0", 2: "1", 11: "0"}, g),
    row("u2_irq_raw.suspend", n, {0: "0", 2: "1"}, g),
    row("u2_irq_raw.resume", n, {0: "0", 12: "1"}, g)],
    "Not to scale. 3 ms idle, suspend; after 5 ms idle software sets rmt_wake, the device drives K for 1 to 15 ms; hardware clears rmt_wake.")

# WF-015 LPM --------------------------------------------------------------------------------------
n, g = 22, (10, 11, 15, 16)
add("WF-015", "LPM L1 entry and exit (OP-010, success)", n, [clk("i_clk_phy", n, g)] +
    seg_rows("rx", "tx", n, [(1, ["EXT", "ADDR", "EP,C5"]), (6, ["LPM", "bmAttr", "CRC5"])], [(12, ["ACK"])], g) +
    [row("u2_dsts.l1_state", n, {0: "0", 14: "1", 18: "0"}, g), row("u2_irq_raw.lpm_evt", n, {0: "0", 13: "1"}, g)],
    "Not to scale. EXT token and LPM token, device ACK, L1 for the HIRD time (gap), resume, then back to L0.")

# WF-016 test packet -----------------------------------------------------------------------------
n = 14
add("WF-016", "Test_Packet transmitted repeatedly (OP-011, success)", n, [
    clk("i_clk_phy", n),
    row("u2_dctrl.test_mode", n, {0: "=", 1: "="}, (), ["0", "4"]),
    row("o_utmi_txvalid", n, {0: "0", 3: "1"}),
    row("i_utmi_txready", n, {0: "0", 3: "1"}),
    row("o_utmi_dataout", n, {0: "x", 3: "=", 4: "=", 5: "=", 6: "=", 7: "=", 8: "=", 9: "=", 10: "=", 11: "=", 12: "=", 13: "="}, (),
        ["00", "00", "00", "C3", "00", "AA", "AA", "EE", "EE", "FE", "7F"])],
    "Test pattern of REF-001 section 7.1.20 (not to scale, first bytes shown); the pattern repeats until reset.")

# WF-017 AXI read burst --------------------------------------------------------------------------
n = 13
add("WF-017", "AXI master read burst into the FIFO (OP-012, success)", n, [
    clk("i_clk_bus", n),
    row("o_axim_arvalid", n, {0: "0", 1: "1", 3: "0"}),
    row("i_axim_arready", n, {0: "0", 2: "1", 3: "0"}),
    row("o_axim_araddr", n, {0: "x", 1: "=", 3: "x"}, (), ["A0"]),
    row("o_axim_arlen", n, {0: "x", 1: "=", 3: "x"}, (), ["3"]),
    row("i_axim_rvalid", n, {0: "0", 5: "1", 9: "0"}),
    row("o_axim_rready", n, {0: "0", 4: "1", 10: "0"}),
    row("i_axim_rdata", n, {0: "x", 5: "=", 6: "=", 7: "=", 8: "=", 9: "x"}, (), ["R0", "R1", "R2", "R3"]),
    row("i_axim_rlast", n, {0: "0", 8: "1", 9: "0"})],
    "INCR burst of four beats of 32 bits (awlen = 3). The data goes to the FIFO region of the endpoint.")

# WF-018 AXI write error --------------------------------------------------------------------------
n = 14
add("WF-018", "AXI master write burst with error response (OP-012, error)", n, [
    clk("i_clk_bus", n),
    row("o_axim_awvalid", n, {0: "0", 1: "1", 3: "0"}),
    row("i_axim_awready", n, {0: "0", 2: "1", 3: "0"}),
    row("o_axim_wvalid", n, {0: "0", 3: "1", 7: "0"}),
    row("i_axim_wready", n, {0: "0", 3: "1", 7: "0"}),
    row("o_axim_wlast", n, {0: "0", 6: "1", 7: "0"}),
    row("i_axim_bvalid", n, {0: "0", 8: "1", 9: "0"}),
    row("i_axim_bresp", n, {0: "x", 8: "=", 9: "x"}, (), ["SLVERR"]),
    row("u2_irq_raw.axi_err", n, {0: "0", 10: "1"}),
    row("u2_irq_raw.dma_err", n, {0: "0", 10: "1"})],
    "BRESP = SLVERR: the DMA stops the endpoint (ahb_err_stop = 1), and axi_err and dma_err are set.")

# WF-019 DMA req ack -------------------------------------------------------------------------------
n, g = 12, (6,)
add("WF-019", "external DMA request and acknowledge (OP-013, success)", n, [
    clk("i_clk_bus", n, g),
    row("w_fifo_level_ge_thr", n, {0: "0", 1: "1", 9: "0"}, g),
    row("o_dma_req", n, {0: "0", 2: "1", 8: "0"}, g),
    row("i_axis_arvalid", n, {0: "0", 3: "1", 5: "0"}, g),
    row("o_axis_rvalid", n, {0: "0", 4: "1", 7: "0"}, g),
    row("i_dma_ack", n, {0: "0", 7: "1", 8: "0"}, g)],
    "o_dma_req rises when the mapped FIFO reaches req_thr and stays high until the burst is read; the DMA controller pulses i_dma_ack once.")

# WF-020 UTMI+ backpressure and rx error ---------------------------------------------------------
n = 16
add("WF-020", "UTMI+ transmit wait and receive error (IF-001, error)", n, [
    clk("i_clk_phy", n),
    ["Link to PHY",
     row("o_utmi_txvalid", n, {0: "0", 1: "1", 7: "0"}),
     row("i_utmi_txready", n, {0: "0", 1: "1", 4: "0", 5: "1", 7: "0"}),
     row("o_utmi_dataout", n, {0: "x", 1: "=", 2: "=", 3: "=", 4: "=", 5: "=", 6: "=", 7: "x"}, (), ["PID", "B0", "B1", "B2", "B2", "B3"])],
    ["PHY to link",
     row("i_utmi_rxactive", n, {0: "0", 9: "1", 14: "0"}),
     row("i_utmi_rxvalid", n, {0: "0", 9: "1", 13: "0"}),
     row("i_utmi_rxerror", n, {0: "0", 12: "1", 14: "0"}),
     row("i_utmi_datain", n, {0: "x", 9: "=", 10: "=", 11: "=", 12: "x"}, (), ["PID", "B0", "B1"])],
    row("u2_irq_raw.stuf_err", n, {0: "0", 14: "1"})],
    "While i_utmi_txready is low (cycle 4) the byte B2 is held. A receive packet ends with i_utmi_rxerror: the packet is dropped and the stuf_err flag is set.")

# WF-021 ULPI transmit, receive, abort --------------------------------------------------------------
n = 22
add("WF-021", "ULPI transmit and receive turnaround, TX CMD aborted by dir (IF-002, success and error)", n, [
    clk("i_clk_phy", n),
    row("i_ulpi_dir", n, {0: "0", 8: "1", 13: "0", 17: "1"}),
    row("i_ulpi_nxt", n, {0: "0", 2: "1", 5: "0", 10: "1", 12: "0"}),
    row("o_ulpi_stp", n, {0: "0", 5: "1", 6: "0"}),
    row("o_ulpi_data_oe", n, {0: "0", 1: "1", 6: "0", 15: "1", 17: "0"}),
    row("o_ulpi_data", n, {0: "x", 1: "=", 2: "=", 3: "=", 4: "=", 5: "x", 15: "=", 17: "x"}, (), ["TXCMD", "D0", "D1", "D2", "TXCMD"]),
    row("i_ulpi_data", n, {0: "x", 9: "=", 10: "=", 11: "=", 12: "=", 13: "x"}, (), ["RXCMD", "D0", "D1", "D2"])],
    "TX CMD with PID, data on nxt, stp one cycle. dir rises (cycle 8): the PHY drives RX CMD and data. A second TX CMD (cycle 15) is aborted when dir rises (cycle 17): the link releases the bus at once.")

# WF-022 PHY register access -----------------------------------------------------------------------
n = 24
add("WF-022", "ULPI PHY register write then read (OP-014, success)", n, [
    clk("i_clk_phy", n),
    row("u2_phy_acc.start", n, {0: "0", 1: "1", 8: "0", 9: "1", 20: "0"}),
    row("u2_phy_acc.busy", n, {0: "0", 2: "1", 8: "0", 10: "1", 21: "0"}),
    row("i_ulpi_dir", n, {0: "0", 15: "1", 18: "0"}),
    row("i_ulpi_nxt", n, {0: "0", 3: "1", 6: "0", 12: "1", 14: "0"}),
    row("o_ulpi_stp", n, {0: "0", 6: "1", 7: "0"}),
    row("o_ulpi_data_oe", n, {0: "0", 2: "1", 7: "0", 11: "1", 15: "0"}),
    row("o_ulpi_data", n, {0: "x", 2: "=", 3: "=", 4: "x", 6: "x", 11: "=", 12: "x", 7: "x"}, (), ["REGW", "WDATA", "REGR"]),
    row("i_ulpi_data", n, {0: "x", 16: "=", 17: "x"}, (), ["RDATA"]),
    row("u2_phy_acc.rdata", n, {0: "=", 19: "="}, (), ["old", "RDATA"]),
    row("u2_irq_raw.phy_done", n, {0: "0", 8: "1"})],
    "Register write: command, address in the command, data byte, stp. Register read: command, turnaround (dir high), data byte, dir low. rdata is valid when busy falls.")

# WF-023 APB access ---------------------------------------------------------------------------------
n = 14
add("WF-023", "APB4 write, read and w1c clear of an interrupt flag (IF-003, success)", n, [
    clk("i_clk_bus", n),
    row("i_apb_psel", n, {0: "0", 1: "1", 10: "0", 11: "1", 13: "0"}),
    row("i_apb_penable", n, {0: "0", 2: "1", 4: "0", 5: "1", 7: "0", 8: "1", 10: "0"}),
    row("i_apb_pwrite", n, {0: "x", 1: "1", 4: "0", 7: "1", 10: "x"}),
    row("i_apb_paddr", n, {0: "x", 1: "=", 4: "=", 7: "=", 10: "x"}, (), ["irq_en", "irq_raw", "irq_raw"]),
    row("i_apb_pwdata", n, {0: "x", 1: "=", 4: "x", 7: "=", 10: "x"}, (), ["0x3", "0x1"]),
    row("o_apb_pready", n, {0: "0", 3: "1", 4: "0", 6: "1", 7: "0", 9: "1", 10: "0"}),
    row("o_apb_prdata", n, {0: "x", 6: "=", 7: "x"}, (), ["0x1"]),
    row("u2_irq_raw.sof", n, {0: "1", 9: "0"})],
    "Each access has one wait state: PREADY rises one cycle after PENABLE. The write of 1 to a w1c bit clears it (a new event in the same cycle would be kept).")

# WF-024 role change ---------------------------------------------------------------------------------
n, g = 14, (3, 8)
add("WF-024", "dual-role port changes from device to host on an A-plug (OP-015, success)", n, [
    clk("i_clk_phy", n, g),
    row("i_utmi_vbusvalid", n, {0: "1", 5: "0", 10: "1"}, g),
    row("i_utmi_iddig", n, {0: "1", 4: "0"}, g),
    row("o_utmi_dppulldown", n, {0: "0", 9: "1"}, g),
    row("o_utmi_dmpulldown", n, {0: "0", 9: "1"}, g),
    row("o_utmi_drvvbus", n, {0: "0", 10: "1"}, g),
    row("u2_sts.role", n, {0: "0", 11: "1"}, g),
    row("u2_irq_raw.role_chg", n, {0: "0", 11: "1"}, g)],
    "Not to scale. The B-plug cable is removed (VBUS lost), a micro-A plug is attached (ID low, 50 ms sampling), the core releases the device pull-up, enables the pull-downs and drives VBUS: the role becomes host.")

# WF-025 soft reset -----------------------------------------------------------------------------------
n = 12
add("WF-025", "soft reset of the protocol engines (IF-008, success)", n, [
    clk("i_clk_bus", n),
    row("u2_ctrl.core_en", n, {0: "1", 1: "0", 11: "1"}),
    row("u2_ctrl.soft_rst", n, {0: "0", 2: "1", 8: "0"}),
    row("u2_sts.rst_busy", n, {0: "0", 3: "1", 8: "0"}),
    row("w_rst_n_phy_core", n, {0: "1", 5: "0", 7: "1"}),
    row("o_utmi_txvalid", n, {0: "0"})],
    "Software clears core_en, writes soft_rst = 1; the pulse crosses to CLK-PHY (CDC-005), the engines are reset, hardware clears soft_rst; registers keep their values.")

# WF-026 back to back tokens --------------------------------------------------------------------------
n, g = 18, (5, 6, 7, 8, 9)
add("WF-026", "host back-to-back packets with at least 88 bit times between them (OP-007, corner)", n, [clk("i_clk_phy", n, g)] +
    seg_rows("rx", "tx", n, [], [(1, ["OUT", "ADDR", "EP,C5"]), (11, ["DATA0", "D0", "CRCL", "CRCH"])], g)[1:] +
    [row("w_ipd_cnt_ge_88bt", n, {0: "0", 3: "1", 10: "0"}, g)],
    "Not to scale. At least 88 bit times (eleven bytes in 8-bit UTMI+) separate two packets sent by the host in a row.")

# WF-027 FIFO full ------------------------------------------------------------------------------------
n = 18
add("WF-027", "device OUT with the receive region full, NAK and overflow flag (OP-002, corner)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("OUT")), (6, DATA("DATA1"))], [(14, ["NAK"])], ()) +
    [row("w_rx_region_full", n, {0: "1"}), row("u2_epo_int.nak", n, {0: "0", 16: "1"})],
    "No space for the packet: the data is not stored, the device answers NAK, and the nak flag is set; the host retries.")

# WF-028 high-bandwidth isochronous IN -------------------------------------------------------------
n, g = 34, (11, 22)
rx = [(1, ["IN", "ADDR", "EP,C5"]), (12, ["IN", "ADDR", "EP,C5"]), (23, ["IN", "ADDR", "EP,C5"])]
tx = [(6, ["DATA2", "D0", "CRCL", "CRCH"]), (17, ["DATA1", "D0", "CRCL", "CRCH"]), (28, ["DATA0", "D0", "CRCL", "CRCH"])]
add("WF-028", "high-bandwidth isochronous IN, three transactions in one microframe (OP-003, corner)", n,
    [clk("i_clk_phy", n, g)] + seg_rows("rx", "tx", n, rx, tx, g) + [row("u2_epi_ctrl.mult", n, {0: "="}, (), ["2"])],
    "Not to scale. mult = 2: DATA2, DATA1 and DATA0 PIDs follow in the three IN transactions of the microframe; isochronous has no handshake.", 1)

# WF-029 AXI 4 KB boundary ---------------------------------------------------------------------------
n = 10
add("WF-029", "AXI master burst split at the 4 KB boundary (OP-012, corner)", n, [
    clk("i_clk_bus", n),
    row("o_axim_arvalid", n, {0: "0", 1: "1", 3: "0", 5: "1", 7: "0"}),
    row("i_axim_arready", n, {0: "0", 2: "1", 3: "0", 6: "1", 7: "0"}),
    row("o_axim_araddr", n, {0: "x", 1: "=", 3: "x", 5: "=", 7: "x"}, (), ["0xFE0", "0x1000"]),
    row("o_axim_arlen", n, {0: "x", 1: "=", 3: "x", 5: "=", 7: "x"}, (), ["7", "7"])],
    "A 16-beat transfer that starts at 0xFE0 is split: eight beats up to 0xFFF, then eight beats from 0x1000, so no burst crosses a 4 KB boundary (REQ-IF-006).")

# WF-030 ULPI dir mid-packet -------------------------------------------------------------------------
n = 18
add("WF-030", "ULPI direction change in the middle of a transmit packet (IF-002, corner)", n, [
    clk("i_clk_phy", n),
    row("i_ulpi_dir", n, {0: "0", 6: "1", 13: "0"}),
    row("i_ulpi_nxt", n, {0: "0", 2: "1", 6: "0", 8: "1", 12: "0"}),
    row("o_ulpi_stp", n, {0: "0"}),
    row("o_ulpi_data_oe", n, {0: "0", 1: "1", 6: "0"}),
    row("o_ulpi_data", n, {0: "x", 1: "=", 2: "=", 3: "=", 4: "=", 5: "=", 6: "x"}, (), ["TXCMD", "D0", "D1", "D2", "D3"]),
    row("i_ulpi_data", n, {0: "x", 7: "=", 8: "=", 9: "=", 10: "x"}, (), ["RXCMD", "R0", "R1"]),
    row("w_tx_retry", n, {0: "0", 13: "1", 14: "0"})],
    "The PHY raises dir during the packet (cycle 6): the link releases the data bus at once and does not drive stp. After the receive ends (dir low) the link repeats the packet.")

# WF-031 double buffering ---------------------------------------------------------------------------
n = 34
add("WF-031", "double-buffered bulk OUT endpoint, two packets (OP-016, success)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("OUT")), (6, DATA("DATA0")), (17, TOK("OUT")), (22, DATA("DATA1"))], [(13, ["ACK"]), (30, ["ACK"])], ()) +
    [["Buffers of the endpoint region",
      row("w_buf_a", n, {0: "=", 6: "=", 12: "=", 20: "="}, (), ["free", "bus fills", "DMA drains", "free"]),
      row("w_buf_b", n, {0: "=", 22: "=", 28: "="}, (), ["free", "bus fills", "DMA drains"]),
      row("u2_epo_ctrl.buf_cur", n, {0: "0", 12: "1", 28: "0"})]],
    "Packet 1 goes to buffer A; while the DMA drains A, packet 2 is received into buffer B. buf_cur toggles at the end of each packet.")

# WF-032 automatic ZLP --------------------------------------------------------------------------------
n, g = 33, (16, 17)
add("WF-032", "automatic zero-length packet after a full packet, zlp_en = 1 (OP-017, success)", n,
    [clk("i_clk_phy", n, g)] + seg_rows("rx", "tx", n, [(1, TOK("IN")), (14, ["ACK"]), (19, TOK("IN")), (30, ["ACK"])],
                                         [(6, ["DATA1", "D0", "D511", "CRCL", "CRCH"]), (24, ["DATA0", "CRCL", "CRCH"])], g) +
    [row("u2_epi_xfer.xsize", n, {0: "=", 15: "="}, g, ["512", "0"]),
     row("w_zlp_pending", n, {0: "0", 15: "1", 31: "0"}, g),
     row("u2_epi_int.done", n, {0: "0", 31: "1"}, g)],
    "Not to scale. xsize = 512 equals one maximum packet: after the first packet is ACKed the hardware answers the next IN token with a zero-length packet, then sets done.")

# WF-033 interval polling -------------------------------------------------------------------------------
n = 34
add("WF-033", "host interval polling, NAK then retry at the next interval (OP-018, success)", n,
    [clk("i_clk_phy", n)] +
    [["Microframes and polling",
      row("w_uframe_tick", n, {0: "0", 1: "1", 2: "0", 9: "1", 10: "0", 17: "1", 18: "0", 25: "1", 26: "0"}),
      row("u2_hc_cfg.interval", n, {0: "="}, (), ["2"]),
      row("w_poll_due", n, {0: "0", 1: "1", 2: "0", 17: "1", 18: "0"})]] +
    seg_rows("rx", "tx", n, [(7, ["NAK"]), (23, ["DATA0", "D0", "CRCL", "CRCH"])], [(2, ["IN", "ADDR", "EP,C5"]), (18, ["IN", "ADDR", "EP,C5"]), (29, ["ACK"])], ()) +
    [row("u2_hc_int.nak", n, {0: "0", 9: "1"}), row("u2_hc_int.done", n, {0: "0", 31: "1"})],
    "interval = 2 microframes. The first poll is answered with NAK; the hardware retries at the next interval (two microframes later), receives the data and ACKs it.")

# WF-034 isochronous incomplete ---------------------------------------------------------------------
n = 14
add("WF-034", "isochronous IN token with no data ready, incomplete flag (OP-019, error)", n,
    [clk("i_clk_phy", n)] + seg_rows("rx", "tx", n, [(1, TOK("IN"))], [(6, ["DATA0", "CRCL", "CRCH"])], ()) +
    [row("u2_epi_int.iso_inc", n, {0: "0", 9: "1"}), row("u2_irq_raw.iso_inc", n, {0: "0", 11: "1"})],
    "The isochronous endpoint has no packet ready: the device sends a zero-length packet, nothing is retried, and the iso_inc flags are set (endpoint flag first, then the global flag after the clock crossing).")

# WF-035 over-current ------------------------------------------------------------------------------------
n, g = 18, (4, 5)
add("WF-035", "port over-current: filter, power off, flag, restore (OP-020, error)", n, [
    clk("i_clk_bus", n, g),
    row("i_ovrcur_n", n, {0: "1", 2: "0"}, g),
    row("w_oc_filter_cnt", n, {0: "=", 2: "=", 3: "=", 6: "=", 7: "=", 8: "="}, g, ["0", "1", "2", "15", "16", "0"]),
    row("o_vbus_pwr_en", n, {0: "1", 9: "0", 15: "1"}, g),
    row("o_utmi_drvvbus", n, {0: "1", 10: "0", 16: "1"}, g),
    row("u2_hsts.oc_act", n, {0: "0", 8: "1"}, g),
    row("u2_irq_raw.ocur", n, {0: "0", 8: "1", 11: "0"}, g),
    row("u2_hport.vbus_drv", n, {0: "1", 12: "0", 14: "1"}, g)],
    "Not to scale. i_ovrcur_n low for 16 CLK-BUS cycles (gap) sets ocur and oc_act; o_vbus_pwr_en falls within 2 cycles and o_utmi_drvvbus follows through CDC-001. Power returns only after software clears ocur and rewrites vbus_drv (0 then 1).")

# WF-036 scatter-gather ----------------------------------------------------------------------------------
n, g = 25, (12, 13, 14)
add("WF-036", "scatter-gather: descriptor read, data burst, status write-back (OP-021, success)", n, [
    clk("i_clk_bus", n, g),
    row("reg_fsm_dma_axi_current_state", n, {0: "=", 1: "=", 7: "=", 10: "=", 16: "=", 23: "="}, g, ["IDLE", "DESC_RD", "AR", "RDATA", "DESC_WB", "IDLE"]),
    ["Read channel",
     row("o_axim_arvalid", n, {0: "0", 1: "1", 3: "0", 8: "1", 10: "0"}, g),
     row("i_axim_arready", n, {0: "0", 2: "1", 3: "0", 9: "1", 10: "0"}, g),
     row("o_axim_araddr", n, {0: "x", 1: "=", 3: "x", 8: "=", 10: "x"}, g, ["DESC0", "BUF0"]),
     row("o_axim_arlen", n, {0: "x", 1: "=", 3: "x", 8: "=", 10: "x"}, g, ["1", "15"]),
     row("i_axim_rvalid", n, {0: "0", 4: "1", 6: "0", 11: "1", 15: "0"}, g)],
    ["Write-back channel",
     row("o_axim_awvalid", n, {0: "0", 17: "1", 19: "0"}, g),
     row("i_axim_awready", n, {0: "0", 18: "1", 19: "0"}, g),
     row("o_axim_awaddr", n, {0: "x", 17: "=", 19: "x"}, g, ["DESC0+4"]),
     row("o_axim_wvalid", n, {0: "0", 19: "1", 20: "0"}, g),
     row("i_axim_bvalid", n, {0: "0", 21: "1", 22: "0"}, g)]],
    "Not to scale. The descriptor (two beats) is read, its buffer is moved in a 16-beat burst (IN endpoint), then word 1 is rewritten with done and the bytes not transferred; with ioc = 0 no interrupt is raised for this descriptor.")

# WF-037 loopback -----------------------------------------------------------------------------------------
n = 20
add("WF-037", "link loopback self-test with two packets (OP-022, success)", n, [
    clk("i_clk_phy", n),
    row("u2_ctrl.lpbk", n, {0: "0", 1: "1"}),
    row("u2_lpbk_sts.clr", n, {0: "0", 2: "1", 3: "0"}),
    row("o_utmi_txvalid", n, {0: "0"}),
    ["Internal transmit stream",
     row("w_tx_valid", n, {0: "0", 5: "1", 8: "0", 12: "1", 15: "0"}),
     row("w_tx_data", n, {0: "x", 5: "=", 6: "=", 7: "=", 8: "x", 12: "=", 13: "=", 14: "=", 15: "x"}, (), ["OUT", "ADDR", "EP,C5", "IN", "ADDR", "EP,C5"])],
    ["Looped receive stream",
     row("w_rx_active", n, {0: "0", 6: "1", 9: "0", 13: "1", 16: "0"}),
     row("w_rx_data", n, {0: "x", 6: "=", 7: "=", 8: "=", 9: "x", 13: "=", 14: "=", 15: "=", 16: "x"}, (), ["OUT", "ADDR", "EP,C5", "IN", "ADDR", "EP,C5"])],
    row("u2_lpbk_sts.pkt_ok", n, {0: "=", 10: "=", 17: "="}, (), ["0", "1", "2"]),
    row("u2_lpbk_sts.pkt_err", n, {0: "="}, (), ["0"])],
    "With lpbk = 1 the PHY pins stay idle (o_utmi_txvalid = 0); each transmitted token returns to the receiver one cycle later, passes the PID and CRC5 check, and increments pkt_ok.")

os.makedirs(OUT, exist_ok=True)
for k, v in WFS.items():
    name = os.path.join(OUT, "usb2_%s.json" % k.lower().replace("-", ""))
    json.dump(v, open(name, "w"), indent=1)
print(len(WFS), "waveforms")
