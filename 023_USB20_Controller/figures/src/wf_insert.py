import json, re, os
ROOT = r"C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\023_USB20_Controller"
H = ROOT + r"\VLSIT_USB20_CONTROLLER_HDS.md"
DATE = "2026-11-20"
PLAN = [
 ("WF-001", "OP-001 device reset and chirp to high-speed", "success", "linestate, txvalid, xcvrsel, termsel, enum flag"),
 ("WF-002", "OP-001 chirp without hub answer, full-speed fallback", "corner", "linestate, txvalid, termsel, enum flag"),
 ("WF-003", "OP-002 device OUT data packet with ACK", "success", "UTMI+ receive and transmit, epo done flag"),
 ("WF-004", "OP-002 device OUT with CRC error", "error", "UTMI+ receive, crc_err flag"),
 ("WF-005", "OP-004 PING with ACK and OUT with NYET", "success", "UTMI+ receive and transmit, space"),
 ("WF-006", "OP-003 device IN data packet with host ACK", "success", "UTMI+ receive and transmit, epi done flag"),
 ("WF-007", "OP-003 device IN with no data, NAK", "error", "UTMI+ receive and transmit, nak flag"),
 ("WF-008", "OP-002 control SETUP transaction", "success", "UTMI+ receive and transmit, setup flag"),
 ("WF-009", "OP-005 host port reset and chirp handshake", "success", "prst, linestate, txvalid, port_en, enum"),
 ("WF-010", "OP-006 host start-of-frame", "success", "UTMI+ transmit, sof flag"),
 ("WF-011", "OP-007 host OUT then IN transaction", "success", "UTMI+ transmit and receive, hc done flag"),
 ("WF-012", "OP-007 host IN with no response", "error", "UTMI+ transmit, turn-around, timeout flag"),
 ("WF-013", "OP-008 start-split and complete-split bulk IN", "success", "UTMI+ transmit and receive, hc done flag"),
 ("WF-014", "OP-009 device suspend and remote wakeup", "success", "linestate, suspend_n, rmt_wake, flags"),
 ("WF-015", "OP-010 LPM L1 entry and exit", "success", "UTMI+ receive and transmit, l1_state, lpm_evt"),
 ("WF-016", "OP-011 Test_Packet", "success", "test_mode, UTMI+ transmit"),
 ("WF-017", "OP-012 AXI master read burst", "success", "AR, R channels"),
 ("WF-018", "OP-012 AXI master write with error response", "error", "AW, W, B channels, axi_err, dma_err"),
 ("WF-019", "OP-013 DMA request and acknowledge", "success", "o_dma_req, i_dma_ack, AXI slave read"),
 ("WF-020", "UTMI+ transmit wait and receive error (IF-001)", "error", "txvalid, txready, rxerror, stuf_err"),
 ("WF-021", "ULPI transmit, receive and TX CMD abort (IF-002)", "corner", "dir, nxt, stp, data, data_oe"),
 ("WF-022", "OP-014 ULPI PHY register write and read", "success", "phy_acc fields, ULPI pins"),
 ("WF-023", "APB4 write, read and w1c clear (IF-003)", "success", "APB4 signals, irq_raw flag"),
 ("WF-024", "OP-015 role change on an A-plug", "success", "iddig, vbusvalid, pulldowns, drvvbus, role"),
 ("WF-025", "Soft reset of the protocol engines (IF-008)", "success", "core_en, swrst, rstbusy, domain reset"),
 ("WF-026", "OP-007 host back-to-back packets with 88 bit times", "corner", "UTMI+ transmit, inter-packet counter"),
 ("WF-027", "OP-002 device OUT with the receive region full", "corner", "UTMI+ receive and transmit, region full, nak"),
 ("WF-028", "OP-003 high-bandwidth isochronous IN", "corner", "UTMI+ receive and transmit, mult"),
 ("WF-029", "OP-012 AXI burst split at 4 KB", "corner", "AR channel address and length"),
 ("WF-030", "ULPI direction change in the middle of a packet (IF-002)", "corner", "dir, nxt, data, data_oe, retry"),
 ("WF-031", "OP-016 double-buffered bulk OUT endpoint", "success", "UTMI+ receive and transmit, buffers A and B, buf_cur"),
 ("WF-032", "OP-017 automatic zero-length packet", "success", "UTMI+ receive and transmit, xsize, zlp pending"),
 ("WF-033", "OP-018 host interval polling with NAK and retry", "success", "microframe tick, poll due, UTMI+ packets, flags"),
 ("WF-034", "OP-019 isochronous IN with no data ready", "error", "UTMI+ packets, iso_inc flags"),
 ("WF-035", "OP-020 port over-current, power off and restore", "error", "i_ovrcur_n, filter, o_vbus_pwr_en, ocur, vbus_drv"),
 ("WF-036", "OP-021 scatter-gather descriptor read, burst and write-back", "success", "AXI read and write-back channels, DMA state"),
 ("WF-037", "OP-022 link loopback self-test", "success", "lpbk, internal streams, packet counters"),
]
t = open(H, encoding="utf-8").read()
a = t.index("**Waveform plan (rule R-024).**")
b = t.index("Timing rules that apply to every waveform of this IP")
rows = ["**Waveform plan (rule R-024).** The user confirmed on %s the proposed list of 25 waveforms plus the corner cases, 30 waveforms in total (option C), and on the same date the 7 waveforms WF-031 to WF-037 of the operations OP-016 to OP-022 added with the six candidate features (option A). Every operation of section 10.2 and the success and error cases of the interfaces appear in the plan. Each figure is drawn from the WaveJSON file beside it." % DATE, "",
        "| Waveform ID | Function / operation | Scenario (success / error / corner) | Signals shown | Figure | Confirmed by user |", "|---|---|---|---|---|---|"]
for wid, fn, sc, sig in PLAN:
    rows.append("| %s | %s | %s | %s | figures/usb2_%s.svg | %s |" % (wid, fn, sc, sig, wid.lower().replace("-", ""), DATE))
rows.append("")
for i, (wid, fn, sc, sig) in enumerate(PLAN, 1):
    stem = "usb2_%s" % wid.lower().replace("-", "")
    j = json.load(open(ROOT + "\\figures\\%s.json" % stem))
    rows.append("![%s](figures/%s.svg)" % (wid + " " + fn, stem))
    rows.append("")
    rows.append("```wavedrom")
    rows.append(json.dumps(j, indent=1))
    rows.append("```")
    rows.append("")
    rows.append("*Figure 10-%d. %s (%s). Source: `figures/%s.json`.*" % (i + 8, fn, sc, stem))
    rows.append("")
t = t[:a] + "\n".join(rows) + "\n" + t[b:]
open(H, "w", encoding="utf-8", newline="\n").write(t)
print("ok", len(t.splitlines()))
