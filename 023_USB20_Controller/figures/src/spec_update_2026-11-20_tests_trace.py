import os, re
ROOT = r"C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\023_USB20_Controller"
H = ROOT + r"\VLSIT_USB20_CONTROLLER_HDS.md"
t = open(H, encoding="utf-8").read()

# ---- tests
hdr = "| Test ID | Requirements | Scenario / stimulus"
a = t.index(hdr)
b = t.index("\n\n", a)
rows = t[a:b].split("\n")
tests = []
for r in rows[2:]:
    c = [x.strip() for x in r.strip().strip("|").split("|")]
    tests.append(c)
new = [
    ["TEST-030", "REQ-CLK-003, REQ-REG-002, REQ-REG-003", "Bursts of CSR writes longer than xq_free, hardware updates of xsize racing software writes, soft reset with entries in flight, random CLK-PHY and CLK-BUS ratios", "Order preserved, overflow flagged by xq_ovf, stale updates dropped, no torn value read", "Directed, random, formal, CDC analysis", "all configurations"],
    ["TEST-031", "REQ-IF-011, REQ-IF-013, REQ-FUNC-041", "ULPI low power entry, clock stop, wake by stp, resume detection by the wake detector, ID bit and OTG Control writes, DrvVbus clear after over-current", "Sequences of REF-007 3.9.2 and 3.9.3 hold; role follows the ID bit", "Directed with PHY model", "CFG-FC-DEV, CFG-DUAL-FULL"],
    ["TEST-032", "REQ-IF-012", "XcvrSelect, TermSelect, OpMode and pull-down values at every bus state of the table of section 6.3, including chirp and test modes", "Values equal the table and change only while idle", "Protocol checker, directed", "CFG-CAM-HOST, CFG-MIN"],
    ["TEST-033", "REQ-FUNC-038, REQ-FUNC-039", "Split transactions with interrupt IN, isochronous IN and bulk OUT through a hub model with NYET, NAK, error and microframe Y6 cases", "Start-split and complete-split microframes as in REF-001 11.18.4; three-strike retry", "Directed", "CFG-CAM-HOST"],
    ["TEST-034", "REQ-FUNC-037", "Host SOF stream across selective suspend and L1 with the timer kept running", "SOF phase equal before and after", "Directed with timing checker", "CFG-DUAL-FULL"],
    ["TEST-035", "REQ-FUNC-040, REQ-IF-014", "Single-bit RAM faults injected on read of IN and OUT packets; DMA buffers and descriptors inside, on the edge of and outside the window", "ram_par flag, packet aborted, no wrong data sent; transfers outside the window stopped before the AXI access", "Fault injection, directed", "CFG-CAM-HOST, CFG-DUAL-FULL"],
    ["TEST-036", "REQ-PARAM-003, REQ-PARAM-004, REQ-VER-002", "Elaborate every configuration, derive the bank counts, reject too-small FIFO depths; run the reset and suspend tests with TSCALE = 256 and with TSCALE = 1", "Counts derived; illegal depth rejected; timings correct in both runs", "Lint, elaboration, simulation", "all configurations"],
    ["TEST-037", "REQ-VER-003", "Device role with a Linux host stack (CDC-ACM, mass storage) and host role with a Linux device (UVC, CDC-ACM) on an FPGA prototype with a USB PHY chip", "Enumeration and data transfer pass", "FPGA interoperability", "CFG-DUAL-FULL"],
]
tests += new
tab = ["| Test ID | Requirements | Scenario / stimulus | Expected result | Test type | Configuration |", "|---|---|---|---|---|---|"]
tab += ["| " + " | ".join(c) + " |" for c in tests]
t = t[:a] + "\n".join(tab) + t[b:]

# ---- trace
a3 = t.index("## 3. Requirements and traceability")
b3 = t.index("## 4. Features and configurations")
reqs = re.findall(r"^\| (REQ-[A-Z]+-\d{3}) \|", t[a3:b3], re.M)
ta = t.index("| Requirement ID | RTL module/location | Test/property")
tb = t.index("\n\n", ta)
mods = {}
for r in t[ta:tb].split("\n")[2:]:
    c = [x.strip() for x in r.strip().strip("|").split("|")]
    mods[c[0]] = c[1]
mods.update({"REQ-FUNC-037": "m_usb2_host, m_usb2_spd", "REQ-FUNC-038": "m_usb2_host", "REQ-FUNC-039": "m_usb2_host", "REQ-FUNC-040": "m_usb2_fifo",
             "REQ-FUNC-041": "m_usb2_ocp, m_usb2_phyif_ulpi", "REQ-IF-011": "m_usb2_phyif_ulpi (m_usb2_ulpilp)", "REQ-IF-012": "m_usb2_phyif_utmi, m_usb2_spd",
             "REQ-IF-013": "m_usb2_phyif_ulpi, m_usb2_spd", "REQ-IF-014": "m_usb2_dma", "REQ-CLK-003": "m_usb2_xreg", "REQ-REG-002": "m_usb2_xreg, m_vlsit_csr_usb2",
             "REQ-REG-003": "m_usb2_xreg", "REQ-PARAM-003": "m_usb2_cfgchk", "REQ-PARAM-004": "m_usb2_cfgchk", "REQ-VER-002": "m_usb2_spd", "REQ-VER-003": "verification environment"})
trows = ["| Requirement ID | RTL module/location | Test/property | Verification method / analysis | Configuration |", "|---|---|---|---|---|"]
for r in reqs:
    tt = [x for x in tests if r in [q.strip() for q in x[1].split(",")]]
    assert tt, "untested " + r
    trows.append("| %s | %s | %s | %s | %s |" % (r, mods[r], ", ".join(x[0] for x in tt), tt[0][4], tt[0][5]))
t = t[:ta] + "\n".join(trows) + t[tb:]
open(H, "w", encoding="utf-8", newline="\n").write(t)
print("tests", len(tests), "reqs", len(reqs))
