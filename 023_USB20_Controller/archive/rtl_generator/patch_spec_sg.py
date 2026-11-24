p = '../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md'
lines = open(p, encoding='utf-8').read().split('\n')


def setline(prefix, new, count=1):
    n = 0
    for i, l in enumerate(lines):
        if l.startswith(prefix):
            lines[i] = new
            n += 1
    assert n == count, (prefix, n)


def after(prefix, new):
    for i, l in enumerate(lines):
        if l.startswith(prefix):
            lines.insert(i + 1, new)
            return
    raise AssertionError(prefix)


setline("Scatter-gather descriptor (PARA_USB2_SG_EN = 1, sg_mode = 1)",
        "Scatter-gather descriptor (PARA_USB2_SG_EN = 1, sg_mode = 1; DEC-013): each descriptor is two 32-bit words in "
        "system memory, aligned to 8 bytes, little-endian, and describes the buffer of one USB packet. The DMA address "
        "register of the endpoint or channel (`u2_epi_dma`, `u2_epo_dma`, `u2_hc_dma`) holds the address of the current "
        "descriptor and hardware adds 8 to it after each packet. Word 0 is the buffer address bits [31:0]; bits [63:32] "
        "come from `u2_dma_hi`. Word 1 holds `len` in bits [15:0] (size of the buffer in bytes, 0 to 65535), the "
        "software bits `last` (bit 16), `ioc` (bit 17) and [23:18], which hardware keeps as written, and the status "
        "written back by hardware in bits [31:24]: bit 24 `done`, bit 25 `err` (the packet did not fit the buffer), bit "
        "26 `short` (bytes of the buffer were left over), other bits 0. After the packet hardware rewrites `len` with the "
        "number of bytes not transferred. An IN (transmit) descriptor sends min(`len`, maximum packet size, bytes left "
        "of the transfer) bytes, so software gives `len` not larger than the maximum packet size; a transmit descriptor "
        "with `len` = 0 ends the transfer. An OUT (receive) packet longer than `len` is not stored: the descriptor gets "
        "`err` and `done`, `len` stays unchanged and the DMA pulses `dma_err`. The interrupts are those of the endpoint "
        "or channel; `last` and `ioc` are not interpreted by hardware (ASM-020, DEC-013).")

setline("| REQ-FUNC-036 | When PARA_USB2_SG_EN",
        "| REQ-FUNC-036 | When PARA_USB2_SG_EN = 1 and sg_mode = 1 the AXI4 master DMA shall treat the address register of an "
        "endpoint or channel as the pointer to the current 8-byte descriptor of section 9, shall read one descriptor "
        "per packet, shall move the packet to or from the buffer of the descriptor, shall write back `done`, `err`, "
        "`short` and the number of bytes not transferred, shall add 8 to the pointer after each packet, and shall "
        "pulse `dma_err` for an OUT packet that does not fit the buffer. | ASM-020 | AXI-master wrappers with SG | "
        "Simulation |")

setline("| TEST-028 |",
        "| TEST-028 | REQ-FUNC-036 | Descriptor lists of two OUT and two IN packets with the last and ioc bits set, an "
        "OUT packet longer than the buffer of its descriptor, and the pointer after each packet | Status written back "
        "once per packet with the software bits kept; pointer advanced by 8; `err` and `dma_err` for the long packet "
        "which is not stored; data of the OUT and IN packets match | Directed, protocol checker | CFG-CAM-HOST |")

setline("|  ASM-020 | Assumption",
        "|  ASM-020 | Assumption | The scatter-gather descriptor is two 32-bit words (address, length and control with "
        "write-back status) as defined in section 9 and describes one packet (DEC-013); the format is proposed by the "
        "author and is not the format of any reference SoC. | DMA engine and driver | Accepted 2026-11-20: author "
        "decision under the goal of finishing the specification and writing the RTL as proposed; revised 2026-11-21 to "
        "one descriptor per packet; the user may revise it | spec owner | 2026-11-20  |")

# state table rows and the operation line
for i, l in enumerate(lines):
    if l.startswith("| `ENUM_ST_DM_DESC_WB`"):
        lines[i] = l.replace("advances to the next descriptor or ends | status written (to IDLE) | o_axim_awvalid, interrupt when ioc, last or error",
                             "adds 8 to the descriptor pointer | status written (to IDLE) | o_axim_awvalid, dma_err on an overflow")
    if l.startswith("| OP-021 |"):
        lines[i] = l.replace("| `done` flags, interrupt on `ioc`, last or error | One descriptor after another |",
                             "| `done`, `err`, `short` flags and the bytes not transferred; pointer moved by 8 | One descriptor per packet |")

after("| DEC-012 | Decision",
      "| DEC-013 | Decision | Scatter-gather (`m_usb2_dma`, `PARA_USB2_SG_EN` = 1 and `u2_hsts.sg_mode` = 1): one 8-byte "
      "descriptor per USB packet in both directions, because the receive drain serves the packet events of all "
      "endpoints in order and keeps no per-endpoint descriptor state. The receive drain reads the descriptor (AXI "
      "read, two beats on 32 bit and one beat on 64 bit), writes the packet to the buffer, then writes word 1 back "
      "(single beat, lane of word 1) and moves the pointer; the transmit fill does the same around the packet it "
      "reads. Both engines share the AXI channels only for the descriptors: an engine starts a packet only when the "
      "other holds neither channel, the transmit fill wins a tie, and a transmit write-back waits for the receive "
      "packet in progress. Bytes not transferred, `done`, `err` and `short` are written back; `last` and `ioc` are "
      "kept as written and not interpreted, so interrupts stay those of the endpoint or channel; `sg_mode` changes "
      "only while the DMA is idle. | Per-packet descriptors cost one extra AXI read and one write per packet; a "
      "list that spans many packets of one endpoint without software work needs the endpoint to be re-armed per "
      "transfer | Decided 2026-11-21 | spec owner | 2026-11-21 |")
after("| DEC-013 | Decision",
      "| DEC-014 | Decision | Command bits in the CLK-PHY shadow words (`m_usb2_xreg`): the bits that the engine consumes "
      "(the clear mask of the hardware-clear fields such as `ep_en`, `clr_nak`, `set_d0`, `ep_dis` and the port and "
      "channel commands) also leave the shadow word in CLK-PHY, so a second write of the same command gives a new "
      "edge for the engine; before this change the shadow kept the bit and a repeated command was not seen. A "
      "command written in the cycle of a clear wins. | Found with the scatter-gather test that re-arms an endpoint; "
      "every earlier test armed each endpoint once | Decided 2026-11-21 | spec owner | 2026-11-21 |")
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('ok')
