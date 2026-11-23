"""Applies the review fixes (2026-11-20) to the USB 2.0 controller specification."""
import json, os, re, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\023_USB20_Controller"
H = ROOT + r"\spec\../spec/VLSIT_USB20_CONTROLLER_HDS.md"
FIG = ROOT + r"\figures"
sys.path.insert(0, D)
import ports

t = open(H, encoding="utf-8").read()
STATE_INFO_NEW = {
    "ulpi_if": {"ENUM_ST_UL_LP": ("ULPI low power mode, PHY clock may be stopped", "dir high, nxt low, data[3:0] carry the low power signals (LineState, int)", "o_ulpi_data_oe low, wake detector of `m_usb2_ulpilp` active"),
                "ENUM_ST_UL_WAKE": ("Wakes the PHY", "stp driven asynchronously until the PHY drops dir after at least 5 clock cycles", "o_ulpi_stp high, released in the cycle after dir falls")},
    "host_xact": {"ENUM_ST_HX_SSPLIT": ("Start-split phase", "SPLIT token with SC = 0, then the full-speed or low-speed token and data; at most three attempts", "split state to the channel"),
                  "ENUM_ST_HX_CSPLIT": ("Complete-split phase", "SPLIT token with SC = 1 in the scheduled microframes; retry on NYET or error", "split state to the channel")},
}


def region(start_h, end_h):
    a = t.index(start_h)
    b = t.index(end_h, a + 5)
    return a, b


def setline(prefix, new, start_h="## 3. Requirements", end_h="## 4. Features"):
    global t
    a, b = region(start_h, end_h)
    seg = t[a:b]
    i = seg.index("\n" + prefix) + 1
    e = seg.index("\n", i)
    seg = seg[:i] + new + seg[e:]
    t = t[:a] + seg + t[b:]


def ins_after(prefix, text, start_h, end_h):
    global t
    a, b = region(start_h, end_h)
    seg = t[a:b]
    i = seg.index("\n" + prefix) + 1
    e = seg.index("\n", i)
    seg = seg[:e + 1] + text.rstrip("\n") + "\n" + seg[e + 1:]
    t = t[:a] + seg + t[b:]


def sub(old, new, n=1):
    global t
    assert t.count(old) == n, (t.count(old), old[:80])
    t = t.replace(old, new)


S3 = ("## 3. Requirements", "## 4. Features")

# ----------------------------------------------------------------- section 3: changed requirements
setline("| REQ-FUNC-015 |", "| REQ-FUNC-015 | The host shall schedule the periodic (isochronous and interrupt) channels of a (micro)frame before the non-periodic channels, shall not start a transaction that cannot finish before the next SOF, shall keep periodic transactions within 80 % of a high-speed microframe and 90 % of a full-speed or low-speed frame, and shall refuse to arm a periodic channel that would exceed the limit (ch_en is cleared and frm_ovr is set). | REF-001 section 5.7.4 | Host roles | Simulation |")
setline("| REQ-FUNC-022 |", "| REQ-FUNC-022 | The controller shall support the test selectors 0x01 Test_J, 0x02 Test_K, 0x03 Test_SE0_NAK, 0x04 Test_Packet and, for the host port only, 0x05 Test_Force_Enable; a device shall enter the selected mode no later than 3 ms after the status stage of SetFeature(TEST_MODE), shall answer an invalid selector with a request error, and shall leave the mode only by power cycle or reset of i_rst_n_phy; Test_Packet shall send the packet of REF-001 section 7.1.20 repeatedly and Test_SE0_NAK shall answer valid IN tokens with NAK. | REF-001 sections 7.1.20, 9.4.9; USB ECN TEST_MODE selector values | All roles | Simulation |")
setline("| REQ-FUNC-025 |", "| REQ-FUNC-025 | The controller shall treat the loss of an expected response as a transaction error: in high-speed a device or host shall not time out before 736 bit times and shall time out within 816 bit times after the end of the packet (92 to 102 cycles of a 60 MHz CLK-PHY, 46 to 51 cycles at 30 MHz); in full-speed and low-speed a device shall time out between 16 and 18 bit times and a host shall wait at least 18 bit times; a host that signals an error by timeout shall wait the full time before the next token. | REF-001 sections 7.1.19.1, 7.1.19.2, 8.7.2 | All roles | Simulation with timing checker |")
setline("| REQ-FUNC-034 |", "| REQ-FUNC-034 | With oc_en = 1 the controller shall drop o_vbus_pwr_en within 2 CLK-BUS cycles after i_ovrcur_n has been low for 16 consecutive CLK-BUS cycles, shall set ocur and oc_act, shall hold the port in the power-off state, and shall restore power only after software clears ocur and writes vbus_drv again. | REF-001 section 7.2.1.2.1, ASM-022 | Host roles | Simulation |")
setline("| REQ-IF-006 |", "| REQ-IF-006 | The AXI master DMA shall issue only INCR bursts of at most 16 beats that do not cross a 4 KB boundary, shall use only full-width aligned beats, and shall report BRESP and RRESP errors in the interrupt status; the profile is limited to the behavior of the AXI3 text REF-010 and uses no AXI4-only feature (ASM-007). | REF-010 | AXI-master wrappers | Protocol checker |")
setline("| REQ-IF-007 |", "| REQ-IF-007 | The AXI slave port shall give access to the FIFO region windows with FIXED and INCR bursts of at most 16 beats and shall respond SLVERR to an access outside the windows; the profile is limited to the behavior of the AXI3 text REF-010 (ASM-007). | REF-010 | AXI-slave wrappers | Protocol checker |")
setline("| REQ-PARAM-001 |", "| REQ-PARAM-001 | Parameter values outside section 8 are configuration errors; the elaboration check module `m_usb2_cfgchk` shall report them (REQ-PARAM-003, REQ-PARAM-004) and the RTL behavior for them is undefined. | ASM-011 | All wrappers | Lint, elaboration |")

# ----------------------------------------------------------------- section 3: new requirements
ins_after("| REQ-FUNC-036 |", """| REQ-FUNC-037 | After a selective suspend or an L1 state the host shall resume the SOF transmission phase-locked to the SOFs sent before it; the microframe timer shall keep counting through the suspend or L1 interval. | USB 2.0 Phase-locked SOFs ECN | Host roles | Simulation |
| REQ-FUNC-038 | For interrupt and isochronous IN split transactions the host shall send one start-split in the microframe before the transaction is budgeted, and complete-splits in each following microframe as REF-001 section 11.18.4 states (two complete-splits for interrupt transactions plus a third unless the budget started in microframe Y6); it shall never send more than one complete-split in a microframe for the same transaction and never a complete-split for a full-speed isochronous OUT. | REF-001 section 11.18.4 | Host roles with split | Simulation |
| REQ-FUNC-039 | For bulk and control split transactions the host shall retry the start-split on NAK or error until the error count reaches three, shall retry the complete-split on NYET or error, and shall retry a failed complete-split before other bulk or control split transactions. | REF-001 sections 11.17.1, 11.17.2, 11.17.3 | Host roles with split | Simulation |
| REQ-FUNC-040 | When PARA_USB2_RAM_PAR_EN = 1 each FIFO RAM word shall carry one parity bit written with the data and checked on every read; a parity error shall set ram_par, abort the packet being read or received, and answer the host with no handshake (IN) or NAK (OUT). | Review F-017, ASM-025 | All roles with parity | Simulation, fault injection |
| REQ-FUNC-041 | In UTMI+ builds o_utmi_drvvbus shall follow the power-off state of REQ-FUNC-034 within 4 CLK-PHY cycles after the command reaches CLK-PHY; in ULPI builds the link shall clear DrvVbus in the OTG Control register of the PHY by a register write as soon as the PHY clock runs, and until then o_vbus_pwr_en alone cuts the power. | REF-006 section 2.2.1.6, REF-007 section 4.2 | Host roles | Simulation |""", *S3)
ins_after("| REQ-IF-010 |", """| REQ-IF-011 | In ULPI builds the link shall enter low power mode by writing SuspendM = 0 in the Function Control register, may stop CLK-PHY at least five cycles after the PHY accepted the write, and shall leave the mode by asserting stp asynchronously until the PHY has dropped dir after at least five clock cycles, then releasing stp in the cycle after dir falls; while the clock is stopped the wake detector of `m_usb2_ulpilp` in CLK-BUS shall watch LineState and the interrupt indication on data[3:0]. | REF-007 sections 3.9.1 to 3.9.3 | ULPI wrappers | Protocol checker, simulation |
| REQ-IF-012 | The UTMI+ wrapper shall drive XcvrSelect, TermSelect, OpMode, DpPulldown and DmPulldown with the values of the table of section 6.3 for each bus state, and shall change them only while the bus is idle. | REF-006 sections 2.2.1.11, 2.3.1, 2.4.1, 3.1 | UTMI+ wrappers | Protocol checker |
| REQ-IF-013 | In ULPI builds the role controller shall take the ID indication from bit 6 of the RX CMD byte, valid 50 ms after IdPullup is set in the OTG Control register of the PHY, and the initialization flow shall write IdPullup, DpPulldown and DmPulldown there for the selected role. | REF-007 sections 3.8.1, 4.2 | ULPI wrappers, dual-role | Simulation |
| REQ-IF-014 | With win_en = 1 the DMA shall transfer only buffers and descriptors whose addresses lie between u2_dma_wbase and u2_dma_wlim; a violation shall stop the transfer before any AXI access to the address, set dma_err and mark the descriptor err. | Review F-018 | AXI-master wrappers | Simulation |""", *S3)
ins_after("| REQ-CLK-002 |", """| REQ-CLK-003 | Every CSR field that CLK-PHY consumes or produces shall cross through the register command FIFO (CLK-BUS to CLK-PHY) or the register update FIFO (CLK-PHY to CLK-BUS) of section 7.2; a multi-bit value shall never cross as unqualified levels, and each register shall be delivered as one whole 32-bit word. | REF-003 | All wrappers | CDC analysis, simulation |""", *S3)
ins_after("| REQ-REG-001 |", """| REQ-REG-002 | u2_sts.xq_free shall report the free entries (0 to 8) of the register command FIFO; a CSR write to a crossing field while xq_free = 0 shall be dropped and shall set xq_ovf. | Review F-001 | All wrappers | Simulation |
| REQ-REG-003 | A hardware update shall be applied to a CSR field only when its generation tag equals the CSR-side tag of that register; a software write to the register increments the tag, so a stale update is dropped and the software value is sent to CLK-PHY. | Review F-014 | All wrappers | Simulation, assertion |""", *S3)
ins_after("| REQ-PARAM-002 |", """| REQ-PARAM-003 | The core shall derive every CSR bank count (`u2_epi_*`, `u2_epo_*`, `u2_hc_*`, `u2_dma_map`) from PARA_USB2_NUM_EP, PARA_USB2_NUM_HC and PARA_USB2_NUM_DMA_CH, so that the integrator ties no bank count by hand. | Review F-020 | All wrappers | Elaboration, lint |
| REQ-PARAM-004 | PARA_USB2_FIFO_DEPTH shall be at least the sum of the minimum regions of the configuration: for each endpoint or channel the maximum packet size times (1 + dbuf) times mult, rounded up to words, and 256 words for the receive region. | Review F-021 | All wrappers | Elaboration, lint |""", *S3)
ins_after("| REQ-VER-001 |", """| REQ-VER-002 | PARA_USB2_TSCALE shall divide every millisecond-scale timer of the speed and power controller by its value in simulation, shall be 1 in every delivered netlist, and each timing requirement shall be tested at least once with TSCALE = 1. | Review F-028 | All wrappers | Simulation |
| REQ-VER-003 | The verification plan shall include interoperability tests of the device role with a real host stack (CDC-ACM, mass storage) and of the host role with a real device stack (UVC, CDC-ACM), and a compliance pre-check list. | Review F-026 | All wrappers | Review, FPGA prototype |""", *S3)

# ----------------------------------------------------------------- 2.1 references and ECN applicability
setline("| REF-010 |", "| REF-010 | AMBA AXI Protocol Specification v1.0 (AXI3 era, `vlsit_axi_amba_axi_ihi0022b_v1_0.md`) | burst rules, channel handshake | The only AXI text available; the profile is limited to its behavior and uses no AXI4-only feature (ASM-007) |", "## 2. Normative references", "## 3. Requirements")
ins_after("| REF-012 |", """
### ECN applicability (USB 2.0 package, 2024-09-27)

| ECN | Applies to this IP | Effect |
|---|---|---|
| TEST_MODE selector values | Yes | Selectors 0x06 and 0x07 reserved for OTG and EH compliance; the IP uses 0x01 to 0x05 (REQ-FUNC-022) |
| Phase-locked SOFs | Yes (host) | REQ-FUNC-037 |
| Link Power Management | Yes (optional) | REF-008, REQ-FUNC-021 |
| Double Isochronous IN bandwidth | No | Only for directly connected inbox eUSB2 devices; the IP supports up to three transactions per microframe |
| Suspend current limit | No | Concerns the supply current of devices, which is a board and PHY property |
| Connect timing update | Partly | The soft-connect timing after attach is a software rule of the driver (S12 of section 11.2) |
| Other ECNs of the package (connector, cable, HSIC, eUSB2 repeater, inter-chip) | No | Mechanical, electrical or other interfaces outside the scope |""", "## 2. Normative references", "## 3. Requirements")
setline("| AMBA AXI |", "| AMBA AXI | Behavior of the AXI3 text REF-010 (IHI 0022 v1.0) as a subset that is also legal in AXI4 | Manager (DATA_IF = 0) or Subordinate (DATA_IF = 1) | INCR bursts of at most 16 beats; no lock, QoS, region or user; no AXI4-only feature | ASM-007 |", "## 2. Normative references", "## 3. Requirements")

# ----------------------------------------------------------------- 6.2 ports, 6.3 tables, 6.4
a = t.index("| Port | Direction | Width | Meaning (function)")
b = t.index("### 6.3 Protocol behavior")
t = t[:a] + ports.table() + "\n\n" + t[b:]
ins_after("| Over-current input |", """| ULPI low power mode | Link writes SuspendM = 0; the PHY asserts dir with nxt low and drives data[3:0]; the link wakes the PHY with stp | Data driven by the link while the PHY is in low power mode; stp released before dir falls | Link releases the bus, wake detector in CLK-BUS asserts stp asynchronously until dir falls | REQ-IF-011 |""", "### 6.3 Protocol behavior", "### 6.4 Interrupts and events")
sub("### 6.4 Interrupts and events", """**UTMI+ control values (REQ-IF-012).** Source: REF-006 sections 2.2.1.11, 2.3.1, 2.4.1 and 3.1 (unofficial copy, ASM-001). XcvrSelect: 00b high-speed, 01b full-speed, 10b low-speed, 11b low-speed packet on a full-speed bus (level 3 preamble). OpMode: 00b normal with SYNC and EOP appended, 01b non-driving, 10b disable bit stuffing and NRZI (chirp and resume), 11b normal without automatic SYNC and EOP (valid only with XcvrSelect = 00b). The encoding of chirp K and chirp J on DataOut during OpMode = 10b is fixed by REF-006 section 3.1 and shall be transcribed from the official copy.

| Bus state | XcvrSelect | TermSelect | OpMode | DpPulldown, DmPulldown | Note |
|---|---|---|---|---|---|
| Device attached, full-speed idle | 01b | 1 (FS) | 00b | 0, 0 | pull-up on D+ |
| Device chirp | 01b | 1 | 10b | 0, 0 | TXReady must be answered for chirp data (REF-006 2.1.1.4) |
| Device high-speed active | 00b | 0 (HS) | 00b | 0, 0 | after K-J-K-J-K-J |
| Device suspend | 01b | 1 | 00b | 0, 0 | SuspendM low; TermSelect stays FS so the pull-up stays powered |
| Device resume signaling | 01b | 1 | 10b | 0, 0 | OpMode returns to 00b only after the TX end delay |
| Host reset (SE0) and chirp | 01b | 1 | 10b during chirp | 1, 1 | host sends alternating chirp K and J |
| Host high-speed | 00b | 0 | 00b | 1, 1 | |
| Host full-speed | 01b | 1 | 00b | 1, 1 | |
| Host low-speed direct | 10b | 1 | 00b | 1, 1 | UTMI+ level 2 |
| Host low-speed behind a hub | 11b | 1 | 00b | 1, 1 | UTMI+ level 3, preamble at full-speed |
| Test mode Test_J, Test_K, Test_SE0_NAK | 00b | 0 | 00b | per role | the PHY holds the state |
| Link loopback (lpbk = 1) | 01b | 1 | 01b | per role | PHY pins idle (non-driving) |

### 6.4 Interrupts and events""")
setline("| Cause: iso_inc, ocur |", "| Cause: iso_inc, ocur, ram_par, xq_ovf | Event | Isochronous incomplete or missed transfer; port over-current; FIFO RAM parity error; register command FIFO overflow | Software clear | Enable | CLK-PHY to CLK-BUS; CLK-BUS (ocur, xq_ovf) | 0 |", "### 6.4 Interrupts and events", "## 7. Clock, reset")

# ----------------------------------------------------------------- 7.2 CDC and 7.3 reset
R7 = ("### 7.2 CDC and RDC", "### 7.3 Reset domains")
setline("| CDC-001 |", "| CDC-001 | CLK-BUS → CLK-PHY | Register command stream: every CSR write to a field that CLK-PHY uses (role, enables, test mode, address, endpoint and channel fields, FIFO region pointers, flush and start requests) | Register command FIFO in `m_usb2_xreg`: asynchronous Gray-pointer FIFO of 8 entries of 48 bits {register id 8, entry index 4, value 32, generation tag 4}, filled by the CSR write strobes in CLK-BUS and drained in CLK-PHY into shadow registers that hold the value for the engines; order of writes preserved | Both FIFO sides reset in their domains; entries in flight at a soft reset are discarded | Gray-pointer constraint (EXC-002), CDC tool; software reads u2_sts.xq_free (REQ-REG-002) |", *R7)
setline("| CDC-002 |", "| CDC-002 | CLK-PHY → CLK-BUS | Register update stream: values that hardware changes (xsize, pkt_cnt, DMA address, buf_cur, link and port status, speed, line state) | Register update FIFO in `m_usb2_xreg`: same format, written by the engines in CLK-PHY when a value changes and drained into the `i_hw_wdata_*` and `i_hw_we_*` ports of the CSR in CLK-BUS; an entry is applied only if its generation tag equals the CSR-side tag of the register (REQ-REG-003), otherwise it is dropped | Both sides reset in their domains | Gray-pointer constraint (EXC-002), CDC tool |", *R7)
ins_after("| CDC-006 |", """| CDC-007 | asynchronous → CLK-BUS and CLK-BUS → pin | ULPI `i_ulpi_dir`, `i_ulpi_data[3:0]` in low power mode; `o_ulpi_stp` wake request | Two-flop synchronizers on the inputs inside `m_usb2_ulpilp`; the wake request drives `o_ulpi_stp` through a glitch-free hand-off from the CLK-PHY driver | Always-on logic in CLK-BUS, reset by i_rst_n_bus | set_false_path on the inputs, CDC tool; the hand-off is held by assertion SVA-014 |""", *R7)
sub("A bus reset on the USB wire is handled by the speed controller and does not reset the domains.", "A bus reset on the USB wire is handled by the speed controller and does not reset the domains. Stopped-clock rule (F-019): when CLK-PHY is stopped by the PHY, asserting i_rst_n_phy resets the state asynchronously, its release waits for the first rising edges of the restarted clock, and the soft reset of the CSR completes only after CLK-PHY runs; software shall check u2_sts.phyclk_ok = 1 before writing swrst and a soft reset that does not finish within 1 ms of CLK-BUS time shall be treated as an error by software.")

# ----------------------------------------------------------------- 8 parameters
ins_after("| PARA_USB2_SG_EN |", """| PARA_USB2_RAM_PAR_EN | One parity bit per FIFO RAM word | 1 | 0, 1 | none | RAM word of 33 or 65 bits; ram_par flag |
| PARA_USB2_TSCALE | Verification-only divider of the millisecond timers | 1 | 1, 16, 256, 4096 | must be 1 in every delivered netlist (REQ-VER-002) | Timer reload values |
| LPARA_USB2_RAM_W | RAM word width in data bits, derived: 64 when PARA_USB2_UTMI_W = 16, else 32 | 32 | 32, 64 | follows PARA_USB2_UTMI_W | RAM width and bandwidth (section 10.4) |""", "## 8. Parameters", "## 9. Data representation")
sub("PARA_USB2_SG_EN = 1 with PARA_USB2_DATA_IF = 1;", "PARA_USB2_SG_EN = 1 with PARA_USB2_DATA_IF = 1; PARA_USB2_TSCALE other than 1 in a delivered netlist;")

# ----------------------------------------------------------------- 10.1 FSM tables for ulpi_if and host_xact
def fsm_table(k):
    spec = json.load(open(FIG + r"\usb2_fsm_%s.json" % k))
    old = {}
    # existing state info from the current table
    out = ["| Mode/state | Entry condition | Behavior | Exit condition | Outputs / side effects |", "|---|---|---|---|---|"]
    marker = "<!-- /FSM-DIAGRAM:%s -->" % k
    i = t.index(marker) + len(marker)
    j = t.index("| Mode/state | Entry condition", i)
    e = t.index("\n\n", j)
    for line in t[j:e].split("\n")[2:]:
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        name = cells[0].strip("`")
        beh, outp = cells[2], cells[4]
        old[name] = (beh, outp)
    for s in spec["states"]:
        n = s["name"]
        ent = ["%s (%s)" % (x["label"], x["src"].split("_", 3)[-1]) for x in spec["transitions"] if x["dst"] == n]
        ex = ["%s (to %s)" % (x["label"], x["dst"].split("_", 3)[-1]) for x in spec["transitions"] if x["src"] == n]
        entry = ("reset" if n == spec["initial"] else "") + (("; " if n == spec["initial"] and ent else "") + "; ".join(ent))
        if n in STATE_INFO_NEW.get(k, {}):
            info = STATE_INFO_NEW[k][n]
            beh, outp = "%s: %s" % (info[0], info[1]), info[2]
        else:
            beh, outp = old[n]
        out.append("| `%s` | %s | %s | %s | %s |" % (n, entry or "reset", beh, "; ".join(ex) or "none", outp))
    return "\n".join(out), j, e


for k in ("ulpi_if", "host_xact"):
    tab, j, e = fsm_table(k)
    t = t[:j] + tab + t[e:]

# ----------------------------------------------------------------- 10.4 bandwidth, 10.5 RAM
a = t.index("- **Bandwidth check:**")
e = t.index("\n", a)
t = t[:a] + """- **Bandwidth check (review F-003):** the RAM has one port in CLK-PHY, so its capacity is the word width times CLK-PHY. The packet stream of high-speed is 60 MB/s and the bus side may use up to 60 MB/s. The RAM word is therefore 32 bits at 60 MHz and 64 bits at 30 MHz (LPARA_USB2_RAM_W).

| Configuration | CLK-PHY | RAM word | RAM capacity | Packet engine | Bus side | Use |
|---|---|---|---|---|---|---|
| UTMI+ 8-bit | 60 MHz | 32 bits | 240 MB/s | 60 MB/s | 60 MB/s | 50 % |
| UTMI+ 16-bit, 64-bit RAM word (chosen) | 30 MHz | 64 bits | 240 MB/s | 60 MB/s | 60 MB/s | 50 % |
| UTMI+ 16-bit, 32-bit RAM word (rejected) | 30 MHz | 32 bits | 120 MB/s | 60 MB/s | 60 MB/s | 100 %, no margin |
| ULPI 8-bit | 60 MHz | 32 bits | 240 MB/s | 60 MB/s | 60 MB/s | 50 % |""" + t[e:]
setline("| MEM-001 |", "| MEM-001 | FIFO RAM (shared regions) | PARA_USB2_FIFO_DEPTH x LPARA_USB2_RAM_W (+1 parity bit when PARA_USB2_RAM_PAR_EN = 1) | one read-write port in CLK-PHY | 1 cycle | byte lanes not needed; whole words | content not reset; pointers reset | one parity bit per word (REQ-FUNC-040) | macro or memory-compiler instance wrapped as `u_dont_touch_sram` (DEP-004) |", "### 10.5 Memories and storage", "## 11. Register and programming model")

# ----------------------------------------------------------------- 11.1, 11.2, 11.3
setline("| Repeated register groups |", "| Repeated register groups | PARAMETERIZED banks; the core derives each generated count parameter `PARA_U2_xx_COUNT` (xx is the upper-case register name) from PARA_USB2_NUM_EP plus 1 (device endpoint banks `u2_epi_*`, `u2_epo_*`), PARA_USB2_NUM_HC (host banks `u2_hc_*`) or PARA_USB2_NUM_DMA_CH (`u2_dma_map`), so the integrator ties no count by hand (REQ-PARAM-003) |", "### 11.1 CSR specification source", "### 11.2 Software sequences")
setline("| S05 |", "| S05 | Configure the PHY registers | O (ULPI builds) | APB4 write and poll | write `u2_phy_acc.reg_addr`, `wdata`, `rd_wr` = 1, `start` = 1; poll `u2_phy_acc.busy` = 0 or wait for `u2_irq_raw.phy_done`; registers written at start-up: Function Control (XcvrSelect, TermSelect, OpMode), OTG Control (IdPullup, DpPulldown, DmPulldown for the role, DrvVbus in host role), USB Interrupt Enable Rising and Falling (all 1, needed in low power mode) | Writes the PHY registers through the ULPI register commands so that the PHY is in the mode of the role before the first packet |", "### 11.2 Software sequences", "### 11.3 CSR connection to the design")
a = t.index("### 11.3 CSR connection to the design")
t = t[:a] + "**Register writes that cross to CLK-PHY.** Before a group of writes to endpoint, channel, FIFO, role or enable fields software reads `u2_sts.xq_free` and issues at most that many writes (REQ-REG-002); a write while `xq_free` is 0 is dropped and sets `xq_ovf`. A written value reaches the engines within 8 cycles of the slower clock after it enters the register command FIFO, so software starts a transfer with `ep_en` or `ch_en` as the last write of its group and waits for the flags of the endpoint or channel, never for an immediate effect.\n\n" + t[a:]
a = t.index("A signal from a clock domain other than the register clock is synchronized")
e = t.index("\n", a)
t = t[:a] + "A signal from a clock domain other than the register clock is carried by the register command FIFO and the register update FIFO of section 7.2, not synchronized bit by bit by the CSR. Rule for a software write that meets a hardware update of the same `rwi` field (REQ-REG-003): every software write to the register increments the generation tag of that register in CLK-BUS and sends the written word to CLK-PHY; an update entry from CLK-PHY carries the tag it was produced under and is applied only if the tag still equals the CSR-side tag, otherwise it is dropped because a newer software value is in flight. A `count-down` field such as xsize therefore never loses the software value, and a stale count never overwrites it. A hardware load to a `w1c` field wins over a software clear, so a new event is kept." + t[e:]

# 11.5 software integration and driver plan
a = t.index("## 12. Error handling and recovery")
t = t[:a] + """### 11.5 Software integration and driver plan

**Compatibility statement (review F-013).** The register model of REF-005 is new: it is not register-compatible with DWC_otg, Mentor MUSB or ChipIdea, so no existing Linux gadget or host controller driver, TinyUSB port or vendor HAL runs on it unchanged. A driver for this IP is a deliverable of the product plan, not of this specification.

| Driver module | Scope | Registers used |
|---|---|---|
| Core and PHY | probe by `u2_version` and `u2_build`, reset and clock sequence S01 to S03, PHY register setup S05 | `u2_ctrl`, `u2_sts`, `u2_build`, `u2_phy_acc` |
| FIFO and DMA | region division S06, DMA setup S08, descriptor lists, window check | `u2_fifo_*`, `u2_dma_*`, `u2_dma_map` |
| Interrupt service | S16: read `u2_irq_sts`, summaries, per-entry flags, clear by w1c | `u2_irq_*`, `u2_ep_sum_*`, `u2_hc_sum`, `u2_epi_int`, `u2_epo_int`, `u2_hc_int` |
| Device stack | enumeration, EP0 control state machine, endpoint arm and halt, remote wakeup, LPM answer | `u2_dctrl`, `u2_dsts`, `u2_epi_*`, `u2_epo_*`, `u2_lpm_cfg` |
| Host stack | port reset and enumeration, channel scheduling, split, polling, over-current | `u2_hport`, `u2_hsts`, `u2_hc_*` |

EP0 control transfer reference (device): arm EP0 OUT for the SETUP packet (`ep_en`), on the `setup` flag read the eight bytes from the receive region, arm the data stage with `xsize` and the direction, arm the status stage in the opposite direction with a zero-length packet, and on `ep_dis` or `stall` follow the halt rules of REF-001 section 8.5.3. A DWC_otg-compatible register view is an option that would cost registers and is recorded as TBD-013 for a product decision.

""" + t[a:]

# ----------------------------------------------------------------- 12 errors
ins_after("| ERR-014 |", """| ERR-015 | FIFO RAM parity error on a read (PARA_USB2_RAM_PAR_EN = 1) | Packet aborted, no handshake (IN) or NAK (OUT) | `ram_par` | Write 1; software resets the endpoint | Cleared |
| ERR-016 | Register command FIFO full | Write dropped | `xq_ovf` | Write 1; software reads `xq_free` before writing | Cleared |
| ERR-017 | DMA address outside the window (win_en = 1) | Transfer stopped before the AXI access | `dma_err` | Write 1; software corrects the address | Cleared |""", "## 12. Error handling", "## 13. Performance")

# ----------------------------------------------------------------- 13 performance, area, power
setline("| PERF-002 |", "| PERF-002 | Device response time (link decision time from the end of the received packet to TXValid or the TX CMD) | At most 14 CLK-PHY cycles at 60 MHz (UTMI+ 8-bit and ULPI, REF-006 and REF-007 Table 10) and at most 4 cycles at 30 MHz (UTMI+ 16-bit); within 24 cycles (192 bit times) at the connector | HS | Simulation with timing checker, cycle budget table below | Hard |", "## 13. Performance", "## 14. RTL implementation")
ins_after("| PERF-003 |", """
**Turnaround cycle budget (review F-009).** A device that answers a token must start its packet within 192 bit times (REF-001 section 7.1.18.2, 24 cycles at 60 MHz, 12 cycles at 30 MHz). The PHY consumes part of it: the Receive End Delay is 3 to 8 CLK at 60 MHz and 2 to 6 CLK at 30 MHz, and the TX Start Delay is 1 to 2 CLK (UTMI 1.05 section 6.4 and REF-006 section 2.1.1.5; ULPI Table 9). What remains for the link is the SIE decision time:

| Interface | Limit at the connector | PHY Receive End Delay (max) | PHY TX Start Delay (max) | Link decision time allowed | Link path of this IP (stages) | Margin |
|---|---|---|---|---|---|---|
| UTMI+ 8-bit, 60 MHz | 24 CLK | 8 CLK | 2 CLK | 14 CLK (UTMI 1.05) | handshake 3, IN data 4 | 10 CLK |
| UTMI+ 16-bit, 30 MHz | 12 CLK | 6 CLK | 2 CLK | 4 CLK | handshake 3, IN data 4 with prefetch | 0 CLK for IN data |
| ULPI 8-bit, 60 MHz | 24 CLK | 8 CLK | 2 CLK | 14 CLK (ULPI Table 10, receive-transmit 1 to 14) | handshake 4, IN data 5 (TX CMD stage) | 9 CLK |

Link path stages: (1) RXActive falling edge detected, (2) token CRC5 and endpoint match, (3) handshake or PID byte presented, (4) first data word available (the first word of every armed IN packet is prefetched into the engine before the IN token, so no RAM latency is on the path), (5) ULPI TX CMD driven. The 16-bit configuration has no margin for IN data, so it needs the prefetch and no extra pipeline stage. Host transmit-to-transmit spacing is 88 to 192 bit times (11 to 24 CLK at 60 MHz; ULPI Table 10: 15 to 24 clocks counted from stp).

**Area proxy and power assumption (review F-012).** Label: proxy, not a mapped area (no library or corner).

| Item | Default counts | Maximum counts | Basis |
|---|---|---|---|
| CSR control flip-flops (rw, rwi, w1c bits) | CSRFF_DEF | CSRFF_MAX | `csr/regs_usb2.json`; banks of 9 endpoint, 8 channel and 4 DMA entries (default) or 16 each (maximum) |
| CSR status inputs (ro bits) | CSRRO_DEF | CSRRO_MAX | same source, not flip-flops |
| FIFO RAM | 4 KB (1 024 x 32) | 128 KB (32 768 x 32) | PARA_USB2_FIFO_DEPTH default and maximum, plus one parity bit per word |
| Crossing FIFOs | 2 x 8 x 48 + 8 x 36 bits | same | CDC-001, CDC-002, MEM-002 |

Power assumption: activity of the CLK-PHY domain follows the traffic, the FIFO RAM is enabled only on an access, and an idle bus (suspend, L1) stops CLK-PHY through the PHY; a power number is produced only from simulation activity of TEST-006 and TEST-017 on the CFG-DUAL-FULL netlist. Evaluation of sharing the device and host register banks (the DWC_otg databook, REF-011 table 3-4, reuses the device registers as host registers because the roles are exclusive): the host banks hold 1 288 control flip-flops at 8 channels, about a third of the default total; sharing is not adopted in this release because it changes the software model (TBD-013).
""", "## 13. Performance", "## 14. RTL implementation")

# ----------------------------------------------------------------- 14 implementation
ins_after("| `m_usb2_lpbk` |", """| `m_usb2_xreg` | Register command FIFO, register update FIFO, generation tags, shadow registers of CLK-PHY (CDC-001, CDC-002) | `u_xreg` | both | CSR write strobes and hardware loads, shadow registers, update stream |
| `m_usb2_ulpilp` | ULPI low power wake detector and hand-off of `o_ulpi_stp` (always on, CDC-007) | `u_ulpilp` in `m_usb2_phyif_ulpi` | CLK-BUS | `i_ulpi_dir`, `i_ulpi_data[3:0]`, `o_ulpi_stp` request |
| `m_usb2_cfgchk` | Elaboration check of the parameters and derivation of the bank counts (REQ-PARAM-003, REQ-PARAM-004) | `u_cfgchk` | none (elaboration) | parameters |""", "### 14.2 RTL hierarchy", "### 14.3 Synthesis assumptions")
ins_after("| Lint rule configuration |", """| Expected critical paths | CRC16 update per byte in `m_usb2_crc16` (one byte per cycle at 60 MHz, a pipeline stage between byte capture and remainder); token decode and endpoint match (stage 2 of the turnaround path); RAM arbitration of `m_usb2_fifo`; address generation of the DMA at CLK-BUS; a synthesis run of CFG-DUAL-FULL is required before RTL sign-off |""", "### 14.3 Synthesis assumptions", "## 15. Verification")
a = t.index("## 15. Verification specification")
t = t[:a] + """### 14.4 Integration checklist

| Item | What the integrator provides or checks |
|---|---|
| Wrapper | choose one of `m_usb2_top_utmi_axim`, `_utmi_axis`, `_ulpi_axim`, `_ulpi_axis`; set the parameters of section 8 |
| Clocks | `i_clk_phy` from the PHY (60 MHz or 30 MHz); `i_clk_bus` at 30 MHz or faster (100 MHz or faster for REQ-PERF-001); asynchronous groups of EXC-001 |
| Resets | `i_rst_n_phy`, `i_rst_n_bus`; `o_phy_rst_n` to the PHY; release order in section 11.2 S01 to S03 |
| Tie-offs | `i_protect_en`, `i_slverr_en` constants; `i_ovrcur_n` = 1 when no switch flag exists; `i_dft_test_en` = 0, `i_dft_scan_en` = 0 outside test; unused AXI or DMA ports of the other profile do not exist in the wrapper |
| Pads | bidirectional `io_ulpi_data` pad wrapper driven by `o_ulpi_data_oe`, `o_ulpi_data`, `i_ulpi_data`; `o_ulpi_stp` must be a pin that the link can drive while CLK-PHY is stopped |
| Macros | FIFO RAM macro of `LPARA_USB2_RAM_W` (+1 parity) bits and PARA_USB2_FIFO_DEPTH words, wrapped as `u_dont_touch_sram`; library synchronizer cells |
| VBUS | `o_vbus_pwr_en` to the load switch and `i_ovrcur_n` from its flag; board filter (TBD-012) |
| Interrupt and DMA | `o_int_usb` to the interrupt controller; DMA channel mapping for AXI-slave builds; address window of the SoC (u2_dma_wbase and wlim) |
| Power-up checks | read `u2_version` and `u2_build`; wait for `u2_sts.phyclk_ok`; run the loopback self-test S19 if no PHY is wired yet |

""" + t[a:]

# ----------------------------------------------------------------- 15 verification
sub("FPGA prototype with a USB PHY chip after RTL;", "FPGA prototype with a USB PHY chip after RTL, with interoperability runs against real stacks (REQ-VER-003); simulation time scaling by PARA_USB2_TSCALE (REQ-VER-002);")
ins_after("| SVA-011 |", """| SVA-012 | The register command FIFO never overflows silently: a write while xq_free = 0 is dropped and sets xq_ovf; the order of commands is preserved | REQ-CLK-003, REQ-REG-002 | Simulation, formal | Never fails |
| SVA-013 | A hardware update whose generation tag differs from the CSR-side tag never changes the CSR field | REQ-REG-003 | Simulation, formal | Never fails |
| SVA-014 | `o_ulpi_stp` has no glitch at the hand-off between CLK-PHY and the wake detector, and is released only in the cycle after `i_ulpi_dir` falls | REQ-IF-011 | Simulation | Never fails |
| SVA-015 | A parity error aborts the packet and no wrong data is sent | REQ-FUNC-040 | Simulation, fault injection | Never fails |""", "### 15.3 Assertions and coverage", "### 15.4 Formal, CDC, and RDC")

# ----------------------------------------------------------------- 16 DFT, 17 timing, 18 security
setline("| Scan/test clocks, controls, reset behavior |", "| Scan/test clocks, controls, reset behavior | The SoC clock controller owns the scan clock mux and drives `i_clk_phy` and `i_clk_bus` with the scan clock in test mode; `i_dft_test_en` makes `m_usb2_rst` override the resets and `i_dft_scan_en` is the test enable of every clock gate |", "## 16. DFT", "## 17. Physical design")
setline("| Test access, wrappers, test points |", "| Test access, wrappers, test points | Functional ports `i_dft_test_en` and `i_dft_scan_en` are in section 6.2; the scan chain ports `i_dft_scan_in_*` and `o_dft_scan_out_*` are added by the scan insertion flow; the FIFO RAM wrapper bypasses the macro when `i_dft_test_en` = 1 and MBIST is added by the SoC memory flow |", "## 16. DFT", "## 17. Physical design")
sub("is the clock source that the integrator", "is the clock source that the integrator", 0) if False else None
setline("| UTMI+ inputs |", "| UTMI+ inputs | Input | CLK-PHY | assumed 50 % of the period (8.33 ns at 60 MHz) until the PHY macro datasheet gives numbers (ASM-027, TBD-007) | PHY output drive | Half period for setup | UTMI+ builds | `sdc/usb2_io.sdc` |", "#### 17.1.2 Interface timing budgets", "#### 17.1.3 Timing exception inventory")
setline("| UTMI+ outputs |", "| UTMI+ outputs | Output | CLK-PHY | assumed 50 % of the period (ASM-027, TBD-007) | PHY input load | Half period | UTMI+ builds | `sdc/usb2_io.sdc` |", "#### 17.1.2 Interface timing budgets", "#### 17.1.3 Timing exception inventory")
setline("| ULPI inputs and outputs |", "| ULPI inputs and outputs | Input and output | CLK-PHY | ULPI Table 5 as read, PHY output clock mode: input setup 6.0 ns, input hold 0.0 ns, output delay 9.0 ns maximum (the converted table is partly garbled; verify with the official copy, ASM-027) | PHY and pad | Per REF-007 Table 5 | ULPI builds | `sdc/usb2_io.sdc` |", "#### 17.1.2 Interface timing budgets", "#### 17.1.3 Timing exception inventory")
sub("`sdc/usb2_clocks.sdc` (delivered with the RTL)", "`sdc/usb2_clocks.sdc` (delivered in this folder)")
setline("| ECC/parity and fault detection |", "| ECC/parity and fault detection | Required: one parity bit per FIFO RAM word when PARA_USB2_RAM_PAR_EN = 1 (default), checked on every read before the CRC is generated, error flag `ram_par` (REQ-FUNC-040, ASM-025); the USB CRC protects the wire but not the RAM, because the CRC is generated from the bytes read from the RAM | Fault injection test |", "## 18. Security", "## 19. Requirement-to-verification")
setline("| Access control / privilege |", "| Access control / privilege | Required: `i_protect_en` and PPROT[1] limit CSR access (section 11.4); an optional DMA address window (u2_dma_wbase, u2_dma_wlim, win_en) contains a faulty buffer or descriptor address (REQ-IF-014); the AXI master attributes come from `u2_dma_cfg.axi_prot` | CSR test, DMA window test |", "## 18. Security", "## 19. Requirement-to-verification")

# ----------------------------------------------------------------- 20 decisions, owners, dates
a = t.index("## 20. Assumptions, dependencies, and decisions")
b = t.index("## 21. Glossary")
sec = t[a:b]
lines = sec.split("\n")
out = []
owners = {"DEP": "integrator", "TBD": "spec owner", "ASM": "spec owner"}
for l in lines:
    if l.startswith("| ID | Type"):
        l = l.rstrip() + " Owner | Opened |"
    elif l.startswith("|---|---|---|---|---|") and "Owner" not in l:
        l = l + "---|---|"
    elif re.match(r"^\| (ASM|DEP|TBD)-\d+ ", l):
        key = l[2:5]
        owner = "user" if ("Open: confirm" in l or "Open:" in l) and key == "ASM" else owners[key]
        l = l.rstrip() + " %s | 2026-11-20 |" % owner
    out.append(l)
sec = "\n".join(out)
t = t[:a] + sec + t[b:]
setline("| ASM-001 ", "| ASM-001 | Assumption | The UTMI+ 1.0, ULPI 1.1 and UTMI 1.05 texts in `reference/md_doc/` come from third-party mirrors (nxp.com, sparkfun.com) and the Intel site; their licences forbid redistribution or are unverified, so the converted files stay out of version control. The UTMI+ copy has 26 pages, the page-level `verify` check reports differences, and some tables (ULPI Table 5 and Table 24) are partly garbled; numbers read from them are marked 'as read'. | Protocol statements citing these files rest on copies whose completeness is unconfirmed (review F-007) | Open: the user supplies official copies and the pages that differ by more than 5 % are inspected | user | 2026-11-20 |", "## 20. Assumptions", "## 21. Glossary")
setline("| ASM-007 ", "| ASM-007 | Assumption | The only AXI text in `md_doc` is AXI v1.0 (AXI3 era). The profile is limited to the behavior of that text (INCR bursts of at most 16 beats, no lock, QoS, region or user), which is also legal in AXI4; no AXI4-only feature is used. | AXI4 256-beat INCR bursts and the AXI4 protocol text are not used | Applied to the text of REQ-IF-006, REQ-IF-007 and section 2.3 (review F-006); the AXI4 standard is still to be added to `md_doc` | spec owner | 2026-11-20 |", "## 20. Assumptions", "## 21. Glossary")
setline("| TBD-005 ", "| TBD-005 | Decision | ULPI low power mode and register access abort. | Section 6.3, 7.4 | Resolved 2026-11-20: REQ-IF-011, FSM ulpi_if states LP and WAKE, CDC-007 and `m_usb2_ulpilp` from REF-007 sections 3.9.1 to 3.9.3 | spec owner | 2026-11-20 |", "## 20. Assumptions", "## 21. Glossary")
setline("| TBD-007 ", "| TBD-007 | Decision | UTMI+ input and output delays need the PHY macro datasheet; the ULPI numbers are 'as read' from a garbled table. | Section 17 | Open, narrowed to UTMI+ and the verification of ULPI Table 5 (ASM-027) | user | 2026-11-20 |", "## 20. Assumptions", "## 21. Glossary")
setline("| TBD-009 ", "| TBD-009 | Decision | DFT port names and scan architecture. | Section 16 | Resolved 2026-11-20: ports `i_dft_test_en` and `i_dft_scan_en` in section 6.2; chain ports by the insertion flow; scan clock mux owned by the SoC | spec owner | 2026-11-20 |", "## 20. Assumptions", "## 21. Glossary")
setline("| TBD-010 ", "| TBD-010 | Decision | FIFO RAM parity or ECC for the drone product. | Section 18 | Resolved 2026-11-20 as ASM-025: one parity bit per word, default on | user | 2026-11-20 |", "## 20. Assumptions", "## 21. Glossary")
ins_after("| TBD-012 ", """| ASM-025 | Assumption | A FIFO RAM soft error is detected by one parity bit per word (PARA_USB2_RAM_PAR_EN, default 1), not by ECC; the CRC does not protect the RAM because it is generated from the RAM output. | RAM width and `ram_par` flag | Open: confirm for the drone product | user | 2026-11-20 |
| ASM-026 | Assumption | Millisecond timers can be divided by PARA_USB2_TSCALE in simulation only. | Verification time | Open: confirm | spec owner | 2026-11-20 |
| ASM-027 | Assumption | The UTMI+ input and output delays are assumed to be 50 % of the CLK-PHY period and the ULPI delays are read from a partly garbled table. | `sdc/usb2_io.sdc` | Open until the PHY datasheet and the official ULPI text are available | user | 2026-11-20 |
| ASM-028 | Assumption | The first word of every armed IN packet is prefetched before the IN token so that the 16-bit UTMI+ turnaround budget of 4 cycles holds. | Engine and FIFO design | Open: confirm by the RTL cycle count | spec owner | 2026-11-20 |
| TBD-013 | Decision | Sharing the device and host register banks (about 1 288 flip-flops) and a DWC_otg-compatible register view. | Section 11, 13 | Open: product decision | user | 2026-11-20 |
| TBD-014 | Decision | L1 timing values (TL1 parameters) of the LPM ECN are not yet in REQ-FUNC-021. | Section 3 | Open | spec owner | 2026-11-20 |""", "## 20. Assumptions", "## 21. Glossary")

# ----------------------------------------------------------------- 21 glossary
ins_after("| Descriptor |", """| Generation tag | 4-bit counter per register that marks which software write a hardware update belongs to |
| Register command FIFO | Asynchronous FIFO that carries CSR writes from CLK-BUS to CLK-PHY |
| Register update FIFO | Asynchronous FIFO that carries hardware-changed values from CLK-PHY to CLK-BUS |
| SIE decision time | Time the link needs from the end of a received packet to the start of its response |""", "## 21. Glossary", "## 22. References")

# CSR flop proxy numbers
def width(b):
    m = re.fullmatch(r"\[(\d+)(?::(\d+))?\]", b)
    hi = int(m.group(1)); lo = int(m.group(2)) if m.group(2) else hi
    return hi - lo + 1


d = json.load(open(ROOT + r"\csr\regs_usb2.json"))
ff = {False: 0, True: 0}; ro = {False: 0, True: 0}
for r in d["registers"]:
    f = sum(width(x["bits"]) for x in r["fields"] if x["type"] in ("rw", "rwi", "w1c", "wo", "w0c", "w2c", "r2c") and x["name"] != "reserved")
    q = sum(width(x["bits"]) for x in r["fields"] if x["type"] == "ro" and x["name"] != "reserved")
    rep = r.get("repeat")
    for mx in (False, True):
        k = (rep["max"] if mx else rep["count"]) if rep else 1
        ff[mx] += f * k; ro[mx] += q * k
fmt = lambda n: "{:,}".format(n).replace(",", " ")
sub("CSRFF_DEF", fmt(ff[False])); sub("CSRFF_MAX", fmt(ff[True])); sub("CSRRO_DEF", fmt(ro[False])); sub("CSRRO_MAX", fmt(ro[True]))

open(H, "w", encoding="utf-8", newline="\n").write(t)
print("ok", len(t.splitlines()), ff, ro)
