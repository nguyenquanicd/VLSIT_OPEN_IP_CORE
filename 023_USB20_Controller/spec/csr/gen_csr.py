"""Builds regs_usb2.json for the USB 2.0 controller CSR workbook."""
import json

P = "u2"
regs = []


def desc(full, usage, values, unit="none", limits="none"):
    lines = []
    for i, v in enumerate(values):
        lines.append(v + (";" if i < len(values) - 1 else "."))
    return "%s\n\nUsage: %s\n\nValues:\n%s\n\nUnit: %s.\n\nLimits: %s." % (full, usage, "\n".join(lines), unit, limits)


def fld(name, bits, typ, reset, full, usage, values, unit="none", limits="none"):
    return {"name": name, "bits": bits, "type": typ, "reset": reset,
            "description": desc(full, usage, values, unit, limits)}


def rsv(bits):
    return {"name": "reserved", "bits": bits, "type": "ro", "reset": "0x0", "description": ""}


def reg(name, off, text, fields, repeat=None):
    r = {"name": "%s_%s" % (P, name), "offset": off, "description": text.replace("USB 2.0 ", "USB2 "), "fields": fields}
    if repeat:
        r["repeat"] = repeat
    regs.append(r)


def bank(count, mx):
    return {"mode": "PARAMETERIZED", "count": count, "stride": "0x4", "max": mx}


def flag(name, bit, full, usage, a="0x0 flag clear (reset value)", b="0x1 flag set", typ="rw"):
    return fld(name, "[%d]" % bit, typ, "0x0", full, usage, [a, b])


# ---------------------------------------------------------------- version
regs.append({"name": "u2_version", "offset": "0x0",
             "description": "USB2 controller version register. Reports the IP major and minor version numbers.",
             "fields": [
                 fld("major", "[31:16]", "ro", "0x1", "Major version number of the IP. Software reads it to select a compatible driver.",
                     "Read after reset; software never writes this field.", ["0x1 major version 1 (reset value)"], "none", "16-bit unsigned value"),
                 fld("minor", "[15:0]", "ro", "0x0", "Minor version number of the IP. Software reads it to identify compatible additions.",
                     "Read after reset; software never writes this field.", ["0x0 minor version 0 (reset value)"], "none", "16-bit unsigned value")]})

# ---------------------------------------------------------------- ctrl
reg("ctrl", "0x4", "USB 2.0 controller global control register. Enables the core, resets it and selects the role override.", [
    flag("core_en", 0, "Core enable. Lets the protocol engines, the FIFO manager and the PHY interface run.",
         "Set after the FIFO regions, the endpoint or channel registers and the DMA registers are programmed; clear before changing PARA-independent role or FIFO settings.",
         "0x0 core disabled, the bus side is idle (reset value)", "0x1 core enabled"),
    fld("swrst", "[1]", "rwi", "0x0", "Core soft reset. Returns all protocol state of the CLK-PHY domain to its reset value while the registers keep their values.",
        "Software writes 1; hardware clears the bit when the reset has finished in both clock domains; poll it before reprogramming.",
        ["0x0 no reset pending (reset value)", "0x1 reset requested or in progress"]),
    flag("phy_rst", 2, "PHY reset output. Drives o_phy_rst_n to the PHY.",
         "Set to hold the PHY in reset; clear after the PHY supply and clock are stable.",
         "0x0 PHY reset released", "0x1 PHY held in reset"),
    flag("role_ovr_en", 3, "Role override enable. Ignores the ID indication of the PHY in a dual-role build.",
         "Write before core_en; used when the board has no ID pin or for tests.",
         "0x0 role follows the PHY ID indication (reset value)", "0x1 role follows role_ovr"),
    flag("role_ovr", 4, "Role override value. Selects the role used when role_ovr_en is 1.",
         "Valid only when role_ovr_en is 1; change only while no device is attached.",
         "0x0 device role (reset value)", "0x1 host role"),
    flag("dma_en", 5, "DMA enable. Lets the AXI4 master DMA or the DMA request logic serve FIFO traffic.",
         "Set after the dma_cfg and the endpoint or channel address registers are programmed.",
         "0x0 DMA disabled, software moves data through the FIFO window (reset value)", "0x1 DMA enabled"),
    fld("ahb_err_stop", "[6]", "rw", "0x1", "Stop on bus error. Disables the DMA of the failing endpoint or channel after an AXI error response.",
        "Leave 1 so that a faulty buffer address cannot corrupt memory further.",
        ["0x0 continue after an AXI error", "0x1 stop the transfer on an AXI error (reset value)"]),
    flag("lpbk", 7, "Link loopback. Feeds the transmitted packet bytes back into the packet receiver inside the link and isolates the PHY pins.",
         "Write before core_en for bring-up tests without a PHY; clear for normal operation; counters are in u2_lpbk_sts.",
         "0x0 normal operation (reset value)", "0x1 link loopback"),
    rsv("[31:8]")])
# ---------------------------------------------------------------- status
reg("sts", "0x8", "USB 2.0 controller status register. Reports the live role, speed, line and VBUS state.", [
    flag("role", 0, "Active role. Shows whether the controller currently acts as host or device.",
         "Read after the role_chg interrupt; valid when core_en is 1.", "0x0 device role (reset value)", "0x1 host role", "ro"),
    fld("speed", "[2:1]", "ro", "0x1", "Negotiated bus speed. Shows the speed set by the chirp handshake or by the attached device.",
        "Read after the enum interrupt; undefined while detached.",
        ["0x0 high-speed", "0x1 full-speed (reset value)", "0x2 low-speed", "0x3 reserved"]),
    flag("attached", 3, "Attach state. Shows that a device is connected (host role) or a host drives VBUS (device role).",
         "Read after the conn or disc interrupt.", "0x0 not attached (reset value)", "0x1 attached", "ro"),
    flag("suspended", 4, "Suspend state. Shows that the bus is suspended or in L1 sleep.",
         "Read after the suspend or resume interrupt.", "0x0 bus active (reset value)", "0x1 bus suspended", "ro"),
    fld("linestate", "[6:5]", "ro", "0x0", "Line state of D+ and D-. Shows the filtered LineState or the RX CMD line state of the PHY.",
        "Read for debug; the value follows the bus and changes without notice.",
        ["0x0 SE0 (reset value)", "0x1 J state", "0x2 K state", "0x3 SE1 or reserved"]),
    flag("vbus_valid", 7, "VBUS valid. Shows that VBUS is above the operating threshold.",
         "Read before enabling the device role pull-up or the host VBUS drive.", "0x0 VBUS below threshold (reset value)", "0x1 VBUS valid", "ro"),
    flag("id_a_plug", 8, "ID indication. Shows the plug type that the PHY reports.",
         "Read in dual-role builds; the value is meaningful after the PHY ID sampling time of 50 ms.", "0x0 B plug, device (reset value)", "0x1 A plug, host", "ro"),
    flag("rstbusy", 9, "Reset busy. Shows that a soft reset or a bus reset sequence is running.",
         "Poll after writing swrst or after a port reset.", "0x0 idle (reset value)", "0x1 busy", "ro"),
    flag("phyclk_ok", 10, "PHY clock present. Shows that CLK-PHY toggles.",
         "Poll after releasing phy_rst; the CSR stays accessible without the PHY clock.", "0x0 PHY clock absent (reset value)", "0x1 PHY clock present", "ro"),
    fld("xq_free", "[16:11]", "ro", "0x8", "Free command entries. The number of free entries of the register command FIFO that carries CSR writes to the CLK-PHY domain.",
        "Read before a burst of writes to endpoint, channel, FIFO, role or enable fields; issue at most this many writes before reading it again.",
        ["0x0 FIFO full: further writes to crossing fields are dropped and xq_ovf is set", "0x1 to 0x8 free entries (reset value 0x8)", "0x9 to 0x3F reserved"], "entry", "0 to 8"),
    rsv("[31:17]")])

# ---------------------------------------------------------------- build
reg("build", "0xC", "USB 2.0 controller build configuration register. Reports the elaboration parameters of this build.", [
    fld("role_cfg", "[1:0]", "ro", "0x2", "Role parameter. Reports PARA_USB2_ROLE of this build.", "Read by the driver at probe time.",
        ["0x0 device only", "0x1 host only", "0x2 dual-role (reset value)", "0x3 reserved"]),
    flag("phy_ulpi", 2, "PHY interface parameter. Reports whether the build uses ULPI.", "Read at probe time.", "0x0 UTMI+ (reset value)", "0x1 ULPI", "ro"),
    flag("utmi_16", 3, "UTMI+ width parameter. Reports whether the UTMI+ interface is 16 bits wide.", "Read at probe time; it fixes the CLK-PHY frequency at 30 MHz.", "0x0 8-bit (reset value)", "0x1 16-bit", "ro"),
    flag("axi_slave", 4, "Data interface parameter. Reports whether the build uses the AXI4 slave port with DMA request and acknowledge.", "Read at probe time.", "0x0 AXI4 master DMA (reset value)", "0x1 AXI4 slave with DMA handshake", "ro"),
    flag("lpm_cfg", 5, "LPM parameter. Reports whether PARA_USB2_LPM_EN is 1.", "Read at probe time; LPM fields do nothing when 0.", "0x0 no LPM (reset value)", "0x1 LPM present", "ro"),
    flag("split_cfg", 6, "Split parameter. Reports whether PARA_USB2_SPLIT_EN is 1.", "Read at probe time; hc_spl fields do nothing when 0.", "0x0 no split (reset value)", "0x1 split present", "ro"),
    fld("num_ep", "[11:7]", "ro", "0x8", "Endpoint count parameter. Reports PARA_USB2_NUM_EP, the endpoints besides EP0.", "Read at probe time.",
        ["0x1 to 0xF endpoints besides EP0 (reset value 0x8)"], "count", "1 to 15"),
    fld("num_hc", "[16:12]", "ro", "0x8", "Host channel count parameter. Reports PARA_USB2_NUM_HC.", "Read at probe time.",
        ["0x1 to 0x10 host channels (reset value 0x8)"], "count", "1 to 16"),
    fld("fifo_log2", "[20:17]", "ro", "0xA", "FIFO depth parameter. Reports the base-2 logarithm of PARA_USB2_FIFO_DEPTH in 32-bit words.", "Read at probe time before dividing the FIFO.",
        ["0x8 to 0xF depth of 2 to the power of the value words (reset value 0xA, 1024 words)", "0x0 to 0x7 reserved"], "none", "0x8 to 0xF, depth 256 to 32768 words"),
    flag("sg_cfg", 21, "Scatter-gather parameter. Reports whether PARA_USB2_SG_EN is 1.", "Read at probe time; sg_mode has no effect when 0.", "0x0 no scatter-gather DMA (reset value)", "0x1 scatter-gather DMA present", "ro"),
    fld("dbuf_cfg", "[22]", "ro", "0x1", "Double-buffer parameter. Reports whether PARA_USB2_DBUF_EN is 1.", "Read at probe time; dbuf fields have no effect when 0.", ["0x0 no double buffering", "0x1 double buffering present (reset value)"]),
    fld("par_cfg", "[23]", "ro", "0x1", "RAM parity parameter. Reports whether PARA_USB2_RAM_PAR_EN is 1.", "Read at probe time; the ram_par interrupt exists only when 1.", ["0x0 no RAM parity", "0x1 RAM parity present (reset value)"]),
    rsv("[31:24]"),
    ])

# ---------------------------------------------------------------- interrupt set
IRQ = [
    ("sof", "start-of-frame packet sent or received"), ("busrst", "USB bus reset detected or completed"),
    ("suspend", "bus suspend or L1 sleep entered"), ("resume", "bus resume detected or completed"),
    ("conn", "device connection detected"), ("disc", "device disconnection detected"),
    ("role_chg", "role of the dual-role port changed"), ("enum", "speed enumeration finished"),
    ("pid_err", "packet with a bad PID check received"), ("crc_err", "CRC error in a received packet"),
    ("stuf_err", "bit-stuff error reported by the PHY"), ("timeout", "response time-out of a transaction"),
    ("babble", "babble or loss of activity detected"), ("fifo_ovf", "FIFO overflow"),
    ("fifo_udf", "FIFO underflow"), ("axi_err", "AXI error response"),
    ("dma_err", "DMA error"), ("lpm_evt", "LPM transaction event"),
    ("ep_xfer", "an endpoint transfer event, read the endpoint summary registers"),
    ("hc_xfer", "a host channel event, read the channel summary register"),
    ("phy_done", "PHY register access finished"),
    ("iso_inc", "an isochronous transfer was incomplete or missed"), ("ocur", "port over-current detected"),
    ("ram_par", "FIFO RAM parity error"), ("xq_ovf", "register command FIFO overflow"),
]


def irq_fields(kind):
    out = []
    for i, (n, t) in enumerate(IRQ):
        up = t[0].upper() + t[1:]
        if kind == "raw":
            out.append(fld(n, "[%d]" % i, "w1c", "0x0", "%s. Raw event flag set by hardware when the cause occurs." % up,
                           "Hardware sets it on the event; software writes 1 to clear it; a new event in the same cycle wins over the clear.",
                           ["0x0 no event (reset value)", "0x1 event occurred"]))
        elif kind == "en":
            out.append(fld(n, "[%d]" % i, "rw", "0x0", "Enable of the interrupt cause: %s. Lets the raw flag reach o_int_usb." % t,
                           "Set after the driver handler is installed; clear to mask the cause.",
                           ["0x0 cause masked (reset value)", "0x1 cause enabled"]))
        elif kind == "inj":
            out.append(fld(n, "[%d]" % i, "rw", "0x0", "Injection of the interrupt cause: %s. A rising edge raises the raw flag." % t,
                           "Write 0 and then 1 to raise the raw flag for driver tests; hardware raises the event on the 0 to 1 edge.",
                           ["0x0 no injection (reset value)", "0x1 inject the event on the rising edge"]))
        else:
            out.append(fld(n, "[%d]" % i, "ro", "0x0", "Masked status of the interrupt cause: %s. Equals raw AND enable." % t,
                           "Read in the interrupt handler to find the active causes.",
                           ["0x0 cause inactive or masked (reset value)", "0x1 cause active and enabled"]))
    out.append(rsv("[31:%d]" % len(IRQ)))
    return out


reg("irq_raw", "0x10", "USB 2.0 controller raw interrupt status register. Holds the sticky event flags of all interrupt causes.", irq_fields("raw"))
reg("irq_en", "0x14", "USB 2.0 controller interrupt enable register. Enables each cause to reach the interrupt output.", irq_fields("en"))
reg("irq_inj", "0x18", "USB 2.0 controller interrupt injection register. Raises a raw event on a rising edge for driver tests.", irq_fields("inj"))
reg("irq_sts", "0x1C", "USB 2.0 controller masked interrupt status register. Shows the raw flags that are enabled.", irq_fields("sts"))

# ---------------------------------------------------------------- device control and status
reg("dctrl", "0x20", "USB 2.0 device control register. Sets the device address, the connection and remote wakeup.", [
    fld("dev_addr", "[6:0]", "rw", "0x0", "Device address. The USB address that the device matches in token packets.",
        "Write the value of the SetAddress request after its status stage completes; keep 0 until then.",
        ["0x0 default address (reset value)", "0x1 to 0x7F assigned address"], "none", "7-bit value"),
    flag("soft_conn", 7, "Soft connect. Lets the PHY pull-up connect the device to the bus.",
         "Set after the descriptors and endpoints are ready; clear to appear disconnected to the host.",
         "0x0 disconnected (reset value)", "0x1 connected"),
    fld("rmt_wake", "[8]", "rwi", "0x0", "Remote wakeup request. Makes the device drive resume signaling.",
        "Write 1 only when remote wakeup is enabled by the host and the bus has been idle for 5 ms; hardware clears the bit when the resume pulse ends (1 to 15 ms).",
        ["0x0 no request (reset value)", "0x1 resume requested or in progress"]),
    flag("rmt_wake_en", 9, "Remote wakeup enable. Mirrors the DEVICE_REMOTE_WAKEUP feature of the host.",
         "Write 1 when the driver handles SetFeature(DEVICE_REMOTE_WAKEUP) and 0 on ClearFeature.",
         "0x0 remote wakeup not allowed (reset value)", "0x1 remote wakeup allowed"),
    fld("test_mode", "[12:10]", "rw", "0x0", "Test mode selector. Starts a USB 2.0 test mode on the device port.",
        "Write after the status stage of the SetFeature(TEST_MODE) request; leave the mode only by power cycle or reset.",
        ["0x0 test mode off (reset value)", "0x1 Test_J", "0x2 Test_K", "0x3 Test_SE0_NAK", "0x4 Test_Packet", "0x5 to 0x7 reserved"]),
    flag("dev_hs_dis", 13, "High-speed disable. Forces the device to stay in full-speed.",
         "Write before soft_conn; the device skips the chirp handshake.", "0x0 high-speed allowed (reset value)", "0x1 full-speed only"),
    rsv("[31:14]")])
reg("dsts", "0x24", "USB 2.0 device status register. Reports the device speed, frame number and LPM state.", [
    fld("frame_num", "[10:0]", "ro", "0x0", "Frame number. The 11-bit frame number of the last SOF packet received.",
        "Read for isochronous scheduling; it repeats eight times per frame in high-speed.", ["0x0 to 0x7FF last frame number (reset value 0x0)"], "frame", "11-bit value"),
    fld("uframe", "[13:11]", "ro", "0x0", "Microframe index. Counts the SOF packets with the same frame number in high-speed.",
        "Read together with frame_num.", ["0x0 to 0x7 microframe index (reset value 0x0)"], "microframe", "0 to 7"),
    flag("susp_det", 14, "Suspend detect. Shows that the device saw 3 ms of idle.", "Read after the suspend interrupt.", "0x0 active (reset value)", "0x1 suspend state", "ro"),
    flag("l1_state", 15, "L1 state. Shows that the device is in LPM L1 sleep.", "Read after the lpm_evt interrupt.", "0x0 not in L1 (reset value)", "0x1 in L1", "ro"),
    fld("lpm_hird", "[19:16]", "ro", "0x0", "Last host initiated resume duration of an accepted LPM transaction.",
        "Read after the lpm_evt interrupt; value 0 is 50 us and each step adds 75 us.", ["0x0 to 0xF HIRD code (reset value 0x0)"], "code", "4-bit value"),
    flag("lpm_rwake", 20, "Last remote-wake attribute of an accepted LPM transaction.", "Read after the lpm_evt interrupt.", "0x0 remote wake not allowed (reset value)", "0x1 remote wake allowed", "ro"),
    rsv("[31:21]")])

# ---------------------------------------------------------------- host control and status
reg("hport", "0x28", "USB 2.0 host port control register. Controls reset, suspend, resume, VBUS and test mode of the root port.", [
    fld("prst", "[0]", "rwi", "0x0", "Port reset. Drives bus reset on the root port.",
        "Write 1 to start the reset after attach debounce; hardware holds reset for the programmed time and clears the bit; the reset is at least 50 ms.",
        ["0x0 no reset (reset value)", "0x1 reset requested or in progress"]),
    fld("port_susp", "[1]", "rwi", "0x0", "Port suspend. Puts the root port into suspend.",
        "Write 1 after all traffic has stopped; hardware clears the bit when the bus is suspended.",
        ["0x0 no request (reset value)", "0x1 suspend requested"]),
    fld("port_res", "[2]", "rwi", "0x0", "Port resume. Drives resume signaling on the root port for at least 20 ms.",
        "Write 1 to resume a suspended port; hardware clears the bit when the resume sequence ends.",
        ["0x0 no request (reset value)", "0x1 resume requested or in progress"]),
    flag("vbus_drv", 3, "VBUS drive. Controls DrvVbus or the ULPI OTG control of the PHY.",
         "Set before attach detection in host role.", "0x0 VBUS off (reset value)", "0x1 VBUS on"),
    flag("sof_en", 4, "SOF generation enable. Lets the host send SOF packets.",
         "Set after the port is enabled and clear before suspend.", "0x0 no SOF (reset value)", "0x1 SOF every (micro)frame"),
    fld("test_mode", "[7:5]", "rw", "0x0", "Port test mode. Starts a USB 2.0 test mode on the host port.",
        "Write while the port is enabled; leave the mode by soft reset.",
        ["0x0 test mode off (reset value)", "0x1 Test_J", "0x2 Test_K", "0x3 Test_SE0_NAK", "0x4 Test_Packet", "0x5 Test_Force_Enable (host only)", "0x6 to 0x7 reserved"]),
    fld("lpm_req", "[8]", "rwi", "0x0", "LPM request. Sends an LPM extended transaction to the device on the next frame.",
        "Write 1 after the hird and rwake fields and the device address are set; hardware clears the bit when the device answered.",
        ["0x0 no request (reset value)", "0x1 request pending"]),
    fld("lpm_hird", "[12:9]", "rw", "0x0", "LPM host initiated resume duration code sent in the LPM token.",
        "Write before lpm_req; value 0 is 50 us and each step adds 75 us.", ["0x0 to 0xF HIRD code (reset value 0x0)"], "code", "4-bit value"),
    flag("lpm_rwake", 13, "LPM remote-wake attribute sent in the LPM token.", "Write before lpm_req.", "0x0 remote wake not allowed (reset value)", "0x1 remote wake allowed"),
    fld("lpm_addr", "[20:14]", "rw", "0x0", "Address of the device that receives the LPM token.", "Write before lpm_req.", ["0x0 to 0x7F device address (reset value 0x0)"], "none", "7-bit value"),
    flag("hs_dis", 21, "Host high-speed disable. Skips the chirp handshake and keeps the port in full-speed.",
         "Write before prst.", "0x0 high-speed allowed (reset value)", "0x1 full-speed only"),
    flag("oc_en", 22, "Over-current protection enable. Lets the over-current input switch the port power off.",
         "Set before vbus_drv in host role; clear when no power switch with an over-current flag is fitted.", "0x0 over-current input ignored (reset value)", "0x1 over-current protection on"),
    rsv("[31:23]")])
reg("hsts", "0x2C", "USB 2.0 host port status register. Reports the connect state, speed and frame number of the root port.", [
    flag("port_conn", 0, "Port connect status. Shows that a device is attached to the root port.", "Read after the conn or disc interrupt.", "0x0 no device (reset value)", "0x1 device attached", "ro"),
    flag("port_en", 1, "Port enable status. Shows that the port is enabled after reset.", "Read after the rst interrupt.", "0x0 disabled (reset value)", "0x1 enabled", "ro"),
    fld("port_speed", "[3:2]", "ro", "0x1", "Port speed. Shows the speed of the attached device.", "Read after the enum interrupt.",
        ["0x0 high-speed", "0x1 full-speed (reset value)", "0x2 low-speed", "0x3 reserved"]),
    flag("port_susp_sts", 4, "Port suspend status. Shows that the port is suspended or in L1.", "Read after port_susp or lpm_req completes.", "0x0 active (reset value)", "0x1 suspended", "ro"),
    fld("frame_num", "[18:5]", "ro", "0x0", "Host frame number. The 11-bit frame count and the 3-bit microframe index of the last SOF sent.",
        "Read to schedule periodic transfers; bits [15:5] are the frame, bits [18:16] the microframe.", ["0x0 to 0x3FFF frame and microframe (reset value 0x0)"], "microframe", "14-bit value"),
    flag("oc_act", 19, "Over-current active. Shows that the over-current input is active.", "Read after the ocur interrupt; power stays off until software clears the flag and writes vbus_drv again.", "0x0 no over-current (reset value)", "0x1 over-current", "ro"),
    flag("sg_mode", 20, "Scatter-gather mode. Makes each endpoint or channel DMA address register point to a descriptor list.",
         "Set before dma_en in builds with scatter-gather; descriptors are 8-byte entries described in section 9 of the specification.", "0x0 buffer address mode (reset value)", "0x1 descriptor list mode"),
    flag("win_en", 21, "DMA window enable. Restricts every DMA address to the window of u2_dma_wbase and u2_dma_wlim.",
         "Set before dma_en; a descriptor or buffer outside the window is not transferred and dma_err is set.", "0x0 any address is accepted (reset value)", "0x1 addresses must lie inside the window"),
    rsv("[31:22]")])

# ---------------------------------------------------------------- SOF configuration
reg("sof_cfg", "0x30", "USB 2.0 SOF timing configuration register. Sets the microframe length of the host in PHY clock cycles.", [
    fld("uf_len", "[15:0]", "rw", "0x1D4C", "Microframe length. The number of CLK-PHY cycles in one 125 us high-speed microframe.",
        "Write before sof_en; use 0x1D4C (7500) at 60 MHz and 0xEA6 (3750) at 30 MHz (16-bit UTMI+); the full-speed frame is eight times this value.",
        ["0x1D4C 7500 cycles at 60 MHz (reset value)", "0xEA6 3750 cycles at 30 MHz", "0x1 to 0xFFFF custom microframe length"], "CLK-PHY cycle", "1 to 65535"),
    rsv("[31:16]")])

# ---------------------------------------------------------------- DMA configuration
reg("dma_cfg", "0x34", "USB 2.0 DMA configuration register. Sets the burst length and AXI attributes of the master DMA.", [
    fld("burst_len", "[4:0]", "rw", "0x10", "AXI burst length. The number of beats in each DMA burst.",
        "Write before dma_en; larger bursts use the bus better but need more FIFO space.",
        ["0x1 to 0x10 beats (reset value 0x10)", "0x11 to 0x1F reserved"], "beat", "1 to 16"),
    fld("axi_cache", "[8:5]", "rw", "0x0", "AXI cache attributes driven on awcache and arcache.", "Write before dma_en.", ["0x0 to 0xF AxCACHE value (reset value 0x0)"], "none", "4-bit value"),
    fld("axi_prot", "[11:9]", "rw", "0x0", "AXI protection attributes driven on awprot and arprot.", "Write before dma_en.", ["0x0 to 0x7 AxPROT value (reset value 0x0)"], "none", "3-bit value"),
    fld("req_thr", "[19:12]", "rw", "0x10", "DMA request threshold. A write window raises o_dma_req while its queue has at least this many 32-bit words free (at least one row, at most the whole region); a read window ignores it and asks while a packet of its region waits.", "Write before dma_en in AXI slave builds.",
        ["0x1 to 0xFF words (reset value 0x10)"], "32-bit word", "1 to 255"),
    rsv("[31:20]")])
reg("dma_hi", "0x38", "USB 2.0 DMA address high register. Holds address bits 63 to 32 shared by all endpoint and channel buffers.", [
    fld("addr_hi", "[31:0]", "rw", "0x0", "High address word. Bits 63 to 32 of every DMA buffer address.", "Write before dma_en; all buffers lie in the same 4 GB window; zero for 32-bit AXI.",
        ["0x0 to 0xFFFFFFFF address bits 63 to 32 (reset value 0x0)"], "none", "32-bit value")])

# ---------------------------------------------------------------- PHY access
reg("phy_acc", "0x3C", "USB 2.0 PHY register access register. Reads and writes PHY registers through the ULPI interface.", [
    fld("reg_addr", "[7:0]", "rw", "0x0", "PHY register address. The ULPI register address that the access uses.", "Write before start; valid in ULPI builds.", ["0x0 to 0xFF register address (reset value 0x0)"], "none", "8-bit value"),
    fld("wdata", "[15:8]", "rw", "0x0", "PHY write data. The byte written to the PHY register by a write access.", "Write before start with rd_wr = 1.", ["0x0 to 0xFF write data (reset value 0x0)"], "none", "8-bit value"),
    fld("rdata", "[23:16]", "ro", "0x0", "PHY read data. The byte read from the PHY register by the last read access.", "Read after busy falls or the phy_done interrupt.", ["0x0 to 0xFF read data (reset value 0x0)"], "none", "8-bit value"),
    flag("rd_wr", 24, "Access direction. Selects a PHY register read or write.", "Write before start.", "0x0 read (reset value)", "0x1 write"),
    fld("start", "[25]", "rwi", "0x0", "Access start. Starts the PHY register access.", "Write 1 after reg_addr, wdata and rd_wr; hardware clears the bit when the access has finished.", ["0x0 idle (reset value)", "0x1 access requested or in progress"]),
    flag("busy", 26, "Access busy. Shows that a PHY register access is running.", "Poll before the next access.", "0x0 idle (reset value)", "0x1 busy", "ro"),
    rsv("[31:27]")])

# ---------------------------------------------------------------- FIFO configuration
for nm, off, txt, what in (("fifo_rx", "0x40", "USB 2.0 receive FIFO configuration register. Sets the start address and size of the shared receive region.", "receive region"),
                           ("fifo_hnp", "0x44", "USB 2.0 host non-periodic FIFO configuration register. Sets the start address and size of the host non-periodic transmit region.", "host non-periodic transmit region"),
                           ("fifo_hpt", "0x48", "USB 2.0 host periodic FIFO configuration register. Sets the start address and size of the host periodic transmit region.", "host periodic transmit region")):
    reg(nm, off, txt, [
        fld("start", "[15:0]", "rw", "0x0", "Region start. The first 32-bit word address of the %s in the FIFO RAM." % what,
            "Write before core_en; regions must not overlap.", ["0x0 to 0x7FFF word address (reset value 0x0)"], "32-bit word", "below PARA_USB2_FIFO_DEPTH"),
        fld("size", "[31:16]", "rw", "0x100", "Region size. The number of 32-bit words of the %s." % what,
            "Write before core_en; at least one maximum packet.", ["0x40 to 0x8000 words (reset value 0x100)"], "32-bit word", "at least 0x40 and start plus size not above the RAM depth")])
reg("fifo_ctl", "0x4C", "USB 2.0 FIFO control register. Flushes the receive region or a transmit region.", [
    fld("fl_rx", "[0]", "rwi", "0x0", "Receive region flush. Discards all data in the receive region.", "Write 1 when the core is idle; hardware clears the bit when the flush is done.", ["0x0 idle (reset value)", "0x1 flush requested"]),
    fld("fl_tx", "[1]", "rwi", "0x0", "Transmit region flush. Discards the data of the region selected by tx_sel.", "Write tx_sel first and then 1; hardware clears the bit when the flush is done.", ["0x0 idle (reset value)", "0x1 flush requested"]),
    fld("tx_sel", "[6:2]", "rw", "0x0", "Transmit region select. Chooses which transmit region fl_tx clears.", "Write before fl_tx.",
        ["0x0 to 0xF device IN endpoint number (reset value 0x0)", "0x10 host non-periodic region", "0x11 host periodic region", "0x12 to 0x1F reserved"]),
    rsv("[31:7]")])

# ---------------------------------------------------------------- summaries
for nm, off, txt, what in (("ep_sum_i", "0x50", "USB 2.0 IN endpoint interrupt summary register. Shows which device IN endpoints have an interrupt flag.", "IN endpoint"),
                           ("ep_sum_o", "0x54", "USB 2.0 OUT endpoint interrupt summary register. Shows which device OUT endpoints have an interrupt flag.", "OUT endpoint"),
                           ("hc_sum", "0x58", "USB 2.0 host channel interrupt summary register. Shows which host channels have an interrupt flag.", "host channel")):
    reg(nm, off, txt, [
        fld("flags", "[15:0]", "ro", "0x0", "Summary flags. Bit n is 1 when the %s n has an enabled interrupt flag." % what,
            "Read in the interrupt handler after ep_xfer or hc_xfer, then read the interrupt register of each flagged entry.", ["0x0 no flag (reset value)", "0x1 to 0xFFFF bit mask of flagged entries"], "none", "16-bit mask"),
        rsv("[31:16]")])

# ---------------------------------------------------------------- LPM configuration
reg("lpm_cfg", "0x60", "USB 2.0 LPM configuration register. Selects the device answer to an LPM token.", [
    fld("resp", "[1:0]", "rw", "0x0", "LPM answer. The handshake the device returns to an accepted LPM token.",
        "Write before soft_conn; the fields have no effect when the build has no LPM.",
        ["0x0 ACK (reset value)", "0x1 NYET", "0x2 STALL", "0x3 no response"]),
    flag("lpm_en_rt", 2, "LPM runtime enable. Lets the device or host process LPM transactions.", "Write before soft_conn or prst.", "0x0 LPM ignored (reset value)", "0x1 LPM enabled"),
    rsv("[31:3]")])

# ---------------------------------------------------------------- DMA channel map (AXI slave)
reg("dma_map", "0x100", "USB 2.0 DMA channel map register. Maps one DMA handshake channel to a FIFO region.", [
    fld("region", "[4:0]", "rw", "0x0", "Mapped region. The FIFO region that the DMA channel serves.", "Write before dma_en; one region per channel.",
        ["0x0 to 0xF device endpoint number: the IN endpoint of a write window, or the endpoint tag of the packets of a read window (reset value 0x0)", "0x1E host non-periodic queue (write window)", "0x1F host periodic queue (write window)"]),
    flag("dir_in", 5, "Channel direction. Selects a write window or a read window of the AXI slave port.", "Write before dma_en.", "0x0 read window: the DMA reads the received packets of an OUT region (reset value)", "0x1 write window: the DMA writes the rows of the transmit queue of an IN endpoint or host queue"),
    flag("ch_en", 6, "Channel enable. Lets the channel raise o_dma_req.", "Set after region and dir_in are written.", "0x0 channel disabled (reset value)", "0x1 channel enabled"),
    rsv("[31:7]")], bank(4, 16))

# ---------------------------------------------------------------- device endpoints
def ep_regs(d, base_off, indir):
    p = "ep" + d
    ZLPFIELD = (flag("zlp_en", 26, "Automatic zero-length packet. Sends a zero-length packet after the last full packet when the transfer size is a multiple of the maximum packet size.",
                     "Set before ep_en for bulk IN endpoints that end a message with a short packet.", "0x0 software adds the packet (reset value)", "0x1 hardware adds the packet")
                if indir else
                flag("short_end", 26, "End on short packet. Ends the transfer at the first packet shorter than the maximum packet size.",
                     "Set before ep_en for bulk OUT endpoints with messages of unknown length; xsize then holds the bytes not received.", "0x0 transfer ends when xsize is 0 (reset value)", "0x1 transfer ends on a short packet"))
    other = "IN" if indir else "OUT"
    n = "device %s endpoint" % other
    ctrl_off, xf_off, dma_off = [("0x%X" % (base_off + k * 0x40)) for k in range(3)]
    int_off = "0x%X" % (base_off + (0x100 if indir else 0xC0))
    ien_off = "0x%X" % (base_off + (0x140 if indir else 0x100))
    fifo_off = None
    reg(p + "_ctl", ctrl_off, "USB 2.0 %s control register. Configures and controls one %s." % (n, n), [
        fld("mps", "[10:0]", "rw", "0x0", "Maximum packet size. The largest data packet of the endpoint in bytes.", "Write before ep_en; 64 for a high-speed control endpoint, 512 for high-speed bulk.",
            ["0x0 to 0x400 bytes (reset value 0x0)"], "byte", "at most 1024"),
        fld("type", "[12:11]", "rw", "0x0", "Endpoint type. The USB transfer type of the endpoint.", "Write before ep_en.",
            ["0x0 control (reset value)", "0x1 isochronous", "0x2 bulk", "0x3 interrupt"]),
        flag("stall", 13, "Stall handshake. Makes the endpoint answer STALL.", "Set for SetFeature(ENDPOINT_HALT); clear for ClearFeature; hardware clears it for a control endpoint after the next SETUP.", "0x0 normal (reset value)", "0x1 stalled"),
        flag("active", 14, "Endpoint active. Shows that the endpoint is enabled for the current configuration.", "Read for debug.", "0x0 inactive (reset value)", "0x1 active", "ro"),
        flag("nak_sts", 15, "NAK status. Shows that the endpoint answers NAK.", "Read after set_nak or after a NAK interrupt.", "0x0 endpoint accepts traffic (reset value)", "0x1 endpoint NAKs", "ro"),
        flag("dpid", 16, "Next data toggle. Shows whether the next data packet is DATA0 or DATA1.", "Read for debug or to resume after a halt.", "0x0 DATA0 (reset value)", "0x1 DATA1", "ro"),
        fld("set_nak", "[17]", "rwi", "0x0", "Set NAK. Makes the endpoint answer NAK from now on.", "Write 1 to stop traffic; hardware clears the bit when the NAK state is active.", ["0x0 no request (reset value)", "0x1 NAK requested"]),
        fld("clr_nak", "[18]", "rwi", "0x0", "Clear NAK. Lets the endpoint accept traffic again.", "Write 1 after the buffer is ready; hardware clears the bit when done.", ["0x0 no request (reset value)", "0x1 clear requested"]),
        fld("set_d0", "[19]", "rwi", "0x0", "Set data toggle to DATA0. Forces the next packet to DATA0.", "Write 1 after SetConfiguration or ClearFeature(ENDPOINT_HALT); hardware clears the bit when done.", ["0x0 no request (reset value)", "0x1 set DATA0"]),
        fld("set_d1", "[20]", "rwi", "0x0", "Set data toggle to DATA1. Forces the next packet to DATA1.", "Write 1 to force DATA1; hardware clears the bit when done.", ["0x0 no request (reset value)", "0x1 set DATA1"]),
        fld("ep_dis", "[21]", "rwi", "0x0", "Endpoint disable. Stops the endpoint after the current packet.", "Write 1 to abort a transfer; hardware clears ep_en and this bit and raises ep_dis in the interrupt register.", ["0x0 no request (reset value)", "0x1 disable requested"]),
        fld("ep_en", "[22]", "rwi", "0x0", "Endpoint enable. Starts the programmed transfer on the endpoint.", "Write 1 after xfer, dma and fifo registers are written; hardware clears the bit when the transfer ends.", ["0x0 idle (reset value)", "0x1 transfer armed"]),
        fld("mult", "[24:23]", "rw", "0x0", "Transactions per microframe. For a high-bandwidth isochronous endpoint, the number of transactions in one microframe minus one.", "Write before ep_en; 0 for other endpoint types.", ["0x0 one transaction (reset value)", "0x1 two transactions", "0x2 three transactions", "0x3 reserved"]),
        flag("dbuf", 25, "Double buffering. Splits the endpoint region into two packet buffers used alternately.",
             "Set before ep_en; the region must hold two maximum packets; has effect only when PARA_USB2_DBUF_EN is 1.", "0x0 single buffer (reset value)", "0x1 double buffer"),
        ZLPFIELD,
        flag("buf_cur", 27, "Current buffer. Shows which of the two buffers the bus side uses next.", "Read for debug when dbuf is 1.", "0x0 buffer A (reset value)", "0x1 buffer B", "ro"),
        rsv("[31:28]")], bank(9, 16))
    reg(p + "_xfr", xf_off, "USB 2.0 %s transfer register. Holds the size and the packet count of the transfer." % n, [
        fld("xsize", "[18:0]", "rwi", "0x0", "Transfer size. The number of bytes still to move; hardware counts it down.", "Write before ep_en; read the remainder after the transfer.", ["0x0 to 0x7FFFF bytes (reset value 0x0)"], "byte", "at most 524287"),
        fld("pkt_cnt", "[28:19]", "rwi", "0x0", "Packet count. The number of packets still to move; hardware counts it down.", "Write before ep_en; for an OUT endpoint it limits the accepted packets.", ["0x0 to 0x3FF packets (reset value 0x0)"], "packet", "at most 1023"),
        rsv("[31:29]")], bank(9, 16))
    reg(p + "_dma", dma_off, "USB 2.0 %s DMA address register. Holds the low buffer address of the transfer." % n, [
        fld("addr", "[31:0]", "rwi", "0x0", "DMA buffer address, low word. Hardware advances it as data moves.", "Write before ep_en in AXI master builds; ignored in AXI slave builds.", ["0x0 to 0xFFFFFFFF buffer address (reset value 0x0)"], "byte", "aligned to the AXI data width")], bank(9, 16))
    if indir:
        reg(p + "_buf", "0x%X" % (base_off + 0xC0), "USB 2.0 IN endpoint FIFO register. Sets the transmit region of one device IN endpoint.", [
            fld("start", "[15:0]", "rw", "0x0", "Region start. The first 32-bit word address of the endpoint transmit region.", "Write before core_en; regions must not overlap.", ["0x0 to 0x7FFF word address (reset value 0x0)"], "32-bit word", "below PARA_USB2_FIFO_DEPTH"),
            fld("size", "[31:16]", "rw", "0x80", "Region size. The number of 32-bit words of the endpoint transmit region.", "Write before core_en; at least one maximum packet.", ["0x10 to 0x8000 words (reset value 0x80)"], "32-bit word", "at least 0x10")], bank(9, 16))
    ev = [("done", "transfer complete"), ("ep_dis", "endpoint disabled"), ("timeout", "time-out"), ("nak", "NAK sent"), ("nyet", "NYET sent"),
          ("stall", "STALL sent"), ("ovf", "FIFO overflow"), ("unf", "FIFO underflow"), ("setup", "SETUP packet received (OUT endpoints)"), ("iso_inc", "isochronous transfer incomplete")]
    for kind, off, rn in (("int", int_off, "interrupt"), ("ien", ien_off, "interrupt enable")):
        fl = []
        for i, (n2, t) in enumerate(ev):
            up = t[0].upper() + t[1:]
            if kind == "int":
                fl.append(fld(n2, "[%d]" % i, "w1c", "0x0", "%s. Sticky flag set by hardware when the event occurs on the endpoint." % up,
                              "Hardware sets it on the event; software writes 1 to clear it.", ["0x0 no event (reset value)", "0x1 event occurred"]))
            else:
                fl.append(fld(n2, "[%d]" % i, "rw", "0x0", "Enable of the event: %s. Lets the flag reach the endpoint summary and ep_xfer." % t,
                              "Set after the driver handler is installed.", ["0x0 event masked (reset value)", "0x1 event enabled"]))
        fl.append(rsv("[31:10]"))
        reg(p + "_" + kind, off, "USB 2.0 %s %s register. Holds the %s flags of one %s." % (n, rn, "event" if kind == "int" else "enable", n), fl, bank(9, 16))


ep_regs("i", 0x200, True)
ep_regs("o", 0x400, False)

# fix epi/epo ctrl and others: bank count for endpoints = NUM_EP + 1 (default 9)

# ---------------------------------------------------------------- host channels
reg("hc_ctrl", "0x600", "USB 2.0 host channel control register. Configures and starts one host channel.", [
    fld("mps", "[10:0]", "rw", "0x0", "Maximum packet size. The largest packet of the target endpoint in bytes.", "Write before ch_en.", ["0x0 to 0x400 bytes (reset value 0x0)"], "byte", "at most 1024"),
    fld("ep_num", "[14:11]", "rw", "0x0", "Endpoint number. The device endpoint that the channel talks to.", "Write before ch_en.", ["0x0 to 0xF endpoint number (reset value 0x0)"], "none", "4-bit value"),
    flag("ep_dir", 15, "Endpoint direction. Selects an IN or OUT transaction.", "Write before ch_en.", "0x0 OUT (reset value)", "0x1 IN"),
    fld("ep_type", "[17:16]", "rw", "0x0", "Endpoint type. The USB transfer type of the target endpoint.", "Write before ch_en.", ["0x0 control (reset value)", "0x1 isochronous", "0x2 bulk", "0x3 interrupt"]),
    fld("speed", "[19:18]", "rw", "0x0", "Device speed. The speed of the target device.", "Write before ch_en; use full-speed or low-speed behind a hub with the split fields.", ["0x0 high-speed (reset value)", "0x1 full-speed", "0x2 low-speed", "0x3 reserved"]),
    fld("dev_addr", "[26:20]", "rw", "0x0", "Device address. The USB address of the target device.", "Write before ch_en.", ["0x0 to 0x7F device address (reset value 0x0)"], "none", "7-bit value"),
    fld("mc", "[28:27]", "rw", "0x0", "Transactions per microframe. For a periodic high-bandwidth channel, the count minus one.", "Write before ch_en; 0 for other channels.", ["0x0 one transaction (reset value)", "0x1 two transactions", "0x2 three transactions", "0x3 reserved"]),
    flag("odd_frm", 29, "Odd frame. Starts a periodic transaction in an odd (micro)frame.", "Write before ch_en for periodic channels.", "0x0 even frame (reset value)", "0x1 odd frame"),
    fld("ch_dis", "[30]", "rwi", "0x0", "Channel disable. Halts the channel after the current packet.", "Write 1 to stop a transfer; hardware clears the bit and raises ch_halt.", ["0x0 no request (reset value)", "0x1 halt requested"]),
    fld("ch_en", "[31]", "rwi", "0x0", "Channel enable. Starts the programmed transfer on the channel.", "Write 1 after the xfer, dma and split registers are written; hardware clears the bit when the channel halts.", ["0x0 idle (reset value)", "0x1 transfer armed"])], bank(8, 16))
reg("hc_spl", "0x640", "USB 2.0 host channel split register. Holds the hub address and port for split transactions.", [
    fld("hub_addr", "[6:0]", "rw", "0x0", "Hub address. The USB address of the hub with the transaction translator.", "Write before ch_en when split_en is 1.", ["0x0 to 0x7F hub address (reset value 0x0)"], "none", "7-bit value"),
    fld("port_addr", "[13:7]", "rw", "0x0", "Hub port address. The downstream port of the hub where the target device sits.", "Write before ch_en when split_en is 1.", ["0x0 to 0x7F port number (reset value 0x0)"], "none", "7-bit value"),
    fld("xact_pos", "[15:14]", "rw", "0x0", "Transaction position. The position of the payload in a split isochronous OUT transaction.", "Write before ch_en for split isochronous OUT.", ["0x0 middle (reset value)", "0x1 end", "0x2 begin", "0x3 all"]),
    flag("comp_split", 16, "Complete split. Makes the next transaction a complete-split.", "Write 1 after the start-split was acknowledged.", "0x0 start-split (reset value)", "0x1 complete-split"),
    flag("split_en", 17, "Split enable. Makes the channel use split transactions.", "Write before ch_en; has no effect when the build has no split.", "0x0 no split (reset value)", "0x1 split transactions"),
    rsv("[31:18]")], bank(8, 16))
reg("hc_xfer", "0x680", "USB 2.0 host channel transfer register. Holds the size, packet count and data PID of the transfer.", [
    fld("xsize", "[18:0]", "rwi", "0x0", "Transfer size. The bytes still to move; hardware counts it down.", "Write before ch_en.", ["0x0 to 0x7FFFF bytes (reset value 0x0)"], "byte", "at most 524287"),
    fld("pkt_cnt", "[28:19]", "rwi", "0x0", "Packet count. The packets still to move; hardware counts it down.", "Write before ch_en.", ["0x0 to 0x3FF packets (reset value 0x0)"], "packet", "at most 1023"),
    fld("pid", "[30:29]", "rwi", "0x0", "Data PID. The data PID of the next packet; hardware toggles it.", "Write DATA0 for a new transfer or after SETUP.", ["0x0 DATA0 (reset value)", "0x1 DATA1", "0x2 DATA2", "0x3 MDATA"]),
    flag("setup", 31, "SETUP token. Makes the next OUT transaction a SETUP transaction.", "Write 1 for the setup stage of a control transfer.", "0x0 normal token (reset value)", "0x1 SETUP token")], bank(8, 16))
reg("hc_dma", "0x6C0", "USB 2.0 host channel DMA address register. Holds the low buffer address of the transfer.", [
    fld("addr", "[31:0]", "rwi", "0x0", "DMA buffer address, low word. Hardware advances it as data moves.", "Write before ch_en in AXI master builds.", ["0x0 to 0xFFFFFFFF buffer address (reset value 0x0)"], "byte", "aligned to the AXI data width")], bank(8, 16))
HCEV = [("done", "transfer complete"), ("ch_halt", "channel halted"), ("timeout", "response time-out"), ("nak", "NAK received"), ("nyet", "NYET received"),
        ("stall", "STALL received"), ("ack", "ACK received"), ("xact_err", "transaction error"), ("babble", "babble error"), ("tog_err", "data toggle error"), ("frm_ovr", "frame overrun"), ("poll_miss", "polled data not consumed in time"), ("iso_inc", "isochronous transfer incomplete")]
for kind, off, rn in (("int", "0x700", "interrupt"), ("ien", "0x740", "interrupt enable")):
    fl = []
    for i, (n2, t) in enumerate(HCEV):
        up = t[0].upper() + t[1:]
        if kind == "int":
            fl.append(fld(n2, "[%d]" % i, "w1c", "0x0", "%s. Sticky flag set by hardware when the event occurs on the channel." % up, "Hardware sets it on the event; software writes 1 to clear it.", ["0x0 no event (reset value)", "0x1 event occurred"]))
        else:
            fl.append(fld(n2, "[%d]" % i, "rw", "0x0", "Enable of the event: %s. Lets the flag reach the channel summary and hc_xfer." % t, "Set after the driver handler is installed.", ["0x0 event masked (reset value)", "0x1 event enabled"]))
    fl.append(rsv("[31:13]"))
    reg("hc_" + kind, off, "USB 2.0 host channel %s register. Holds the %s flags of one host channel." % (rn, "event" if kind == "int" else "enable"), fl, bank(8, 16))

reg("lpbk_sts", "0x64", "USB2 link loopback status register. Counts the packets of the link loopback test.", [
    fld("pkt_ok", "[11:0]", "ro", "0x0", "Good loopback packets. Counts packets received without error in link loopback.", "Read after a loopback test; clear with clr.", ["0x0 to 0xFFF count (reset value 0x0)"], "packet", "saturates at 4095"),
    fld("pkt_err", "[23:12]", "ro", "0x0", "Bad loopback packets. Counts packets with a PID or CRC error in link loopback.", "Read after a loopback test; clear with clr.", ["0x0 to 0xFFF count (reset value 0x0)"], "packet", "saturates at 4095"),
    fld("clr", "[24]", "rwi", "0x0", "Clear counters. Sets both counters to zero.", "Write 1 before a test; hardware clears the bit when done.", ["0x0 idle (reset value)", "0x1 clear requested"]),
    rsv("[31:25]")])

reg("dma_wbase", "0x68", "USB2 DMA window base register. Holds the lowest address that the DMA may access when the window is enabled.", [
    fld("addr", "[31:0]", "rw", "0x0", "Window base. The lowest byte address that a DMA buffer or descriptor may use when win_en is 1.", "Write before dma_en together with u2_dma_wlim; the high word is taken from u2_dma_hi.",
        ["0x0 to 0xFFFFFFFF base address (reset value 0x0)"], "byte", "not above u2_dma_wlim.addr")])

reg("dma_wlim", "0x6C", "USB2 DMA window limit register. Holds the highest address that the DMA may access when the window is enabled.", [
    fld("addr", "[31:0]", "rw", "0xFFFFFFFF", "Window limit. The highest byte address that a DMA buffer or descriptor may use when win_en is 1.", "Write before dma_en together with u2_dma_wbase; the high word is taken from u2_dma_hi.",
        ["0x0 to 0xFFFFFFFF limit address (reset value 0xFFFFFFFF)"], "byte", "not below u2_dma_wbase.addr")])

reg("hc_cfg", "0x780", "USB2 host channel extension register. Selects double buffering, packet termination and interval polling of one channel.", [
    flag("dbuf", 0, "Double buffering. Splits the channel region into two packet buffers used alternately.", "Set before ch_en; has effect only when PARA_USB2_DBUF_EN is 1.", "0x0 single buffer (reset value)", "0x1 double buffer"),
    flag("zlp_en", 1, "Automatic zero-length packet. Sends a zero-length packet after the last full OUT packet when the transfer size is a multiple of the maximum packet size.", "Set before ch_en for bulk OUT channels.", "0x0 software adds the packet (reset value)", "0x1 hardware adds the packet"),
    flag("short_end", 2, "End on short packet. Ends an IN transfer at the first packet shorter than the maximum packet size.", "Set before ch_en for bulk IN channels with messages of unknown length.", "0x0 transfer ends when xsize is 0 (reset value)", "0x1 transfer ends on a short packet"),
    flag("poll_en", 3, "Interval polling. Makes the host issue the transaction of the channel once per interval.", "Set for interrupt and isochronous channels before ch_en; hardware retries a NAK or NYET at the next interval.", "0x0 one transfer per ch_en (reset value)", "0x1 polled every interval"),
    flag("poll_rep", 4, "Poll repeat. Re-arms the channel automatically after each completed transfer while poll_en is 1.", "Set when software consumes each packet before the next interval; otherwise the poll_miss flag is set.", "0x0 stop after one transfer (reset value)", "0x1 repeat every interval"),
    fld("interval", "[20:5]", "rw", "0x1", "Polling interval. The number of microframes (high-speed) or frames (full-speed and low-speed) between two transactions.", "Write before ch_en from the bInterval of the endpoint descriptor.", ["0x1 to 0xFFFF intervals (reset value 0x1)"], "microframe or frame", "1 to 65535"),
    flag("buf_cur", 21, "Current buffer. Shows which of the two buffers the bus side uses next.", "Read for debug when dbuf is 1.", "0x0 buffer A (reset value)", "0x1 buffer B", "ro"),
    rsv("[31:22]")], bank(8, 16))

doc = {"module": "m_vlsit_csr_usb2", "prefix": P, "async": 0, "ip_version": {"major": 1, "minor": 0}, "registers": regs}
json.dump(doc, open("regs_usb2.json", "w"), indent=1)
print(len(regs), "registers")
