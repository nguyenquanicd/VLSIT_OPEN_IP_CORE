p = '../VLSIT_USB20_CONTROLLER_HDS.md'
lines = open(p, encoding='utf-8').read().split('\n')


def after(prefix, new):
    for i, l in enumerate(lines):
        if l.startswith(prefix):
            lines.insert(i + 1, new)
            return
    raise AssertionError(prefix)


def setline(prefix, new):
    n = 0
    for i, l in enumerate(lines):
        if l.startswith(prefix):
            lines[i] = new
            n += 1
    assert n == 1, (prefix, n)


rows = [
    ("DEC-015", "Host split transactions (`m_usb2_host`, `PARA_USB2_SPLIT_EN`): a channel with `split_en` sends a SPLIT "
     "token (hub address, port, SC, S, E, ET, CRC5) before its IN or OUT token. A start-split OUT carries the data and "
     "the ACK of the hub moves the channel to its complete phase; a start-split IN is answered by an ACK handshake; "
     "the complete phase of an OUT sends no data, reads nothing from the FIFO and needs no queue data to be "
     "scheduled; the complete phase of an IN receives the data. A NYET answer to a complete-split (OUT or IN) delays "
     "the retry to the next tick. | Verified in `tb_host_split` (start and complete split of an OUT and an IN "
     "transfer, token fields, NYET then ACK or DATA); the first version could not send a complete-split of an OUT and "
     "counted the ACK handshake of a start-split IN as an error | Decided 2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-016", "Host LPM request (`u2_hport.lpm_req`): the rising edge of the request bit is kept as a pending flag "
     "until the host handler is idle and not sending a SOF; the handler then sends the EXT token and the LPM token "
     "(hird, remote-wake and address from the register) and waits for the answer. An ACK moves the port to the L1 "
     "suspend state (speed engine) and every answer, including NYET, STALL and a timeout, raises the `lpm` event; the "
     "bit is cleared by hardware when the transaction starts. | Verified in `tb_host_feat` and `tb_host16` (the "
     "pending flag was added because a request that arrived while the handler was busy was lost) | Decided "
     "2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-017", "High-bandwidth isochronous IN endpoints (`m_usb2_dev`): `u2_epi_ctl.mult` (1 to 3, 0 counts as 1) "
     "limits the packets per microframe; a counter per endpoint is cleared at every SOF and counts the committed "
     "packets; the PID of a data packet is DATA2 when three packets remain, DATA1 when two remain and DATA0 for the "
     "last one; an IN token beyond `mult` packets in the microframe is answered like an isochronous endpoint "
     "without data (zero-length DATA0 and the iso event). | Verified in `tb_dev_hbiso` | Decided 2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-018", "Host polling flags (`m_usb2_host`): `poll_miss` is set when a periodic channel was due at the last "
     "tick and has not been served; `frm_ovr` when a due periodic channel did not fit into the time left of the "
     "microframe; `babble` when an IN data packet is longer than the maximum packet size (the transaction is an error "
     "and the channel halts); `iso_inc` for an error on an isochronous transaction. | Verified in `tb_host_feat` "
     "only for the normal path; the four flags are not forced by a directed test | Decided 2026-11-21 | spec owner | "
     "2026-11-21 |"),
    ("DEC-019", "Test_SE0_NAK (`m_usb2_spd`, `m_usb2_dev`): in test mode 3 the speed engine keeps the device active "
     "and `o_test_nak` makes the device answer NAK to every IN token. | Verified in `tb_dev_feat` (test mode 3 "
     "path) | Decided 2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-020", "Transmitter watchdog (`m_usb2_lnktx`): when the payload source gives no byte for 15 cycles in the "
     "payload state the packet is aborted, so a source that disappears cannot hang the link. | Found in a simulation "
     "where the FIFO read was cancelled | Decided 2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-021", "CSR names: fields and registers whose names carry a reset or clock token were renamed because the "
     "naming rules NAM-TBL and NAM-08 conflict (`swrst`, `prst`, `rstbusy`, `phyclk_ok`, `busrst`); the workbook, the "
     "generator input and the specification text use the new names. | The generated CSR files have no rule-check "
     "error after the change | Decided 2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-022", "ULPI low-power wake request (`m_usb2_ulpilp`): the request is a level from the bus-side CSR (remote "
     "wake of a device: `u2_dctrl.rmt_wake` with `rmt_wake_en`; resume of a host port: `u2_hport.port_res`), because "
     "CLK-PHY may be stopped and the speed engine cannot run; one wake handshake is made for each low-power period, so "
     "a request that stays set until the speed engine clears it cannot start a second stp. Before this change the "
     "request was a CLK-PHY pulse of the speed engine, which cannot fire while the PHY clock is stopped and crossed "
     "into CLK-BUS without a synchronizer. | Verified for the host in `tb_host_ulpi` (SuspendM written to 0, clock "
     "stopped, stp held until dir rose and fell, port resumed, SuspendM written back to 1); the device remote-wake "
     "path through the same logic is not simulated | Decided 2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-023", "PHY register access (`u2_phy_acc`): the access direction is passed to the ULPI adapter as written in "
     "the register (`rd_wr` = 1 is a write); the first integration inverted it, so a CSR write ran a read command on the "
     "ULPI bus. | Found with the ULPI host test that writes a PHY scratch register, reads it back and reads the vendor "
     "ID | Decided 2026-11-21 | spec owner | 2026-11-21 |"),
    ("DEC-024", "ULPI register read data (`m_usb2_phyif_ulpi`): the data byte of a register read (dir high, nxt low, "
     "in the state that waits for it) is not decoded as an RX CMD; before this change the register value changed the "
     "line state, the VBUS state and RxActive of the link (a read of a register whose low bits are 00 looked like "
     "SE0 and disconnected the host port). | Found with the ULPI host test that reads PHY registers | Decided "
     "2026-11-21 | spec owner | 2026-11-21 |"),
]
prev = "| DEC-014 | Decision"
for k, t in rows:
    after(prev, "| %s | Decision | %s" % (k, t))
    prev = "| %s | Decision" % k
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('ok')
