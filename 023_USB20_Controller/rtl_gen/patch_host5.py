p = '../rtl/m_usb2_host.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80])
    s = s.replace(a, b)


rep("  logic                                     reg_lpm_seen;\n",
    "  logic                                     reg_lpm_seen;\n  logic                                     reg_lpm_pend;\n")
rep("  assign w_lpm_start = i_hport[8] & ~reg_lpm_seen & i_host_act & ~reg_sof_pend;",
    "  assign w_lpm_start = reg_lpm_pend & i_host_act & ~reg_sof_pend;")
rep("      reg_lpm_seen <= 1'b0;\n", "      reg_lpm_seen <= 1'b0;\n      reg_lpm_pend <= 1'b0;\n")
rep("      reg_lpm_seen <= i_hport[8];\n",
    "      reg_lpm_seen <= i_hport[8];\n      reg_lpm_pend <= (reg_lpm_pend | (i_hport[8] & ~reg_lpm_seen)) & ~w_lpm_start;\n")
open(p, 'w').write(s)
print('ok')
