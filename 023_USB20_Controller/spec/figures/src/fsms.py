"""Writes the FSM specification JSON files of the USB 2.0 controller (section 10.1)."""
import json, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."

FSMS = {}


def fsm(func, initial, states, trans, desc):
    FSMS[func] = {"page_name": "FSM_" + func.upper(), "out_name": "usb2_fsm_%s.drawio" % func, "function": func,
                  "initial": initial, "state_pattern": "^ENUM_ST_[A-Z0-9_]+$",
                  "states": [{"name": s} for s in states],
                  "transitions": [{"src": a, "dst": b, "label": l} for a, b, l in trans],
                  "layout": {"margin": 40}, "_desc": desc}


# 1 device speed and link state --------------------------------------------------------------
fsm("dev_link", "ENUM_ST_DL_DETACH",
    ["ENUM_ST_DL_DETACH", "ENUM_ST_DL_FS_IDLE", "ENUM_ST_DL_CHIRP_K", "ENUM_ST_DL_CHIRP_WAIT", "ENUM_ST_DL_HS_ACT",
     "ENUM_ST_DL_FS_ACT", "ENUM_ST_DL_SUSPEND", "ENUM_ST_DL_RESUME"],
    [("ENUM_ST_DL_DETACH", "ENUM_ST_DL_FS_IDLE", "vbus valid & soft_conn"),
     ("ENUM_ST_DL_FS_IDLE", "ENUM_ST_DL_CHIRP_K", "SE0 > 2.5 us & hs allowed"),
     ("ENUM_ST_DL_FS_IDLE", "ENUM_ST_DL_FS_ACT", "SE0 > 2.5 us & hs disabled"),
     ("ENUM_ST_DL_CHIRP_K", "ENUM_ST_DL_CHIRP_WAIT", "chirp K done (1 to 7 ms)"),
     ("ENUM_ST_DL_CHIRP_WAIT", "ENUM_ST_DL_HS_ACT", "K-J-K-J-K-J seen"),
     ("ENUM_ST_DL_CHIRP_WAIT", "ENUM_ST_DL_FS_ACT", "no hub chirp in 2.5 ms"),
     ("ENUM_ST_DL_HS_ACT", "ENUM_ST_DL_SUSPEND", "idle 3 ms & J after revert"),
     ("ENUM_ST_DL_FS_ACT", "ENUM_ST_DL_SUSPEND", "idle > 3 ms"),
     ("ENUM_ST_DL_HS_ACT", "ENUM_ST_DL_CHIRP_K", "bus reset"),
     ("ENUM_ST_DL_FS_ACT", "ENUM_ST_DL_CHIRP_K", "bus reset & hs allowed"),
     ("ENUM_ST_DL_SUSPEND", "ENUM_ST_DL_RESUME", "K seen or rmt_wake"),
     ("ENUM_ST_DL_SUSPEND", "ENUM_ST_DL_CHIRP_K", "SE0 reset & hs allowed"),
     ("ENUM_ST_DL_RESUME", "ENUM_ST_DL_HS_ACT", "resume end, was HS"),
     ("ENUM_ST_DL_RESUME", "ENUM_ST_DL_FS_ACT", "resume end, was FS"),
     ("ENUM_ST_DL_FS_ACT", "ENUM_ST_DL_DETACH", "vbus lost")],
    "Device link state: attach, chirp, speed, suspend, resume.")

# 2 host port ---------------------------------------------------------------------------------
fsm("host_port", "ENUM_ST_HP_NODEV",
    ["ENUM_ST_HP_NODEV", "ENUM_ST_HP_DEBNC", "ENUM_ST_HP_RESET", "ENUM_ST_HP_CHIRP_DET", "ENUM_ST_HP_CHIRP_TX",
     "ENUM_ST_HP_EN_HS", "ENUM_ST_HP_EN_FS", "ENUM_ST_HP_EN_LS", "ENUM_ST_HP_SUSP", "ENUM_ST_HP_RESUME", "ENUM_ST_HP_OC"],
    [("ENUM_ST_HP_NODEV", "ENUM_ST_HP_DEBNC", "non-SE0 on D+ or D-"),
     ("ENUM_ST_HP_DEBNC", "ENUM_ST_HP_NODEV", "SE0 again"),
     ("ENUM_ST_HP_DEBNC", "ENUM_ST_HP_RESET", "stable & prst"),
     ("ENUM_ST_HP_RESET", "ENUM_ST_HP_CHIRP_DET", "SE0 driven & not LS & hs allowed"),
     ("ENUM_ST_HP_RESET", "ENUM_ST_HP_EN_LS", "LS device & reset >= 50 ms"),
     ("ENUM_ST_HP_CHIRP_DET", "ENUM_ST_HP_CHIRP_TX", "device K >= 2.5 us"),
     ("ENUM_ST_HP_CHIRP_DET", "ENUM_ST_HP_EN_FS", "no chirp & reset >= 50 ms"),
     ("ENUM_ST_HP_CHIRP_TX", "ENUM_ST_HP_EN_HS", "K/J chirps done, reset end"),
     ("ENUM_ST_HP_EN_HS", "ENUM_ST_HP_SUSP", "port_susp"),
     ("ENUM_ST_HP_EN_FS", "ENUM_ST_HP_SUSP", "port_susp"),
     ("ENUM_ST_HP_EN_LS", "ENUM_ST_HP_SUSP", "port_susp"),
     ("ENUM_ST_HP_SUSP", "ENUM_ST_HP_RESUME", "port_res"),
     ("ENUM_ST_HP_RESUME", "ENUM_ST_HP_EN_HS", "resume >= 20 ms, was HS"),
     ("ENUM_ST_HP_RESUME", "ENUM_ST_HP_EN_FS", "resume >= 20 ms, was FS"),
     ("ENUM_ST_HP_EN_HS", "ENUM_ST_HP_NODEV", "disconnect"),
     ("ENUM_ST_HP_EN_FS", "ENUM_ST_HP_NODEV", "SE0 > 2.5 us"),
     ("ENUM_ST_HP_EN_LS", "ENUM_ST_HP_NODEV", "SE0 > 2.5 us"),
     ("ENUM_ST_HP_EN_HS", "ENUM_ST_HP_OC", "over-current"),
     ("ENUM_ST_HP_EN_FS", "ENUM_ST_HP_OC", "over-current"),
     ("ENUM_ST_HP_EN_LS", "ENUM_ST_HP_OC", "over-current"),
     ("ENUM_ST_HP_SUSP", "ENUM_ST_HP_OC", "over-current"),
     ("ENUM_ST_HP_OC", "ENUM_ST_HP_NODEV", "flag cleared & vbus_drv written")],
    "Host root port state: attach, reset, chirp, enabled speed, suspend, resume.")

# 3 packet receive --------------------------------------------------------------------------------
fsm("pkt_rx", "ENUM_ST_PR_IDLE",
    ["ENUM_ST_PR_IDLE", "ENUM_ST_PR_PID", "ENUM_ST_PR_TOKEN", "ENUM_ST_PR_DATA", "ENUM_ST_PR_CRC", "ENUM_ST_PR_DONE", "ENUM_ST_PR_ERR"],
    [("ENUM_ST_PR_IDLE", "ENUM_ST_PR_PID", "rx active"),
     ("ENUM_ST_PR_PID", "ENUM_ST_PR_TOKEN", "PID ok & token or SOF"),
     ("ENUM_ST_PR_PID", "ENUM_ST_PR_DATA", "PID ok & data"),
     ("ENUM_ST_PR_PID", "ENUM_ST_PR_DONE", "PID ok & handshake"),
     ("ENUM_ST_PR_PID", "ENUM_ST_PR_ERR", "PID check fail"),
     ("ENUM_ST_PR_TOKEN", "ENUM_ST_PR_CRC", "2 token bytes"),
     ("ENUM_ST_PR_DATA", "ENUM_ST_PR_CRC", "rx end"),
     ("ENUM_ST_PR_DATA", "ENUM_ST_PR_ERR", "rx error or overflow"),
     ("ENUM_ST_PR_CRC", "ENUM_ST_PR_DONE", "CRC residual ok"),
     ("ENUM_ST_PR_CRC", "ENUM_ST_PR_ERR", "CRC fail"),
     ("ENUM_ST_PR_DONE", "ENUM_ST_PR_IDLE", "result reported"),
     ("ENUM_ST_PR_ERR", "ENUM_ST_PR_IDLE", "rx idle")],
    "Link packet receiver.")

# 4 packet transmit -------------------------------------------------------------------------------
fsm("pkt_tx", "ENUM_ST_PT_IDLE",
    ["ENUM_ST_PT_IDLE", "ENUM_ST_PT_IPD", "ENUM_ST_PT_PID", "ENUM_ST_PT_DATA", "ENUM_ST_PT_CRC", "ENUM_ST_PT_END"],
    [("ENUM_ST_PT_IDLE", "ENUM_ST_PT_IPD", "tx request"),
     ("ENUM_ST_PT_IPD", "ENUM_ST_PT_PID", "turn-around time elapsed"),
     ("ENUM_ST_PT_PID", "ENUM_ST_PT_DATA", "data packet"),
     ("ENUM_ST_PT_PID", "ENUM_ST_PT_CRC", "token packet"),
     ("ENUM_ST_PT_PID", "ENUM_ST_PT_END", "handshake packet"),
     ("ENUM_ST_PT_DATA", "ENUM_ST_PT_CRC", "last data byte accepted"),
     ("ENUM_ST_PT_CRC", "ENUM_ST_PT_END", "CRC bytes accepted"),
     ("ENUM_ST_PT_END", "ENUM_ST_PT_IDLE", "tx idle")],
    "Link packet transmitter.")

# 5 device transaction ----------------------------------------------------------------------------
fsm("dev_xact", "ENUM_ST_DX_IDLE",
    ["ENUM_ST_DX_IDLE", "ENUM_ST_DX_OUT_DATA", "ENUM_ST_DX_OUT_RESP", "ENUM_ST_DX_IN_DATA", "ENUM_ST_DX_IN_ACK", "ENUM_ST_DX_PING_RESP"],
    [("ENUM_ST_DX_IDLE", "ENUM_ST_DX_OUT_DATA", "OUT or SETUP token matched"),
     ("ENUM_ST_DX_IDLE", "ENUM_ST_DX_IN_DATA", "IN token matched"),
     ("ENUM_ST_DX_IDLE", "ENUM_ST_DX_PING_RESP", "PING token matched"),
     ("ENUM_ST_DX_OUT_DATA", "ENUM_ST_DX_OUT_RESP", "data packet received"),
     ("ENUM_ST_DX_OUT_DATA", "ENUM_ST_DX_IDLE", "time-out or bad CRC"),
     ("ENUM_ST_DX_OUT_RESP", "ENUM_ST_DX_IDLE", "ACK, NAK or NYET sent"),
     ("ENUM_ST_DX_IN_DATA", "ENUM_ST_DX_IN_ACK", "data packet sent"),
     ("ENUM_ST_DX_IN_DATA", "ENUM_ST_DX_IDLE", "NAK or STALL sent"),
     ("ENUM_ST_DX_IN_ACK", "ENUM_ST_DX_IDLE", "ACK received or time-out"),
     ("ENUM_ST_DX_PING_RESP", "ENUM_ST_DX_IDLE", "ACK or NAK sent")],
    "Device endpoint transaction.")

# 6 host channel transaction ----------------------------------------------------------------------
fsm("host_xact", "ENUM_ST_HX_IDLE",
    ["ENUM_ST_HX_IDLE", "ENUM_ST_HX_TOKEN", "ENUM_ST_HX_OUT_DATA", "ENUM_ST_HX_WAIT_HS", "ENUM_ST_HX_WAIT_DATA",
     "ENUM_ST_HX_SEND_ACK", "ENUM_ST_HX_SSPLIT", "ENUM_ST_HX_CSPLIT", "ENUM_ST_HX_DONE"],
    [("ENUM_ST_HX_IDLE", "ENUM_ST_HX_TOKEN", "channel granted"),
     ("ENUM_ST_HX_TOKEN", "ENUM_ST_HX_OUT_DATA", "OUT or SETUP token sent"),
     ("ENUM_ST_HX_TOKEN", "ENUM_ST_HX_WAIT_DATA", "IN token sent"),
     ("ENUM_ST_HX_TOKEN", "ENUM_ST_HX_SSPLIT", "start-split token sent"),
     ("ENUM_ST_HX_TOKEN", "ENUM_ST_HX_CSPLIT", "complete-split token sent"),
     ("ENUM_ST_HX_OUT_DATA", "ENUM_ST_HX_WAIT_HS", "data packet sent"),
     ("ENUM_ST_HX_OUT_DATA", "ENUM_ST_HX_DONE", "isochronous, no handshake"),
     ("ENUM_ST_HX_WAIT_HS", "ENUM_ST_HX_DONE", "handshake or time-out"),
     ("ENUM_ST_HX_WAIT_DATA", "ENUM_ST_HX_SEND_ACK", "good data packet"),
     ("ENUM_ST_HX_WAIT_DATA", "ENUM_ST_HX_DONE", "NAK, STALL, error or time-out"),
     ("ENUM_ST_HX_SEND_ACK", "ENUM_ST_HX_DONE", "ACK sent"),
     ("ENUM_ST_HX_SSPLIT", "ENUM_ST_HX_WAIT_HS", "start-split data sent"),
     ("ENUM_ST_HX_CSPLIT", "ENUM_ST_HX_WAIT_DATA", "complete-split IN token sent"),
     ("ENUM_ST_HX_WAIT_DATA", "ENUM_ST_HX_CSPLIT", "NYET, retry complete-split"),
     ("ENUM_ST_HX_DONE", "ENUM_ST_HX_IDLE", "status reported")],
    "Host channel transaction.")

# 7 ULPI interface --------------------------------------------------------------------------------
fsm("ulpi_if", "ENUM_ST_UL_IDLE",
    ["ENUM_ST_UL_IDLE", "ENUM_ST_UL_TXCMD", "ENUM_ST_UL_TXDATA", "ENUM_ST_UL_TXSTOP", "ENUM_ST_UL_RX", "ENUM_ST_UL_REGCMD", "ENUM_ST_UL_REGDATA", "ENUM_ST_UL_REGRD", "ENUM_ST_UL_LP", "ENUM_ST_UL_WAKE"],
    [("ENUM_ST_UL_IDLE", "ENUM_ST_UL_TXCMD", "tx request & dir low"),
     ("ENUM_ST_UL_TXCMD", "ENUM_ST_UL_TXDATA", "nxt high"),
     ("ENUM_ST_UL_TXDATA", "ENUM_ST_UL_TXSTOP", "last byte accepted"),
     ("ENUM_ST_UL_TXSTOP", "ENUM_ST_UL_IDLE", "stp driven one cycle"),
     ("ENUM_ST_UL_IDLE", "ENUM_ST_UL_RX", "dir high"),
     ("ENUM_ST_UL_RX", "ENUM_ST_UL_IDLE", "dir low"),
     ("ENUM_ST_UL_TXCMD", "ENUM_ST_UL_RX", "dir high (abort)"),
     ("ENUM_ST_UL_TXDATA", "ENUM_ST_UL_RX", "dir high (abort)"),
     ("ENUM_ST_UL_IDLE", "ENUM_ST_UL_REGCMD", "phy_acc start & bus idle"),
     ("ENUM_ST_UL_REGCMD", "ENUM_ST_UL_REGDATA", "write, nxt high"),
     ("ENUM_ST_UL_REGCMD", "ENUM_ST_UL_REGRD", "read, dir high"),
     ("ENUM_ST_UL_REGDATA", "ENUM_ST_UL_IDLE", "stp driven"),
     ("ENUM_ST_UL_REGRD", "ENUM_ST_UL_IDLE", "data byte captured"),
     ("ENUM_ST_UL_REGCMD", "ENUM_ST_UL_RX", "dir high (abort)"),
     ("ENUM_ST_UL_REGDATA", "ENUM_ST_UL_LP", "SuspendM = 0 written"),
     ("ENUM_ST_UL_LP", "ENUM_ST_UL_WAKE", "wake request"),
     ("ENUM_ST_UL_WAKE", "ENUM_ST_UL_IDLE", "dir low, stp released")],
    "ULPI link interface.")

# 8 DMA master -------------------------------------------------------------------------------------
fsm("dma_axi", "ENUM_ST_DM_IDLE",
    ["ENUM_ST_DM_IDLE", "ENUM_ST_DM_AR", "ENUM_ST_DM_RDATA", "ENUM_ST_DM_AW", "ENUM_ST_DM_WDATA", "ENUM_ST_DM_BRESP", "ENUM_ST_DM_ERR", "ENUM_ST_DM_DESC_RD", "ENUM_ST_DM_DESC_WB"],
    [("ENUM_ST_DM_IDLE", "ENUM_ST_DM_AR", "IN data, FIFO has space"),
     ("ENUM_ST_DM_AR", "ENUM_ST_DM_RDATA", "arready"),
     ("ENUM_ST_DM_RDATA", "ENUM_ST_DM_IDLE", "rlast & buffer mode"),
     ("ENUM_ST_DM_IDLE", "ENUM_ST_DM_AW", "OUT data, FIFO has data"),
     ("ENUM_ST_DM_AW", "ENUM_ST_DM_WDATA", "awready"),
     ("ENUM_ST_DM_WDATA", "ENUM_ST_DM_BRESP", "wlast accepted"),
     ("ENUM_ST_DM_BRESP", "ENUM_ST_DM_IDLE", "bresp okay & buffer mode"),
     ("ENUM_ST_DM_RDATA", "ENUM_ST_DM_ERR", "rresp error"),
     ("ENUM_ST_DM_BRESP", "ENUM_ST_DM_ERR", "bresp error"),
     ("ENUM_ST_DM_ERR", "ENUM_ST_DM_IDLE", "error status set"),
     ("ENUM_ST_DM_IDLE", "ENUM_ST_DM_DESC_RD", "sg_mode & list armed"),
     ("ENUM_ST_DM_DESC_RD", "ENUM_ST_DM_AR", "IN descriptor read"),
     ("ENUM_ST_DM_DESC_RD", "ENUM_ST_DM_AW", "OUT descriptor read"),
     ("ENUM_ST_DM_DESC_RD", "ENUM_ST_DM_ERR", "rresp error"),
     ("ENUM_ST_DM_RDATA", "ENUM_ST_DM_DESC_WB", "rlast & sg_mode"),
     ("ENUM_ST_DM_BRESP", "ENUM_ST_DM_DESC_WB", "bresp okay & sg_mode"),
     ("ENUM_ST_DM_DESC_WB", "ENUM_ST_DM_IDLE", "status written")],
    "AXI4 master DMA burst engine.")

os.makedirs(OUT, exist_ok=True)
for k, v in FSMS.items():
    d = dict(v)
    d.pop("_desc")
    json.dump(d, open(os.path.join(OUT, "usb2_fsm_%s.json" % k), "w"), indent=1)
json.dump({k: v["_desc"] for k, v in FSMS.items()}, open(os.path.join(OUT, "fsm_index.json"), "w"), indent=1)
print(len(FSMS), "FSMs")
