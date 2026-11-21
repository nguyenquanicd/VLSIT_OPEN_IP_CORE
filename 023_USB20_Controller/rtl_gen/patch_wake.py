def edit(path, pairs):
    s = open(path).read()
    for a, b in pairs:
        assert s.count(a) == 1, (path, s.count(a), a[:70])
        s = s.replace(a, b)
    open(path, 'w').write(s)


edit('gen_regs.py', [("BUS_WORDS = ['ctrl', 'hport',", "BUS_WORDS = ['ctrl', 'dctrl', 'hport',")])
edit('core_body.py', [
    ("BUS_WORDS = ['ctrl', 'hport',", "BUS_WORDS = ['ctrl', 'dctrl', 'hport',"),
    ("'reg_alive', 'w_axi_err', 'w_dma_err']:", "'reg_alive', 'w_axi_err', 'w_dma_err', 'w_wake_csr']:"),
    ("    e('        .i_wake_req  (w_clr_rmt_wake),')", "    e('        .i_wake_req  (w_wake_csr),')"),
])
edit('core_body2.py', [
    ("    e(\"  assign w_pub_hsts     =",
     "    e('  // Wake request of the always-on ULPI logic from the bus-side CSR bits: the remote wake request of a device')\n"
     "    e('  // (with remote wake enabled) and the resume request of a host port.')\n"
     "    e(\"  assign w_wake_csr     = (w_bus_dctrl[8] & w_bus_dctrl[9] & ~w_role_bus) | (w_bus_hport[2] & w_role_bus);\")\n"
     "    e(\"  assign w_pub_hsts     ="),
])
print('ok')
