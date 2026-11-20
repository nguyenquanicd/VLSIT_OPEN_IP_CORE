"""Writes the block diagram spec JSON of m_usb2_core for the USB 2.0 controller."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ports

OUT = sys.argv[1]


def names(prefixes, direction):
    return ", ".join(r[0] for r in ports.rows if r[1] == direction and any(r[0].startswith(p) for p in prefixes))

blocks = [
 ("phyif", "u_phyif", "m_usb2_phyif_*", 0, 0, "PHY interface. Adapts the UTMI+ or ULPI pins of the PHY to one internal byte stream and mode control.", "Section 14.2, 5.1"),
 ("lnk", "u_lnk", "m_usb2_lnk", 0, 1, "USB link. Assembles and disassembles packets, checks PID and CRC, and times the bus turn-around.", "Section 14.2, 5.1"),
 ("dev", "u_dev", "m_usb2_dev", 0, 2, "Device engine. Matches address and endpoint, keeps the data toggle and chooses the handshake.", "Section 14.2, 5.1"),
 ("fifo", "u_fifo", "m_usb2_fifo", 0, 3, "FIFO manager. Owns the shared RAM, divides it into regions and arbitrates the packet and bus ports.", "Section 14.2, 5.1"),
 ("spd", "u_spd", "m_usb2_spd", 1, 0, "Speed and power controller. Runs reset, chirp, suspend, resume, link power management, test modes and the role choice.", "Section 14.2, 5.1"),
 ("host", "u_host", "m_usb2_host", 1, 1, "Host engine. Schedules channels, sends frame markers and runs the host transactions and split phases.", "Section 14.2, 5.1"),
 ("cdc", "u_cdc", "m_usb2_cdc_*", 1, 3, "Clock crossing. Moves levels, event pulses and the FIFO bus port between the two clock domains.", "Section 14.2, 7.2"),
 ("rst", "u_rst", "m_usb2_rst", 2, 0, "Reset controller. Synchronizes the release of both resets and runs the soft-reset sequence.", "Section 14.2, 7.3"),
 ("csr", "u_csr", "m_vlsit_csr_usb2", 2, 1, "Register block. Generated bus-accessible control and status registers.", "Section 14.2, 11"),
 ("irq", "u_irq", "m_usb2_irq", 2, 2, "Interrupt block. Collects event flags and drives the interrupt output.", "Section 14.2, 6.4"),
 ("dma", "u_dma", "m_usb2_dma", 2, 3, "Data mover. Moves payload between memory and the FIFO regions, or serves window accesses and DMA requests.", "Section 14.2, 5.1"),
]

spec = {
 "page_name": "BLOCK_DIAGRAM", "out_name": "m_usb2_top_block_diagram.drawio", "table_suffix": "",
 "layout": {"gap_h": 120, "gap_v": 110, "margin": 40, "block_h": 60},
 "top": {"frame_label": ["TOP", "(m_usb2_core)"], "block_label": ["TOP", "(m_usb2_core)"],
         "block_row": ["TOP (m_usb2_core)", "Structural top of the USB 2.0 controller.", "Section 14.2"]},
 "frame_row": ["TOP (m_usb2_core) frame", "Structural top of the USB 2.0 controller. It instantiates the blocks below and holds no logic of its own. The four wrappers add the fixed port profile of the PHY and data interfaces.", "Section 14.2"],
 "frame_interfaces": ["PHY", "AXI", "APB", "INT", "CKPHY", "CKBUS"],
 "blocks": [], "connectors": [], "externals": [], "nets": [], "interfaces": []}

for key, inst, mod, r, c, fn, src in blocks:
    spec["blocks"].append({"key": key, "label": [inst, "(%s)" % mod], "width": [160, 180, 180, 180][c], "row": r, "col": c,
                           "row_name": "%s (%s)" % (inst, mod), "function": fn, "source": src})

# internal connectors (each one interface)
conn = [
 ("BYTE", "phyif", "R", "lnk", "L"),
 ("DEVP", "lnk", "R", "dev", "L"),
 ("FPKT", "dev", "R", "fifo", "L"),
 ("HOSTP", "lnk", "B", "host", "T"),
 ("MODE", "spd", "T", "phyif", "B"),
 ("FBUS", "fifo", "B", "cdc", "T"),
 ("XDMA", "cdc", "B", "dma", "T"),
 ("RCTL", "rst", "R", "csr", "L"),
 ("EVT", "irq", "L", "csr", "R"),
]
for i, s, ss, d, ds in conn:
    spec["connectors"].append({"id": i, "src": s, "src_side": ss, "dst": d, "dst_side": ds})

ext = [
 ("PHY", "phyif", "L", "in", 0, ["PHY", "UTMI+ or ULPI"]),
 ("AXI", "dma", "R", "out", 0, ["AXI", "AXI4, DMA req"]),
 ("APB", "csr", "B", "in", -50, ["APB", "APB4 slave"]),
 ("INT", "irq", "B", "out", 0, ["INT", "o_int_usb"]),
 ("CKPHY", "lnk", "T", "in", 0, ["CKPHY", "i_clk_phy, i_rst_n_phy"]),
 ("CKBUS", "rst", "B", "in", 0, ["CKBUS", "i_clk_bus, i_rst_n_bus"]),
]
for i, b, s, d, p, t in ext:
    spec["externals"].append({"id": i, "block": b, "side": s, "dir": d, "pos": p, "text": t})

IF = {
 "PHY": ("PHY interface (UTMI+ or ULPI) and VBUS switch pins", "standard protocol (UTMI+ 1.0 or ULPI 1.1)", "PHY <-> TOP", "TOP -> PHY: " + names(("o_utmi_", "o_ulpi_", "o_phy_", "o_vbus_"), "Output") + "; PHY -> TOP: " + names(("i_utmi_", "i_ulpi_", "i_ovrcur_"), "Input")),
 "AXI": ("Data interface (CLK-BUS)", "standard protocol (AXI4 profile) and custom DMA handshake", "TOP <-> SoC", "TOP -> SoC: " + names(("o_axim_", "o_axis_", "o_dma_"), "Output") + "; SoC -> TOP: " + names(("i_axim_", "i_axis_", "i_dma_"), "Input")),
 "APB": ("Register interface (CLK-BUS)", "standard protocol (APB4)", "SoC -> TOP", "SoC -> TOP: " + names(("i_apb_", "i_protect_en", "i_slverr_en"), "Input") + "; TOP -> SoC: " + names(("o_apb_",), "Output")),
 "INT": ("Interrupt output", "custom level", "TOP -> SoC", "TOP -> SoC: o_int_usb"),
 "CKPHY": ("Clock and reset of the PHY domain", "custom", "PHY or SoC -> TOP", "i_clk_phy, i_rst_n_phy"),
 "CKBUS": ("Clock and reset of the bus domain", "custom", "SoC -> TOP", "i_clk_bus, i_rst_n_bus"),
 "BYTE": ("Byte stream and line state", "custom", "u_phyif <-> u_lnk", "byte data, valid, ready, line state"),
 "DEVP": ("Device packet interface", "custom", "u_lnk <-> u_dev", "packet type, fields, data bytes, handshake request"),
 "FPKT": ("FIFO packet port", "custom", "u_dev <-> u_fifo", "word address, data, read and write strobes, status"),
 "HOSTP": ("Host packet interface", "custom", "u_lnk <-> u_host", "packet type, fields, data bytes, handshake request"),
 "MODE": ("Mode and speed control", "custom", "u_spd -> u_phyif", "OpMode, XcvrSelect, TermSelect, suspend, chirp"),
 "FBUS": ("FIFO bus port", "custom", "u_fifo <-> u_cdc", "request, address, write data, read data"),
 "XDMA": ("DMA or window port", "custom", "u_cdc <-> u_dma", "request, address, data in the bus clock"),
 "RCTL": ("Reset control", "custom", "u_rst -> u_csr", "soft-reset request and completion"),
 "EVT": ("Interrupt status", "custom", "u_irq <-> u_csr", "event flags, masks, injection"),
}
for k, (n, cat, act, sig) in IF.items():
    spec["interfaces"].append({"id": k, "name": n, "category": cat, "active": act, "signals": sig})

# clock and reset nets: PHY clock to lnk, host, dev, fifo; bus clock to csr, irq, dma, cdc
spec["nets"] = [
 {"entry": "CKPHY", "sinks": [{"id": "CP1", "block": "phyif", "side": "T", "pos": 0}, {"id": "CP2", "block": "dev", "side": "T", "pos": 0},
                              {"id": "CP3", "block": "fifo", "side": "R", "pos": 0}]},
 {"entry": "CKBUS", "sinks": [{"id": "CB1", "block": "csr", "side": "B", "pos": 50}, {"id": "CB2", "block": "dma", "side": "B", "pos": 0}]},
]
spec["legend_note"] = "The enclosing frame is the top module; blocks inside are its instances."
json.dump(spec, open(OUT, "w"), indent=1)
print("wrote", OUT)
