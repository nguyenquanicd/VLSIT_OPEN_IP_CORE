import json
import os

here = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(here, 'dsig_diagram_spec.json')))
pos = {'U_CSR': (0, 0), 'U_CTL': (0, 1), 'U_KEY': (0, 2),
       'U_AXI': (1, 0), 'U_BUF': (1, 1), 'U_EC': (1, 2),
       'U_RNG': (2, 0), 'U_HARB': (2, 1), 'U_LAT': (2, 2),
       'U_HSEQ': (3, 1), 'U_HBS': (3, 2)}
for b in d['blocks']:
    b['row'], b['col'] = pos[b['key']]
    b['width'] = 240 if b['key'] in ('U_HARB', 'U_HSEQ') else 220


def c(i, s, ss, dd, ds):
    return {'id': i, 'src': s, 'src_side': ss, 'dst': dd, 'dst_side': ds}


d['connectors'] = [
    c('CMD', 'U_CSR', 'R', 'U_CTL', 'L'), c('KREG', 'U_CSR', 'B', 'U_KEY', 'L'),
    c('WIN', 'U_CSR', 'B', 'U_BUF', 'T'), c('BUFW', 'U_AXI', 'R', 'U_BUF', 'L'),
    c('ECRUN', 'U_CTL', 'B', 'U_EC', 'T'), c('B2EC', 'U_BUF', 'R', 'U_EC', 'L'),
    c('K2EC', 'U_KEY', 'B', 'U_EC', 'T'), c('R2EC', 'U_RNG', 'T', 'U_EC', 'B'),
    c('H1', 'U_EC', 'B', 'U_HARB', 'R'), c('H4', 'U_RNG', 'R', 'U_HARB', 'L'),
    c('H2', 'U_LAT', 'L', 'U_HARB', 'R'), c('H5', 'U_HARB', 'B', 'U_HSEQ', 'T'),
    c('H3', 'U_HBS', 'L', 'U_HSEQ', 'R'),
]
d['externals'] = [
    {'id': 'APB', 'block': 'U_CSR', 'side': 'L', 'dir': 'in', 'pos': 0, 'text': ['APB', 'i_apb_*, o_apb_*']},
    {'id': 'AXI', 'block': 'U_AXI', 'side': 'L', 'dir': 'in', 'pos': 0, 'text': ['AXI', 'i_axi_*, o_axi_*']},
    {'id': 'DMA', 'block': 'U_AXI', 'side': 'B', 'dir': 'out', 'pos': 0, 'text': ['DMA', 'o_dma_*, i_dma_*']},
    {'id': 'KEYIF', 'block': 'U_KEY', 'side': 'R', 'dir': 'in', 'pos': 0, 'text': ['KEYIF', 'o_key_*, i_key_*']},
    {'id': 'ENT', 'block': 'U_RNG', 'side': 'L', 'dir': 'in', 'pos': 0, 'text': ['ENT', 'o_ent_req, i_ent_*']},
    {'id': 'IRQ', 'block': 'U_CTL', 'side': 'T', 'dir': 'out', 'pos': 0, 'text': ['IRQ', 'o_irq, o_alarm']},
    {'id': 'CRCLK', 'block': 'U_HSEQ', 'side': 'L', 'dir': 'in', 'pos': 0, 'text': ['CRCLK', 'i_clk_*, i_rst_n_*']},
]
d['nets'] = [{'entry': 'CRCLK', 'sinks': [
    {'id': 'CK1', 'block': 'U_HARB', 'side': 'B', 'pos': 1},
    {'id': 'CK2', 'block': 'U_HBS', 'side': 'B', 'pos': 0},
    {'id': 'CK3', 'block': 'U_LAT', 'side': 'B', 'pos': 0}]}]


def itf(i, name, cat, active, sig):
    return {'id': i, 'name': name, 'category': cat, 'active': active, 'signals': sig}


d['interfaces'] = [
    itf('APB', 'APB4 CSR port', 'bus', 'external -> TOP', 'external -> TOP: i_apb_psel, i_apb_penable, i_apb_pwrite, i_apb_paddr, i_apb_pwdata, i_apb_pstrb, i_apb_pprot; TOP -> external: o_apb_pready, o_apb_pslverr, o_apb_prdata'),
    itf('AXI', 'AXI4 subordinate data port', 'bus', 'external -> TOP', 'external -> TOP: i_axi_awvalid, i_axi_awid, i_axi_awaddr, i_axi_awlen, i_axi_awsize, i_axi_awburst, i_axi_wvalid, i_axi_wdata, i_axi_wstrb, i_axi_wlast, i_axi_bready, i_axi_arvalid, i_axi_arid, i_axi_araddr, i_axi_arlen, i_axi_arsize, i_axi_arburst, i_axi_rready; TOP -> external: o_axi_awready, o_axi_wready, o_axi_bvalid, o_axi_bid, o_axi_bresp, o_axi_arready, o_axi_rvalid, o_axi_rid, o_axi_rdata, o_axi_rresp, o_axi_rlast'),
    itf('DMA', 'DMA request and acknowledge', 'handshake', 'TOP -> external', 'TOP -> external: o_dma_in_req, o_dma_out_req; external -> TOP: i_dma_in_ack, i_dma_out_ack'),
    itf('KEYIF', 'Private-key input', 'handshake', 'TOP -> external', 'TOP -> external: o_key_req, o_key_idx; external -> TOP: i_key_valid, i_key_data'),
    itf('ENT', 'Entropy input', 'handshake', 'TOP -> external', 'TOP -> external: o_ent_req; external -> TOP: i_ent_valid, i_ent_data'),
    itf('IRQ', 'Interrupt and alarm', 'custom', 'TOP -> external', 'TOP -> external: o_irq, o_alarm'),
    itf('CRCLK', 'Clock and reset', 'custom', 'SoC -> TOP', 'i_clk_core, i_rst_n_core, i_clk_apb, i_rst_n_apb'),
    itf('CMD', 'Command and status', 'custom', 'u_csr -> u_ctl', 'u_csr -> u_ctl: command and configuration fields; u_ctl -> u_csr: status, events'),
    itf('KREG', 'Key registers', 'custom', 'u_csr -> u_key', 'u_csr -> u_key: key words; u_key -> u_csr: hardware clear'),
    itf('WIN', 'Data window', 'custom', 'u_csr -> u_buf', 'u_csr -> u_buf: window read and write events; u_buf -> u_csr: read data'),
    itf('BUFW', 'Buffer access from AXI4', 'custom', 'u_axi -> u_buf', 'u_axi <-> u_buf: address, data, strobes, response'),
    itf('ECRUN', 'Engine start and result', 'custom', 'u_ctl -> engines', 'u_ctl -> u_ec, u_lat, u_hbs: start, parameters; engines -> u_ctl: done, status'),
    itf('B2EC', 'Buffer access of the engines', 'custom', 'u_ec <-> u_buf', 'u_ec <-> u_buf: read address, read data, result write'),
    itf('K2EC', 'Key to engines', 'custom', 'u_key -> u_ec', 'u_key -> u_ec, u_lat: key words'),
    itf('R2EC', 'Random bytes to engines', 'custom', 'u_rng -> u_ec', 'u_rng -> u_ec, u_lat: random bytes, valid'),
    itf('H1', 'Hash request from the elliptic-curve engine', 'custom', 'u_ec -> u_harb', 'u_ec <-> u_harb: request, data, digest'),
    itf('H2', 'Hash request from the lattice engine', 'custom', 'u_lat -> u_harb', 'u_lat <-> u_harb: request, data, squeeze'),
    itf('H3', 'Hash request from the hash-based engine', 'custom', 'u_hbs -> u_hseq', 'u_hbs <-> u_harb: request, data, digest'),
    itf('H4', 'Hash request from the random block', 'custom', 'u_rng -> u_harb', 'u_rng <-> u_harb: request, data, digest'),
    itf('H5', 'Granted stream to the sequencer', 'custom', 'u_harb -> u_hseq', 'u_harb <-> u_hseq: stream data, last, digest'),
]
d['frame_interfaces'] = ['APB', 'AXI', 'DMA', 'KEYIF', 'ENT', 'IRQ', 'CRCLK']
d['legend_note'] = 'The enclosing frame is the top module; blocks inside are its instances. The hash engine m_vlsit_sha_eng and the padder m_vlsit_sha_pad are inside u_hseq.'
json.dump(d, open(os.path.join(here, 'dsig_diagram_spec.json'), 'w'), indent=1)
print('ok')
