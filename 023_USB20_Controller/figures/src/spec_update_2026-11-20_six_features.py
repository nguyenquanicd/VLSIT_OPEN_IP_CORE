"""Adds the six software and user features to the USB 2.0 controller specification (2026-11-20)."""
import json, os, re, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\023_USB20_Controller"
H = ROOT + r"\VLSIT_USB20_CONTROLLER_HDS.md"
FIG = ROOT + r"\figures"
sys.path.insert(0, D)
import ports

src = open(D + r"\sec9_22.py", encoding="utf-8").read()
ns = {}
exec(src[:src.index("body = open(")], ns)
TESTS, REQ_MODULE, STATE_INFO = ns["TESTS"], ns["REQ_MODULE"], ns["STATE_INFO"]

t = open(H, encoding="utf-8").read()


def one(key):
    n = t.count(key)
    assert n == 1, (n, key)


def ins_after(key, text):
    """Insert text (one or more table rows) after the single line that contains key."""
    global t
    one(key)
    i = t.index(key)
    e = t.index("\n", i)
    t = t[:e + 1] + text.rstrip("\n") + "\n" + t[e + 1:]


def rep(old, new):
    global t
    one(old)
    t = t.replace(old, new)


# ------------------------------------------------------------------ 1.1
rep("descriptor-based scatter-gather DMA; ", "")
rep("shared dynamic FIFO RAM;", "shared dynamic FIFO RAM with optional double buffering; optional descriptor-based scatter-gather DMA; automatic zero-length packet and end-on-short-packet termination; host interval polling; isochronous incomplete flags; port over-current protection; link loopback;")

# ------------------------------------------------------------------ 1.3 and 1.4
ins_after("| FEAT-016 | High-bandwidth isochronous endpoints | Required |", """| FEAT-017 | Double-buffered endpoints and channels | Optional | PARA_USB2_DBUF_EN = 1 | REQ-FUNC-029 |
| FEAT-018 | Automatic zero-length packet and end-on-short-packet termination | Required | Always present | REQ-FUNC-030, REQ-FUNC-031 |
| FEAT-019 | Host interval polling of interrupt and isochronous channels | Required | Host roles | REQ-FUNC-032 |
| FEAT-020 | Isochronous incomplete and missed-transfer flags | Required | Always present | REQ-FUNC-033 |
| FEAT-021 | Port over-current protection and VBUS switch control | Required | Host roles | REQ-FUNC-034, REQ-IF-010 |
| FEAT-022 | Link loopback for bring-up | Required | Always present | REQ-FUNC-035 |
| FEAT-023 | Descriptor-based scatter-gather DMA | Optional | PARA_USB2_SG_EN = 1 and PARA_USB2_DATA_IF = 0 | REQ-FUNC-036 |""")
ins_after("| FEAT-016 | UVC camera isochronous stream", """| FEAT-017 | UVC camera and bulk streams of the companion link, a high-speed bulk packet of 512 bytes every 8.5 us at 60 MB/s | Two packet buffers per endpoint or channel so that the DMA or software refills one while the bus uses the other | 2 buffers of 512 bytes per bulk endpoint; refill time of one packet 8.5 us (512 bytes at 60 MB/s) | NAK storms and lost isochronous packets when the buffer is not refilled within one packet time | REQ-FUNC-029 | user answer 2026-11-20 (all six candidates); double buffering exists in the RP2040 USB controller (reference SoC manual, ASM-024) |
| FEAT-018 | CDC-ACM virtual serial port of the flight controller carrying MAVLink messages, and bulk file transfer | A message that is an exact multiple of the maximum packet size (64 bytes full-speed, 512 bytes high-speed) must end with a zero-length packet; unknown-length receive must end on a short packet | 128-byte message on a 64-byte endpoint; 1024-byte transfer on a 512-byte endpoint | The host waits for more data and the message is never delivered, or software must add the packet by hand | REQ-FUNC-030, REQ-FUNC-031 | REF-001 section 5.8.3 (transfer ends with a short or zero-length packet); TI AM335x mentions short-packet termination modes (ASM-024) |
| FEAT-019 | HID joystick, hub status and UVC control endpoints polled by the host of the drone companion link | Hardware issues the transaction of each periodic channel once per interval so the CPU does not wake every (micro)frame | interval of 1 to 65535 microframes (high-speed) or frames (full-speed); 8 channels; 125 us microframe | The CPU wakes every 125 us per polled endpoint, or a poll is missed and latency grows | REQ-FUNC-032 | user answer 2026-11-20; RP2040 polls up to 15 interrupt endpoints in hardware (reference SoC manual, ASM-024) |
| FEAT-020 | UVC camera isochronous stream at 30 frames per second on the companion link | A flag for each microframe in which an isochronous transfer was incomplete or missed, so the driver drops a damaged frame instead of showing it | one microframe = 125 us; 8000 microframes per second | A damaged video frame is shown to the operator or a stale frame is used for visual navigation | REQ-FUNC-033 | REF-001 section 5.6 (no retry of isochronous data); user answer 2026-11-20 |
| FEAT-021 | 5 V rail of a USB camera or LTE modem powered from the drone battery through a load switch with an over-current flag | The port power switch is cut and software is informed when the load switch reports over-current | switch off within 2 CLK-BUS cycles after a filtered flag of 16 CLK-BUS cycles | A shorted camera cable pulls down the supply of the flight controller, with loss of flight control | REQ-FUNC-034, REQ-IF-010 | REF-001 section 7.2.1.2.1 (host shall implement over-current protection); user answer 2026-11-20 |
| FEAT-022 | Board bring-up of the flight controller before the USB PHY is wired or its clock is stable | Packets sent by the link return to the receiver with PID and CRC checked, with counters for good and bad packets | 12-bit counters, 4095 packets | Link defects are found only with the PHY and a bus analyzer, which delays bring-up | REQ-FUNC-035 | user answer 2026-11-20; TI AM335x has a UTMI loopback test mode (reference SoC manual, ASM-024) |
| FEAT-023 | UVC video payload of 24.576 MB/s moved to DDR on the companion link | A descriptor list lets the DMA move many packets and interrupt once per list instead of once per packet | 64 KB per list means about 375 interrupts per second instead of 24 000 | The CPU load of per-packet interrupts starves the flight controller tasks | REQ-FUNC-036 | user answer 2026-11-20; ESP32-S3 and TI AM335x provide scatter-gather or descriptor DMA (reference SoC manuals, ASM-024) |""")

# ------------------------------------------------------------------ 2.1 references
ins_after("| REF-011 | DWC_otg USB 2.0 Hi-Speed OTG Databook", """| REF-012 | TI AM335x Technical Reference Manual, spruh73q, chapter 16 USB; Espressif ESP32-S3 Technical Reference Manual v1.8, chapter 32; Raspberry Pi RP2040 Datasheet, section 4.1 | feature lists only | Reference SoC manuals read on 2026-11-20 for the features of FEAT-017 to FEAT-023; not copied, not normative, copyright holders restrict redistribution |""")

# ------------------------------------------------------------------ 3 requirements
ins_after("| REQ-FUNC-028 | The number of device endpoints", """| REQ-FUNC-029 | When PARA_USB2_DBUF_EN = 1 and the dbuf field of an endpoint or channel is 1, the FIFO manager shall split its region into two packet buffers, shall fill or drain one while the bus side uses the other, shall swap them at the end of each packet, and shall report the buffer in use in buf_cur. | User answer 2026-11-20 | All roles with DBUF | Simulation |
| REQ-FUNC-030 | With zlp_en = 1 an IN endpoint or OUT channel shall send one zero-length packet after the last full packet when the transfer size is a non-zero multiple of the maximum packet size. | REF-001 section 5.8.3 | All roles | Simulation |
| REQ-FUNC-031 | With short_end = 1 an OUT endpoint or IN channel shall end the transfer at the first packet whose payload is shorter than the maximum packet size or is zero length, set the done flag, and leave the number of bytes not received in xsize. | REF-001 section 5.8.3 | All roles | Simulation |
| REQ-FUNC-032 | With poll_en = 1 a host channel shall issue its transaction once every interval microframes (high-speed) or frames (full-speed and low-speed), shall retry a NAK or NYET in the next interval, shall re-arm itself after a completed transfer when poll_rep = 1, and shall set poll_miss when the previous packet was not consumed at the next interval. | ASM-021 | Host roles | Simulation |
| REQ-FUNC-033 | The controller shall set iso_inc in the endpoint or channel interrupt register and in the global interrupt register when an isochronous IN token finds no data ready, when a received isochronous packet has an error, or when a host isochronous transfer is not done in its scheduled microframe; no retry shall be made. | REF-001 section 5.6 | All roles | Simulation |
| REQ-FUNC-034 | With oc_en = 1 the controller shall drop o_vbus_pwr_en and o_utmi_drvvbus within 2 CLK-BUS cycles after i_ovrcur_n has been low for 16 consecutive CLK-BUS cycles, shall set ocur and oc_act, shall leave the port in the power-off state, and shall restore power only after software clears ocur and writes vbus_drv again. | REF-001 section 7.2.1.2.1, ASM-022 | Host roles | Simulation |
| REQ-FUNC-035 | With lpbk = 1 the link shall feed its transmitted bytes into its own receiver, isolate the PHY pins in the idle state of section 6.2, and count good and bad packets in u2_lpbk_sts. | ASM-023 | All roles | Simulation |
| REQ-FUNC-036 | When PARA_USB2_SG_EN = 1 and sg_mode = 1 the AXI4 master DMA shall treat the address register of an endpoint or channel as the head of a descriptor list, shall process the 8-byte descriptors of section 9 in order until the last descriptor, shall write back the status and the number of bytes not transferred, and shall raise an interrupt only when ioc is set or the list ends or an error occurs. | ASM-020 | AXI-master wrappers with SG | Simulation |
""".rstrip("\n"))
ins_after("| REQ-IF-009 | For each DMA channel", """| REQ-IF-010 | `i_ovrcur_n` shall be an asynchronous active-low input synchronized and filtered in CLK-BUS (CDC-006), and `o_vbus_pwr_en` shall be a registered output of CLK-BUS that is 0 whenever the port power is off. | REF-001 section 7.2.1.2.1 | All wrappers | Simulation, CDC analysis |""")
rep("and LPM and split logic shall be absent when their enable is 0.", "and LPM, split, double-buffer and scatter-gather logic shall be absent when their enable is 0.")

# ------------------------------------------------------------------ 4 configurations
rep("FEAT-009, FEAT-011 (host only, UTMI+, AXI master, 8 channels, split)", "FEAT-009, FEAT-011, FEAT-017 to FEAT-023 (host only, UTMI+, AXI master, 8 channels, split, double buffering, scatter-gather)")
rep("| CFG-DUAL-FULL | FEAT-001 to FEAT-003, FEAT-005, FEAT-007, FEAT-010, FEAT-011 |", "| CFG-DUAL-FULL | FEAT-001 to FEAT-003, FEAT-005, FEAT-007, FEAT-010, FEAT-011, FEAT-017 |")
rep("PARA_USB2_DATA_IF = 1 with PARA_USB2_NUM_DMA_CH = 0;", "PARA_USB2_DATA_IF = 1 with PARA_USB2_NUM_DMA_CH = 0; PARA_USB2_SG_EN = 1 with PARA_USB2_DATA_IF = 1;")

# ------------------------------------------------------------------ 5.1 text after the block table
ins_after("| `m_usb2_rst`, `m_usb2_cdc_*` |", """
Additions of 2026-11-20: `m_usb2_fifo` also implements the two-buffer ping-pong of FEAT-017 and the zero-length-packet and short-packet termination of FEAT-018; `m_usb2_host` holds the interval timers of FEAT-019 (`m_usb2_poll`) and the over-current control path starts in `m_usb2_ocp` (CLK-BUS, FEAT-021); `m_usb2_lnk` holds the loopback multiplexer of FEAT-022; `m_usb2_dma` holds the descriptor engine of FEAT-023 when PARA_USB2_SG_EN = 1; `m_usb2_irq` collects the `iso_inc` and `ocur` events.""")

# ------------------------------------------------------------------ 6.2 ports
a = t.index("| Port | Direction | Width | Meaning (function)")
b = t.index("### 6.3 Protocol behavior")
t = t[:a] + ports.table() + "\n\n" + t[b:]

# ------------------------------------------------------------------ 6.3 6.4
ins_after("| DMA handshake | `o_dma_req` high until", """| Over-current input | `i_ovrcur_n` high in normal operation; low for 16 CLK-BUS cycles means over-current | Glitch shorter than 16 cycles; flag low while `oc_en` = 0 | Ignore the glitch; ignore the flag when disabled; otherwise power off and set `ocur` | REQ-FUNC-034, REQ-IF-010 |""")
ins_after("| Cause: AXI error, DMA error, LPM event |", """| Cause: iso_inc, ocur | Event | Isochronous incomplete or missed transfer; port over-current detected | Software clear | Enable | CLK-PHY to CLK-BUS; CLK-BUS (ocur) | 0 |""")

# ------------------------------------------------------------------ 7.2
ins_after("| CDC-005 | CLK-BUS → CLK-PHY | Soft-reset request", """| CDC-006 | asynchronous → CLK-BUS | `i_ovrcur_n` | Two-flop synchronizer followed by a 16-cycle filter counter in `m_usb2_ocp` | Reset in CLK-BUS | set_false_path to the synchronizer, CDC tool |""")

# ------------------------------------------------------------------ 8 parameters
ins_after("| PARA_USB2_NUM_DMA_CH | External DMA handshake channels", """| PARA_USB2_DBUF_EN | Double-buffered endpoints and channels | 1 | 0, 1 | none | Two-buffer logic in `m_usb2_fifo`; regions must hold two packets when `dbuf` is set |
| PARA_USB2_SG_EN | Descriptor-based scatter-gather DMA | 0 | 0, 1 | Needs PARA_USB2_DATA_IF = 0 | Descriptor engine in `m_usb2_dma` |""")
rep("| CFG-CAM-HOST | ROLE 1, NUM_HC 8, UTMI_W 16, SPLIT_EN 1, DATA_IF 0 |", "| CFG-CAM-HOST | ROLE 1, NUM_HC 8, UTMI_W 16, SPLIT_EN 1, DATA_IF 0, DBUF_EN 1, SG_EN 1 |")
rep("| CFG-DUAL-FULL | ROLE 2, NUM_EP 8, NUM_HC 8, LPM_EN 1, SPLIT_EN 1, AXI_DATA_W 64 |", "| CFG-DUAL-FULL | ROLE 2, NUM_EP 8, NUM_HC 8, LPM_EN 1, SPLIT_EN 1, AXI_DATA_W 64, DBUF_EN 1 |")

# ------------------------------------------------------------------ 9 descriptor
rep("Reserved, undefined and illegal values:", """Scatter-gather descriptor (PARA_USB2_SG_EN = 1, sg_mode = 1): each descriptor is two 32-bit words in system memory, aligned to 8 bytes, little-endian. The list head address is the endpoint or channel DMA address register. Word 0 is the buffer address bits [31:0]; bits [63:32] come from `u2_dma_hi`. Word 1 holds `len` in bits [15:0] (bytes to move, 0 to 65535), `last` in bit 16 (last descriptor of the list), `ioc` in bit 17 (interrupt on completion of this descriptor), reserved bits [23:18], and the status written back by hardware in bits [31:24]: bit 24 `done`, bit 25 `err`, bit 26 `short` (packet shorter than the maximum packet size ended the descriptor), other status bits 0. After the descriptor completes, hardware rewrites `len` with the number of bytes not transferred (ASM-020).

Reserved, undefined and illegal values:""")

# ------------------------------------------------------------------ 10.1 tables of two FSMs
STATE_INFO["host_port"]["ENUM_ST_HP_OC"] = ("Port power cut after over-current", "o_vbus_pwr_en and o_utmi_drvvbus low, port disabled", "ocur interrupt, oc_act = 1")
STATE_INFO["dma_axi"]["ENUM_ST_DM_DESC_RD"] = ("Reads a descriptor (scatter-gather)", "AXI read burst of two beats from the list address", "o_axim_arvalid")
STATE_INFO["dma_axi"]["ENUM_ST_DM_DESC_WB"] = ("Writes back the descriptor status (scatter-gather)", "rewrites word 1 with done, err, short and bytes not transferred; advances to the next descriptor or ends", "o_axim_awvalid, interrupt when ioc, last or error")


def fsm_table(k):
    spec = json.load(open(FIG + r"\usb2_fsm_%s.json" % k))
    out = ["| Mode/state | Entry condition | Behavior | Exit condition | Outputs / side effects |", "|---|---|---|---|---|"]
    for s in spec["states"]:
        n = s["name"]
        ent = ["%s (%s)" % (x["label"], x["src"].split("_", 3)[-1]) for x in spec["transitions"] if x["dst"] == n]
        ex = ["%s (to %s)" % (x["label"], x["dst"].split("_", 3)[-1]) for x in spec["transitions"] if x["src"] == n]
        info = STATE_INFO[k][n]
        entry = ("reset" if n == spec["initial"] else "") + (("; " if n == spec["initial"] and ent else "") + "; ".join(ent))
        out.append("| `%s` | %s | %s: %s | %s | %s |" % (n, entry or "reset", info[0], info[1], "; ".join(ex) or "none", info[2]))
    return "\n".join(out)


for k in ("host_port", "dma_axi"):
    marker = "<!-- /FSM-DIAGRAM:%s -->" % k
    one(marker)
    i = t.index(marker) + len(marker)
    j = t.index("| Mode/state | Entry condition", i)
    e = t.index("\n\n", j)
    t = t[:j] + fsm_table(k) + t[e:]

# ------------------------------------------------------------------ 10.2 operations
ins_after("| OP-015 | Dual-role build", """| OP-016 | `dbuf` = 1 on an endpoint or channel; PARA_USB2_DBUF_EN = 1 | Alternate two packet buffers: bus side uses one while the DMA or software fills or drains the other | `buf_cur` toggles after each packet | No refill stall while a buffer is free |
| OP-017 | `zlp_en` = 1 (IN, OUT channel) or `short_end` = 1 (OUT, IN channel) | Send a zero-length packet after the last full packet, or end the transfer on a short packet | `done` flag, `xsize` holds the remainder | Same transfer, one extra packet |
| OP-018 | Host channel with `poll_en` = 1 and `interval` set | Issue the transaction every interval; retry NAK or NYET in the next interval; re-arm when `poll_rep` = 1 | `done` or `poll_miss` flag | Interval in microframes or frames |
| OP-019 | Isochronous endpoint or channel | Detect IN token with no data, isochronous packet error, or a transfer not done in its microframe | `iso_inc` flags | No retry |
| OP-020 | Host role; `oc_en` = 1; `i_ovrcur_n` low for 16 CLK-BUS cycles | Cut port power and enter the power-off state | `ocur` flag, `oc_act` = 1 | Power off within 2 CLK-BUS cycles after the filter |
| OP-021 | AXI master build with PARA_USB2_SG_EN = 1; `sg_mode` = 1 | Fetch a descriptor, run its data transfer, write back the status, follow the list to the last descriptor | `done` flags, interrupt on `ioc`, last or error | One descriptor after another |
| OP-022 | `lpbk` = 1 before `core_en` | Loop the transmitted bytes into the receiver, count good and bad packets | `u2_lpbk_sts` counters | Same as normal packet timing |""")
rep("**Waveform plan (rule R-024).** The user confirmed", "**Waveform plan (rule R-024).** Operations OP-016 to OP-022 were added on 2026-11-20 after the plan was confirmed; their seven waveforms are proposed in the conversation and wait for the confirmation of TBD-011. The user confirmed")

# ------------------------------------------------------------------ 10.4 10.5
ins_after("- **Throughput:** target 24.576 MB/s", """- **Double buffering and polling:** with `dbuf` = 1 the packet engine and the bus side work on different buffers of the region, so the bus side has one packet time (8.5 us for 512 bytes at 60 MB/s) to refill; the interval timers of the host count microframes in CLK-PHY and start a channel at the beginning of the right microframe, before non-periodic channels (ASM-014).""")
ins_after("| MEM-003 | Endpoint and channel state", """| MEM-004 | Descriptor lists (scatter-gather) | system memory, 8 bytes per descriptor | AXI4 master reads and writes | n/a | none | software initializes | none | outside the IP; the descriptor engine keeps only the current descriptor |""")

# ------------------------------------------------------------------ 11.2 flow and steps
rep("S09 --> S10 --> S11", "S09 --> S10 --> S11\n    S09 -->|bring-up| S19\n    S19 --> S10")
rep('    S18["S18 [O] Soft reset"]', '    S18["S18 [O] Soft reset"]\n    S19["S19 [O] Link loopback self-test"]')
rep("`u2_dma_cfg.burst_len`, `axi_cache`, `axi_prot`, `req_thr`;", "`u2_dma_cfg.burst_len`, `axi_cache`, `axi_prot`, `req_thr`, `sg_mode` (descriptor lists, scatter-gather builds);")
rep("`u2_epi_dma` or `u2_epo_dma` (`addr`) |", "`u2_epi_dma` or `u2_epo_dma` (`addr`); optional `dbuf` and `zlp_en` (IN) or `short_end` (OUT) in the control register |")
rep("`u2_hport.vbus_drv` = 1; wait for", "`u2_hport.oc_en` = 1 and `u2_hport.vbus_drv` = 1 (clear `u2_irq_raw.ocur` after an over-current); wait for")
rep("`u2_hc_dma`; `u2_hc_ctrl.ch_en` = 1;", "`u2_hc_dma`, `u2_hc_cfg` (`dbuf`, `zlp_en`, `short_end`, `poll_en`, `poll_rep`, `interval`); `u2_hc_ctrl.ch_en` = 1;")
ins_after("| S18 | Soft reset |", """| S19 | Link loopback self-test | O (condition: bring-up without a PHY) | APB4 write, then read | write `u2_ctrl.lpbk` = 1 and `u2_lpbk_sts.clr` = 1 before `u2_ctrl.core_en` = 1; run a channel or endpoint transfer; read `u2_lpbk_sts.pkt_ok` and `pkt_err`; clear `u2_ctrl.lpbk` afterward | Checks PID, CRC, FIFO and DMA paths of the link without a PHY before the real bus is used |""")

# ------------------------------------------------------------------ 11.3
ins_after("| `u2_hc_*` banks |", """| `u2_hc_cfg` bank | control out and status in | double buffer, termination, polling and interval of each channel | CLK-PHY via CDC-001 | `buf_cur` is status; others written before `ch_en` |
| `u2_lpbk_sts`, `u2_ctrl.lpbk` | control out, hardware load, status in | loopback mux and packet counters | CLK-PHY via CDC-001 and CDC-002 | `clr` is rwi, cleared by hardware |
| `u2_hport.oc_en`, `u2_hsts.oc_act`, `u2_irq_raw.ocur` | control out and status in, hardware load | over-current enable, input state and event | CLK-BUS (`m_usb2_ocp`) | The flag is w1c and is held until software clears it |
| `u2_dma_cfg.sg_mode`, `u2_build` extension fields | control out and status in | descriptor mode and build constants | CLK-BUS | Constants are tied from PARA_USB2_SG_EN, PARA_USB2_DBUF_EN and PARA_USB2_FIFO_DEPTH |""")

# ------------------------------------------------------------------ 12
ins_after("| ERR-011 | Illegal parameter or configuration", """| ERR-012 | Descriptor error: AXI error while reading or writing a descriptor, or `len` larger than the buffer region | List stopped, `err` written back when possible | `dma_err`, `axi_err` | Write 1; software rebuilds the list | Cleared |
| ERR-013 | Over-current: `i_ovrcur_n` low for 16 CLK-BUS cycles while `oc_en` = 1 | Power off, port in the over-current state | `ocur` | Clear the flag and write `vbus_drv` again | Flag cleared by reset; power off after reset |
| ERR-014 | Poll miss: polled data not consumed at the next interval | Next transaction deferred | `poll_miss`, `hc_xfer` | Write 1; software drains the buffer | Cleared |""")

# ------------------------------------------------------------------ 14.2 hierarchy
ins_after("| `m_usb2_irq` | Interrupt status collection and output", """| `m_usb2_poll` | Interval timers of the host channels (inside the host engine) | `u_poll` in `m_usb2_host` | CLK-PHY | frame and microframe counts, channel requests |
| `m_usb2_ocp` | Over-current synchronizer, filter and power-off control | `u_ocp` | CLK-BUS | `i_ovrcur_n`, `o_vbus_pwr_en`, event |
| `m_usb2_lpbk` | Loopback multiplexer and packet counters (inside the link) | `u_lpbk` in `m_usb2_lnk` | CLK-PHY | byte stream, counters |""")

# ------------------------------------------------------------------ 15.3 assertions, 17 timing
ins_after("| SVA-008 | CSR rwi and w1c priorities", """| SVA-009 | `o_vbus_pwr_en` is 0 within 2 CLK-BUS cycles after 16 consecutive low samples of `i_ovrcur_n` while `oc_en` = 1 | REQ-FUNC-034 | Simulation | Never fails |
| SVA-010 | A descriptor status is written back exactly once and the list stops at `last` | REQ-FUNC-036 | Simulation | Never fails |
| SVA-011 | With `dbuf` = 1 the two buffers of a region never overlap and are used alternately | REQ-FUNC-029 | Simulation, formal | Never fails |""")
ins_after("| Static ports (`i_protect_en`, `i_slverr_en`)", """| Over-current input `i_ovrcur_n` | Input | none (asynchronous) | external switch flag, no clock relation | n/a | synchronizer in CLK-BUS | All | false path |""")
ins_after("| EXC-004 | set_false_path", """| EXC-005 | set_false_path | `i_ovrcur_n` | none | first flop of the over-current synchronizer | No timing check; the filter and CDC-006 cover the crossing | All | Asynchronous input from an external power switch |""")

# ------------------------------------------------------------------ 18
rep("and disable of the failing DMA channel (section 12)", "disable of the failing DMA channel, and power cut on over-current (section 12, REQ-FUNC-034)")

# ------------------------------------------------------------------ 20
rep("DMA uses buffer addresses held in registers, not descriptors; scatter-gather DMA is excluded. | Software splits large transfers | Open: confirm |", "DMA uses buffer addresses held in registers by default; scatter-gather descriptor lists are an option (PARA_USB2_SG_EN). | Software splits large transfers when SG is off | User answer 2026-11-20: scatter-gather added as an option |")
ins_after("| ASM-019 | Assumption", """| ASM-020 | Assumption | The scatter-gather descriptor is two 32-bit words (address, length and control with write-back status) as defined in section 9; the format is proposed by the author and is not the format of any reference SoC. | DMA engine and driver | Open: confirm |
| ASM-021 | Assumption | Host interval polling counts microframes in high-speed and frames in full-speed and low-speed from a 16-bit `interval`, retries NAK or NYET at the next interval, and raises `poll_miss` when the packet is not consumed. | Host scheduler | Open: confirm |
| ASM-022 | Assumption | The over-current input is active low, filtered for 16 CLK-BUS cycles, and the power-off state is held until software clears the flag and writes `vbus_drv` again; the 16-cycle filter must be checked against the load switch datasheet. | Port power control | Open: confirm (TBD-012) |
| ASM-023 | Assumption | Link loopback feeds the transmit bytes of the packet transmitter into the packet receiver; the PHY pins are held idle; counters saturate at 4095. | Bring-up tests | Open: confirm |
| ASM-024 | Assumption | The reference SoC manuals (TI AM335x TRM, ESP32-S3 TRM, RP2040 datasheet) were downloaded on 2026-11-20 to `C:\\HQuan\\007_Document\\USB\\soc_manuals`, only their feature lists were read, nothing was copied, and the files stay out of version control. | Source of the ideas of FEAT-017 to FEAT-023 | Closed |
| TBD-011 | Decision | Confirm the waveform plan for OP-016 to OP-022 (proposed WF-031 to WF-037) before drawing (rule R-024). | Section 10.3 | Open |
| TBD-012 | Decision | Over-current filter time and polarity against the load switch datasheet of the drone board. | Section 6.2 and 11 | Open |""")

# ------------------------------------------------------------------ 21
ins_after("| TT | Transaction translator of a hub |", """| ZLP | Zero-length packet, a data packet with no payload that ends a transfer |
| Scatter-gather | DMA that follows a list of descriptors, each pointing to one buffer |
| Over-current | Load current above the limit of the port power switch, reported by the switch |
| Loopback | Test mode in which transmitted data returns to the receiver inside the IP |
| Descriptor | Two-word memory structure that describes one DMA buffer |""")

# ------------------------------------------------------------------ tests, traceability
TESTS += [
 ("TEST-023", ["REQ-FUNC-029"], "Double-buffered bulk IN and OUT with the DMA refill slower and faster than the bus; buf_cur toggling", "No overlap of buffers, no stall when a buffer is free", "Directed, formal", "CFG-CAM-HOST, CFG-DUAL-FULL"),
 ("TEST-024", ["REQ-FUNC-030", "REQ-FUNC-031"], "Bulk IN of 0, 1, MPS, 2 x MPS bytes with zlp_en; bulk OUT with short_end and a zero-length packet", "ZLP only for non-zero multiples; transfer ends on a short packet with the remainder in xsize", "Directed", "all configurations"),
 ("TEST-025", ["REQ-FUNC-032"], "Interrupt channels with interval 1, 3, 100 and a NAKing device; poll_rep with and without draining", "Transactions at the right microframes, retry on NAK, poll_miss set", "Directed with timing checker", "CFG-CAM-HOST"),
 ("TEST-026", ["REQ-FUNC-033"], "Isochronous IN token with no data; isochronous OUT with a CRC error; host isochronous transfer that misses its microframe", "iso_inc flags in the endpoint, channel and global registers; no retry", "Directed", "CFG-DUAL-FULL"),
 ("TEST-027", ["REQ-FUNC-034", "REQ-IF-010"], "Glitch of 15 and 16 cycles on i_ovrcur_n, oc_en 0 and 1, restore of power", "Power off within 2 cycles after 16 low cycles, restore only after the flag is cleared", "Directed, CDC analysis", "CFG-CAM-HOST"),
 ("TEST-028", ["REQ-FUNC-036"], "Descriptor lists of 1, 2 and 8 descriptors with ioc, last, a short packet, a bad length and an AXI error on a descriptor", "Status written back once; interrupt only on ioc, list end or error", "Directed, protocol checker", "CFG-CAM-HOST"),
 ("TEST-029", ["REQ-FUNC-035"], "lpbk = 1 with good and corrupted packets; counter clear and saturation", "Counters match; PHY pins idle", "Directed", "all configurations"),
]
REQ_MODULE.update({"REQ-FUNC-029": "m_usb2_fifo", "REQ-FUNC-030": "m_usb2_fifo, m_usb2_dev, m_usb2_host", "REQ-FUNC-031": "m_usb2_fifo, m_usb2_dev, m_usb2_host",
                   "REQ-FUNC-032": "m_usb2_host (m_usb2_poll)", "REQ-FUNC-033": "m_usb2_dev, m_usb2_host, m_usb2_irq", "REQ-FUNC-034": "m_usb2_ocp, m_usb2_spd",
                   "REQ-FUNC-035": "m_usb2_lnk (m_usb2_lpbk)", "REQ-FUNC-036": "m_usb2_dma", "REQ-IF-010": "m_usb2_ocp"})
ns["TESTS"] = TESTS

a = t.index("| Test ID | Requirements | Scenario / stimulus")
b = t.index("\n\n", a)
t = t[:a] + ns["test_section"]() + t[b:]
a = t.index("| Requirement ID | RTL module/location | Test/property")
b = t.index("\n", t.index("| REQ-DFT-001 |", a))
t = t[:a] + ns["trace_section"](t) + t[b:]
open(H, "w", encoding="utf-8", newline="\n").write(t)
print("ok", len(t.splitlines()))
