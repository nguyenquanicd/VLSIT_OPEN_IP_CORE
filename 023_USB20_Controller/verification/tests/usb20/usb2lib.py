"""Scenario library of the USB 2.0 controller tests (R-276). AI-generated candidate (R-117).

A scenario is a list of operations for the generic harnesses (verification/env/tb/tb_usb2_*.sv). Stimulus and expected values are
derived here from the specification (register map of the CSR description, protocol rules of USB 2.0 as cited by the
REQ-FUNC requirements); nothing is read from RTL bodies. Deterministic for a fixed seed.

Checkpoint catalogue of the shared bus reset (op CHK, R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DBR-CHIRP | REQ-FUNC-013, 024; section 6.3 | device attached, the PHY shows SE0 (bus reset) | full-speed idle row first, then TXValid and the chirp row (HS transceiver, FS termination, OpMode 10b) before and during the chirp; chirp K of 1.0 to 7.0 ms with 00 bytes | TB WP, XP, XC on the mode pins and the transmit stream | 200 us to the chirp, 8 ms for its end | wrong mode row, no chirp or a chirp outside 1.0 to 7.0 ms
  DBR-HS | REQ-FUNC-013 | host chirp K-J-K-J-K-J, then SE0 | high-speed row (HS transceiver, no FS termination, OpMode 00b) | TB WP on the mode pins | 500 us after the sixth chirp | the device stays in full speed or selects a wrong row
  DBR-FS | REQ-FUNC-013 | no valid host chirp within 2.5 ms | the device stays in the full-speed row | TB XP on the mode pins | at 2.6 ms | the device switches to high speed without the handshake
"""
import json
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
REGS = json.load(open(os.path.join(HERE, '..', '..', '..', 'spec', 'csr', 'regs_usb2.json')))['registers']   # spec/csr of the IP
REG = {r['name'][3:]: r for r in REGS}                      # name without the u2_ prefix

OUT, IN, SOF, SETUP = 0x1, 0x9, 0x5, 0xD
DATA0, DATA1, DATA2, MDATA = 0x3, 0xB, 0x7, 0xF
ACK, NAK, STALL, NYET = 0x2, 0xA, 0xE, 0x6
PING, SPLIT, ERR, EXT = 0x4, 0x8, 0xC, 0x0
BULK, CTRL, ISO, INTR = 2, 0, 1, 3                          # endpoint type field (section 11.3)
PINS = {'vbusvalid': 0, 'iddig': 1, 'hostdisc': 2, 'ovrcur_n': 3, 'slverr_en': 4, 'protect_en': 5, 'sessend': 6, 'avalid': 7, 'bvalid': 8}


def bits(spec):
    s = spec.strip('[]')
    hi, _, lo = s.partition(':')
    hi = int(hi)
    lo = int(lo) if lo else hi
    return hi, lo


def addr(reg, idx=0):
    r = REG[reg]
    return int(r['offset'], 16) + 4 * idx


def val(reg, **fields):
    """Register value and mask from field names."""
    v = m = 0
    f = {x['name']: bits(x['bits']) for x in REG[reg]['fields']}
    for k, x in fields.items():
        hi, lo = f[k]
        w = (1 << (hi - lo + 1)) - 1
        assert 0 <= x <= w, (reg, k, x)
        v |= x << lo
        m |= w << lo
    return v, m


class Scn:
    def __init__(self, name, seed=1):
        self.name, self.ops, self.rng = name, [], random.Random(seed)
        self.note('scenario %s seed %d' % (name, seed))

    def emit(self, *items):
        self.ops.append(' '.join(format(i, 'x') if isinstance(i, int) else str(i) for i in items))

    def note(self, text):
        self.ops.append('# ' + text)

    def msg(self, text):
        self.ops.append('MSG ' + text)

    def chk(self, cid):
        """Functional checkpoint (R-286): the checks that follow, up to the next checkpoint, belong to <cid> of the header."""
        self.emit('CHK', cid)

    def bin(self, name):
        self.emit('B', name)

    # ---- CSR
    def w(self, reg, idx=0, **fields):
        v, _ = val(reg, **fields)
        self.emit('W', addr(reg, idx), v)

    def wraw(self, reg, idx, value):
        self.emit('W', addr(reg, idx), value)

    def r(self, reg, idx=0, **fields):
        v, m = val(reg, **fields)
        self.emit('R', addr(reg, idx), v, m)

    def show(self, reg, idx=0):
        self.emit('RP', addr(reg, idx))

    def poll(self, reg, idx=0, tries=400, **fields):
        v, m = val(reg, **fields)
        self.emit('P', addr(reg, idx), v, m, tries)

    def w1c(self, reg, idx=0, **fields):
        self.w(reg, idx, **fields)

    # ---- time, pins
    def idle(self, phy_cycles):
        self.emit('I', phy_cycles)

    def wait(self, phy_cycles):
        """Delay inside a transaction (the partner sends nothing, not even a keep-alive SOF)."""
        self.emit('ID', phy_cycles)

    def idle_bus(self, bus_cycles):
        self.emit('IB', bus_cycles)

    def pin(self, name, v):
        self.emit('PIN', PINS[name], v)

    def linestate(self, v):
        self.emit('LS', v)

    # ---- packets to the DUT
    def token(self, pid, a, ep, crc_flip=0):
        self.emit('TK', pid, a, ep, crc_flip)

    def data(self, pid, payload, crc_flip=0):
        self.emit('DT', pid, crc_flip, len(payload), *payload)

    def hs(self, pid):
        self.emit('HS', pid)

    def raw(self, payload, rxerr_at=0):
        self.emit('RAW', rxerr_at, len(payload), *payload)

    # ---- packets expected from the DUT
    def xh(self, pid, tmo=400):
        self.emit('XH', pid, tmo)

    def xd(self, pid, payload, tmo=2000):
        self.emit('XD', pid, tmo, len(payload), *payload)

    def xt(self, pid, a, ep, tmo=4000):
        self.emit('XT', pid, a, ep, tmo)

    def xc(self, lo, hi, value, tmo=4000):
        self.emit('XC', lo, hi, value, tmo)

    def xk(self, lo, hi, transitions, tmo=4000):
        self.emit('XK', lo, hi, transitions, tmo)

    def xp(self, group, value, mask):
        self.emit('XP', group, value, mask)

    def wp(self, group, value, mask, tmo):
        self.emit('WP', group, value, mask, tmo)

    def xs(self, hub, sc, port, spd, e, et, tmo=30000):
        self.emit('XS', hub, sc, port, spd, e, et, tmo)

    def xn(self, tmo=200):
        self.emit('XN', tmo)

    def gap(self, lo, hi):
        self.emit('GAP', lo, hi)

    def gapb(self, lo, hi):
        """Gap in CLK-PHY cycles between the end of the previous own packet and the start of the last captured packet (no packet received between)."""
        self.emit('GAPB', lo, hi)

    # ---- memory
    def mw(self, a, payload):
        for i in range(0, len(payload), 256):
            self.emit('MW', a + i, len(payload[i:i + 256]), *payload[i:i + 256])

    def mc(self, a, payload):
        for i in range(0, len(payload), 256):
            self.emit('MC', a + i, len(payload[i:i + 256]), *payload[i:i + 256])

    def rnd(self, n):
        return [self.rng.randrange(256) for _ in range(n)]

    def save(self, path):
        """Writes verification/tests/<path> (path 'ops/<name>.ops'); returns path, which the runners prefix with 'tests/'."""
        self.emit('END')
        full = os.path.join(HERE, '..', path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'w', newline='\n') as f:
            f.write('\n'.join(self.ops) + '\n')
        return path


# Response gap of a device at the UTMI+ link interface, in CLK-PHY cycles (REQ-FUNC-006: 8 to 192 high-speed bit times
# after the packet; one cycle is 8 bit times at 60 MHz and 16 bit times at 30 MHz). The harness measures from the fall
# of RXActive to the rise of TXValid; the PHY adds its own delays outside the DUT, so the link-side window used here is
# 1 cycle to 192 bit times.
W = 16 if 'w16' in __import__('sys').argv else 8        # UTMI+ width of the build (argument w16)
CLK_PHY_MHZ = 30 if W == 16 else 60


def dev_gap(utmi_w=None):
    return (1, 24) if (utmi_w or W) == 8 else (1, 12)


class DevModel:
    """Device-side protocol expectations (REQ-FUNC-001..009): address, per-endpoint data toggles."""

    def __init__(self, s, address=0):
        self.s, self.addr = s, address
        self.tog_out, self.tog_in = {}, {}

    def setup(self, ep, payload):
        """SETUP transaction: DATA0, device answers ACK and both toggles become 1 (REQ-FUNC-004)."""
        assert len(payload) == 8
        s = self.s
        s.token(SETUP, self.addr, ep)
        s.data(DATA0, payload)
        s.xh(ACK)
        s.gap(*dev_gap())
        self.tog_out[ep] = 1
        self.tog_in[ep] = 1

    def out(self, ep, payload, expect=ACK, pid=None):
        s = self.s
        t = self.tog_out.get(ep, 0)
        s.token(OUT, self.addr, ep)
        s.data(pid if pid is not None else (DATA1 if t else DATA0), payload)
        if expect is None:
            s.xn()
        else:
            s.xh(expect)
            s.gap(*dev_gap())
        if expect in (ACK, NYET) and pid is None:
            self.tog_out[ep] = t ^ 1

    def in_(self, ep, payload=None, expect=None, ack=True):
        """IN transaction: expect a data packet with the current toggle, or a handshake when expect is given."""
        s = self.s
        s.token(IN, self.addr, ep)
        if expect is not None:
            s.xh(expect)
            s.gap(*dev_gap())
            return
        t = self.tog_in.get(ep, 0)
        s.xd(DATA1 if t else DATA0, payload)
        s.gap(*dev_gap())
        if ack:
            s.hs(ACK)
            self.tog_in[ep] = t ^ 1

    def ping(self, ep, expect):
        s = self.s
        s.token(PING, self.addr, ep)
        s.xh(expect)
        s.gap(*dev_gap())


# PHY mode pins of section 6.3 as the harness packs them: {dmpd, dppd, suspend_n, termsel, xcvrsel[1:0], opmode[1:0]}
def mode(xcvr, term, opmode, pd=0):
    return (pd << 7) | (pd << 6) | (term << 4) | (xcvr << 2) | opmode


MODE_MASK = 0b11011111          # suspend_n is checked separately
TS = 1 if 'ts1' in __import__('sys').argv else (16 if 'ts16' in __import__('sys').argv else 256)   # PARA_USB2_TSCALE of the build (argument ts1 or ts16)


def us(t, tscale=None, f_mhz=None):
    """Microseconds of bus time as CLK-PHY cycles after the timer scaling of REQ-VER-002 (module variable TS)."""
    return max(1, int(t * (f_mhz or CLK_PHY_MHZ) / (tscale if tscale else TS)))


def dev_bus_reset(s, hub_chirp=True, pairs=3):
    """Bus reset with the high-speed detection handshake seen from the PHY side of a device (REQ-FUNC-013, 024;
    mode pins of section 6.3). Returns the speed the device is expected to select."""
    s.chk('DBR-CHIRP')
    s.wp(0, mode(1, 1, 0), MODE_MASK, 800)                 # attached, full-speed idle (a ULPI PHY needs a register write first)
    s.linestate(0)                                         # SE0: reset starts (T0)
    s.wp(3, 1, 1, us(200))                                 # TXValid: chirp K starts
    s.xp(0, mode(0, 1, 2), MODE_MASK)                      # the mode pins already show the chirp row when the first byte leaves (BUG-027)
    s.wp(0, mode(0, 1, 2), MODE_MASK, 800)                 # device chirp row of the table (HS transceiver, FS termination)
    s.linestate(2)                                         # the PHY reports K while the device chirps
    s.wait(200)
    s.xp(0, mode(0, 1, 2), MODE_MASK)                      # the chirp row holds during the whole chirp, not only at its start
    s.xc(us(1000), us(7000), 0x00, us(8000))               # chirp K of 1.0 to 7.0 ms, bytes of 00
    s.linestate(0)
    if hub_chirp:
        for _ in range(pairs):
            s.linestate(2)
            s.idle(us(50))
            s.linestate(1)
            s.idle(us(50))
        s.linestate(0)
        if pairs >= 3:
            s.chk('DBR-HS')
            s.wp(0, mode(0, 0, 0), MODE_MASK, us(500) + 8)     # high-speed within 500 us of K-J-K-J-K-J
            return 'hs'
    s.idle(us(2600))                                       # no valid sequence 1.0 to 2.5 ms after the chirp
    s.chk('DBR-FS')
    s.xp(0, mode(1, 1, 0), MODE_MASK)                      # stays full-speed
    s.linestate(1)
    return 'fs'
