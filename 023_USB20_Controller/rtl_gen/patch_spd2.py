import re
p = '../rtl/m_usb2_spd.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


s = s.replace("ENUM_DV_", "ENUM_ST_DV_").replace("ENUM_HP_", "ENUM_ST_HP_")
for nm in ["LPARA_LS_SE0", "LPARA_LS_J", "LPARA_LS_K", "LPARA_KIND_DATA"]:
    s, n = re.subn(r"  localparam logic \[31:0\] " + nm + r"\s*= [^\n]*\n", "", s)
    assert n == 1, nm
# the last localparam must not end with a comma
s = re.sub(r",\n\) \(", "\n) (", s, count=1)
rep("""          if (i_hostdisc & (reg_speed == 2'd0))
            w_fsm_hp_nxt_state = ENUM_ST_HP_OFF;
          else if (w_edge_psusp)
            w_fsm_hp_nxt_state = ENUM_ST_HP_SUSP;
          else if (w_edge_prst)
            w_fsm_hp_nxt_state = ENUM_ST_HP_SE0;""",
    """          casez ({(i_hostdisc & (reg_speed == 2'd0)), w_edge_psusp, w_edge_prst})
            3'b1??:  w_fsm_hp_nxt_state = ENUM_ST_HP_OFF;
            3'b01?:  w_fsm_hp_nxt_state = ENUM_ST_HP_SUSP;
            3'b001:  w_fsm_hp_nxt_state = ENUM_ST_HP_SE0;
            default: w_fsm_hp_nxt_state = ENUM_ST_HP_EN;
          endcase""")
# the test packet function: a ROM case written out, placed before the first always_ff
a = s.index("  // The 53-byte payload of the test packet")
b = s.index("  assign w_tp_byte0 = f_tp_byte(reg_tp_idx);")
s = s[:a] + s[b:]
tp = [0x00] * 9 + [0xAA] * 8 + [0xEE] * 8 + [0xFE] + [0xFF] * 11 + \
     [0x7F, 0xBF, 0xDF, 0xEF, 0xF7, 0xFB, 0xFD, 0xFC, 0x7E, 0xBF, 0xDF, 0xEF, 0xF7, 0xFB, 0xFD, 0x7E]
assert len(tp) == 53, len(tp)
lines = []
for i, v in enumerate(tp):
    lines.append("      6'd%d: w_b = 8'h%02X;" % (i, v))
func = """  // The 53-byte payload of the test packet (REF-001 7.1.20): nine 00, eight AA, eight EE, FE, eleven
  // FF and the 7F, BF, DF, EF, F7, FB, FD, FC, 7E, BF, DF, EF, F7, FB, FD, 7E tail.
  function automatic logic [7:0] f_tp_byte (input logic [5:0] i_idx);
    logic [7:0] w_b;
    w_b = 8'h00;
    case (i_idx)
""" + "\n".join(lines) + """
      default: w_b = 8'h00;
    endcase
    return w_b;
  endfunction

"""
rep("  // Part 1, sequential: the states of the two sides.", func + "  // Part 1, sequential: the states of the two sides.")
open(p, 'w').write(s)
print('ok')
