"""t_fi_ulpi_abort (cfg_dev_ulpi_axim): the PHY raises DIR during a transmit and during a register access (REQ-IF-003, ERR-010).
Expected from ULPI 1.1: a DIR rise aborts the transmit (the link stops driving and the packet is lost); the host sees no good
packet and repeats the token; the device answers again with the same data (toggle unchanged); an aborted register write is
retried until the PHY has accepted it, so the PHY mode registers end with the wanted values."""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_ulpi_abort', seed=seed)
ADDR = s.rng.randrange(1, 128)
MPS = 64
d, _ = dev_bringup(s, address=ADDR)
pin = s.rnd(MPS * 6)
arm_in(s, 2, pin, MPS, 0x4000, pkts=6, set_d0=1)
d.tog_in[2] = 0
n = 0
import sys as _s
for delay in (int(_s.argv[2]),):
    # IN token; the answer is aborted at a different point of the transmit each time
    s.token(IN, ADDR, 2)
    s.wait(delay)
    s.emit('AB')
    s.wait(60)
    s.emit('FLUSH')                                          # the truncated packet is not a packet
    s.bin('cg_ulpi.abort_tx')
    # the repeated token gets the same data again; the host acknowledges it only now
    s.token(IN, ADDR, 2)
    s.xd(DATA0 if d.tog_in[2] == 0 else DATA1, pin[n * MPS:(n + 1) * MPS], tmo=400)
    s.wait(8)
    s.hs(ACK)
    d.tog_in[2] ^= 1
    n += 1
    s.idle_bus(100); s.show('epi_xfr', 2); s.show('epi_ctl', 2)
    s.wait(40)
s.save('ops/dbg_ab.ops')
