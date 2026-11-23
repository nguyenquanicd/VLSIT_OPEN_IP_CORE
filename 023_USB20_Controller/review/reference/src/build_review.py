"""Builds scorecard.json, findings.json, REVIEW_USB20_CONTROLLER.md and vlsit_spec_2026-11-20.md."""
import json, os, sys, hashlib
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
from findings_data import F, AREAS, SPEC

ROOT = r"C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\023_USB20_Controller"
OUT = ROOT + r"\review"
DATE = "2026-11-20"
spec_lines = open(ROOT + "\\" + SPEC, encoding="utf-8").read().split("\n")

ANCH = {"F-001": "| CDC-001 |", "F-002": "| CDC-002 |", "F-003": "- **Bandwidth check:**", "F-004": "| TBD-005 |", "F-005": "| `o_utmi_opmode` |", "F-006": "| ASM-007 |",
        "F-007": "| ASM-001 |", "F-008": "| REQ-FUNC-017 |", "F-009": "| PERF-002 |", "F-010": "| UTMI+ inputs |", "F-011": "sdc/usb2_clocks.sdc", "F-012": "| PPA-003 |",
        "F-013": "### 11.1 CSR specification source", "F-014": "A signal from a clock domain other than the register clock is synchronized", "F-015": "| REQ-FUNC-034 |",
        "F-016": "| REQ-FUNC-023 |", "F-017": "| ECC/parity and fault detection", "F-018": "### 11.4 APB access behavior", "F-019": "### 7.3 Reset domains", "F-020": "| REQ-PARAM-001 |",
        "F-021": "| PARA_USB2_FIFO_DEPTH |", "F-022": "| REQ-FUNC-015 |", "F-023": "| REQ-FUNC-025 |", "F-024": "| REQ-FUNC-022 |", "F-025": "| REF-011 |", "F-026": "### 15.1 Scope",
        "F-027": "## 20. Assumptions", "F-028": "| TEST-007 |", "F-029": "### 14.3 Synthesis", "F-030": "### 6.2 Complete port list", "F-031": "## 16. DFT", "F-032": "### 1.3 Feature summary",
        "F-033": "## 19. Requirement", "F-034": "### 1.4 Real-world"}
for f in F:
    a = ANCH[f["id"]]
    n = next((i + 1 for i, l in enumerate(spec_lines) if a in l), None)
    assert n, (f["id"], a)
    f["evidence"] = "%s:%d" % (SPEC, n)

SEV_GATE = {"Blocker": "Critical", "Major": "High", "Minor": "Medium", "Observation": "Low"}
CH = [  # (area ids, title EN, title VI, EN paragraph, VI paragraph)
 (["application_fit"], "Application fit", "Phù hợp ứng dụng",
  "The specification targets a drone flight controller that is a USB device (CDC-ACM, DFU, mass storage) and a host for a UVC camera or LTE modem, and each of the 23 features has an application row with a number (section 1.4). The excluded list is explicit. The design serves this application; the values are still the author's proposals.",
  "Spec nhắm flight controller của drone vừa là USB device (CDC-ACM, DFU, mass storage) vừa là host cho camera UVC hoặc modem LTE, và mỗi trong 23 feature có dòng ứng dụng với số đo (mục 1.4). Danh sách loại trừ rõ ràng. Thiết kế phục vụ ứng dụng này; các giá trị vẫn là đề xuất của tác giả."),
 (["features"], "Features", "Tính năng",
  "Twenty-three features (FEAT-001 to FEAT-023) map to requirements, tests and configurations. Optional features have a parameter and a stated absent or tied-off behavior.",
  "Hai mươi ba feature (FEAT-001 đến FEAT-023) ánh xạ tới yêu cầu, test và cấu hình. Feature tùy chọn có tham số và hành vi absent hoặc tied-off được nêu."),
 (["functions"], "Functions and cycle behaviour", "Chức năng và hành vi theo chu kỳ",
  "Eight FSM tables and diagrams and 37 waveforms describe the device, host, link, ULPI and DMA behavior. The chirp, reset and suspend timings match REF-001. The gaps are the ULPI low power sequence, split timing, the scheduling limits and the numeric time-out and test-mode entry.",
  "Tám bảng FSM kèm sơ đồ và 37 waveform mô tả hành vi device, host, link, ULPI và DMA. Timing chirp, reset và suspend khớp REF-001. Khoảng trống là chuỗi ULPI low power, timing split, giới hạn lập lịch, time-out bằng số và cách vào test mode."),
 (["interfaces"], "Interfaces and protocol", "Giao diện và giao thức",
  "The port table of section 6.2 gives direction, width, clock domain, signal type, reset value and sampling for every port of the four wrappers. The compliance table below checks the statements against the clauses that were read.",
  "Bảng port mục 6.2 cho hướng, độ rộng, miền clock, loại tín hiệu, giá trị reset và lấy mẫu của mọi port trong bốn wrapper. Bảng tuân thủ bên dưới đối chiếu các phát biểu với các điều khoản đã đọc."),
 (["clock_reset_cdc"], "Clock, reset and CDC", "Clock, reset và CDC",
  "Two asynchronous domains (CLK-PHY, CLK-BUS), two resets and six crossings are listed with structures. The structures fit one-bit levels, pulses and the FIFO bus port, but not the multi-bit endpoint and channel registers that make most of the CSR.",
  "Hai miền bất đồng bộ (CLK-PHY, CLK-BUS), hai reset và sáu crossing được liệt kê kèm cấu trúc. Các cấu trúc phù hợp với level một bit, pulse và cổng FIFO bus, nhưng không phù hợp với thanh ghi endpoint và channel nhiều bit chiếm phần lớn CSR."),
 (["parameters", "data_representation"], "Parameters and data", "Tham số và biểu diễn dữ liệu",
  "Fifteen parameters have defaults, ranges, dependencies and effects, and the quantity table and the descriptor format define widths and encodings. The gaps are the checking of illegal values and the FIFO size rule.",
  "Mười lăm tham số có mặc định, dải, phụ thuộc và tác động, và bảng đại lượng cùng định dạng descriptor xác định độ rộng và encoding. Khoảng trống là việc kiểm tra giá trị sai và quy tắc kích thước FIFO."),
 (["asic_feasibility"], "ASIC feasibility", "Khả thi ASIC",
  "Synthesizability: the structure follows the VLSIT rules, with one module per function and library cells for the RAM and synchronizers. Clock and reset architecture: two domains with synchronized release. CDC and RDC: see chapter 7. Timing path: not assessed in numbers because no synthesis input exists; the likely critical paths are listed in F-029.",
  "Synthesizability: cấu trúc theo rule VLSIT, mỗi module một chức năng và dùng library cell cho RAM và synchronizer. Kiến trúc clock và reset: hai miền với release đồng bộ. CDC và RDC: xem chương 7. Đường timing: chưa đánh giá bằng số vì chưa có đầu vào synthesis; các đường tới hạn có khả năng nằm ở F-029."),
 (["sdc_timing"], "SDC and timing", "SDC và timing",
  "Clocks, the asynchronous clock groups and five exceptions are tabulated with their rationale. The interface input and output delays are open and the SDC files are not delivered.",
  "Clock, nhóm clock bất đồng bộ và năm exception được lập bảng kèm lý do. Input và output delay của giao diện còn mở và file SDC chưa được giao."),
 (["area_power"], "Area and power", "Diện tích và công suất",
  "Area and power have no stated number. The proxy table below is computed in this review from the CSR workbook JSON; it is a flip-flop and storage count, not a mapped area.",
  "Diện tích và công suất không có số. Bảng proxy bên dưới được tính trong review này từ JSON của workbook CSR; đó là số flip-flop và bộ nhớ, không phải diện tích đã map."),
 (["performance"], "Performance and throughput", "Hiệu năng và thông lượng",
  "The specification quantifies the isochronous goal (24.576 MB/s), the response limit (192 bit times, 20-cycle budget), the SOF period and the over-current response. The RAM bandwidth in the 16-bit configuration and the derivation of the turnaround budget are not shown.",
  "Spec định lượng mục tiêu isochronous (24,576 MB/s), giới hạn phản hồi (192 bit time, ngân sách 20 chu kỳ), chu kỳ SOF và thời gian đáp ứng over-current. Băng thông RAM ở cấu hình 16 bit và cách suy ra ngân sách turnaround chưa được trình bày."),
 (["software_ease"], "Software and application ease", "Dễ lập trình và ứng dụng",
  "The register model (44 registers, banks, interrupt set with raw, enable, injection and status, summary registers) and the 19-step flow of section 11.2 are workable; initialization, error clearing and interrupt service are described. The model is new, so no existing driver applies.",
  "Mô hình thanh ghi (44 thanh ghi, bank, bộ ngắt raw, enable, injection, status, thanh ghi tóm tắt) và flow 19 bước ở mục 11.2 dùng được; khởi tạo, xóa lỗi và phục vụ ngắt đã mô tả. Mô hình là mới nên chưa có driver sẵn."),
 (["dft"], "DFT", "DFT",
  "Scan eligibility, the clock-gate test enable, MBIST position and ATPG exclusions are stated; the DFT ports are deferred to the SoC flow (TBD-009).",
  "Scan, test enable của clock gate, vị trí MBIST và loại trừ ATPG đã nêu; port DFT hoãn cho flow SoC (TBD-009)."),
 (["security_ras"], "Security and RAS", "An toàn và độ tin cậy",
  "Stance: untrusted USB data, CSR privilege check, no key material, no ECC, no integrity level. Error containment is by flags, time-outs, flush and DMA stop.",
  "Lập trường: dữ liệu USB không tin cậy, kiểm quyền CSR, không có khóa, không ECC, không integrity level. Cô lập lỗi bằng cờ, time-out, flush và dừng DMA."),
 (["verification_quality"], "Verification quality", "Chất lượng kiểm chứng",
  "Fifty-nine requirements are traced to 29 tests and 15 properties and covered by 4 coverage groups; no requirement lacks a test. Depth is limited: tests are grouped, there is no interoperability or time-scaling plan, and nothing has been simulated.",
  "Năm mươi chín yêu cầu được truy vết tới 29 test và 15 property và 4 nhóm coverage; không yêu cầu nào thiếu test. Độ sâu còn hạn chế: test được gộp, không có kế hoạch interoperability hay scale thời gian, và chưa có gì được mô phỏng."),
 (["documentation"], "Documentation and traceability", "Tài liệu và truy vết",
  "Identifiers are stable and the 41 open items are listed in section 20. The standards texts are unofficial copies and the open items have no owner or date.",
  "Định danh ổn định và 41 mục mở được liệt kê ở mục 20. Văn bản chuẩn là bản sao không chính thức và mục mở không có owner hay ngày."),
 (["integration_effort"], "Integration effort and bring-up", "Công sức tích hợp và bring-up",
  "The integrator must choose a wrapper, supply a PHY, a RAM macro, a pad wrapper and optionally a DMA controller, tie off several ports and tie 19 bank counts. The bring-up flow is in section 11.2.",
  "Integrator phải chọn wrapper, cấp PHY, macro RAM, pad wrapper và tùy chọn DMA controller, tie-off nhiều port và gán 19 số bank. Flow bring-up nằm ở mục 11.2."),
 (["market_position"], "Market position", "Vị thế thị trường",
  "The specification is compared with the DWC_otg databook, vendor pages and three SoC manuals. It is competitive in features for a drone application; area, power and software support cannot be compared yet.",
  "Spec được so với databook DWC_otg, trang của hãng và ba manual SoC. Về tính năng, spec cạnh tranh được cho ứng dụng drone; diện tích, công suất và hỗ trợ phần mềm chưa so được."),
]

STD = [  # requirement, standard revision clause, specification statement, verdict
 ("REQ-FUNC-002, REQ-FUNC-003", "USB 2.0 Rev 2.0 (REF-001), 8.3.1, 8.3.5.1, 8.3.5.2, Table 8-1", "PID check by complement; CRC5 residual 01100B; CRC16 residual 1000000000001101B", "compliant"),
 ("REQ-FUNC-004", "USB 2.0 Rev 2.0, 8.6.1", "SETUP data stage DATA0 with ACK, sequence bits equal afterwards", "compliant"),
 ("REQ-FUNC-006, REQ-FUNC-014", "USB 2.0 Rev 2.0, 7.1.18.1, 7.1.18.2", "8 bit times minimum, 192 maximum (HS); 2 and 6.5 or 7.5 (FS, LS)", "compliant"),
 ("REQ-FUNC-010", "USB 2.0 Rev 2.0, 8.3.3, 8.4.3", "SOF 1 ms +/- 0.0005 ms (FS), 125 us +/- 0.0625 us (HS), 11-bit frame number", "compliant"),
 ("REQ-FUNC-011, 012, 013, 024", "USB 2.0 Rev 2.0, 7.1.7.5", "Reset 50 ms, chirp 1.0 to 7.0 ms, hub chirp 40 to 60 us", "compliant"),
 ("REQ-FUNC-018, 019, 020", "USB 2.0 Rev 2.0, 7.1.7.6, 7.1.7.7", "3 ms idle, 5 ms before remote wake, 20 ms resume", "compliant"),
 ("REQ-FUNC-021", "USB 2.0 LPM ECN, 2.1, 2.2, 4.1", "EXT 0000B, SubPID 0011B, HIRD 50 us plus 75 us per step; L1 residency and exit timings not stated", "not stated (partial)"),
 ("REQ-FUNC-022", "USB 2.0 Rev 2.0, 7.1.20", "Four test modes and the test packet; entry command not stated (ASM-017)", "deviation: entry not stated"),
 ("REQ-FUNC-017", "USB 2.0 Rev 2.0, 8.4.2, 11.17 to 11.21", "SPLIT PID 1000B; scheduling and retry rules not stated", "not stated (partial)"),
 ("REQ-FUNC-015", "USB 2.0 Rev 2.0, 5.7.4", "Periodic limits of 80 % and 90 % not stated", "not stated"),
 ("REQ-FUNC-025", "USB 2.0 Rev 2.0, 8.7.2", "Time-out by turn-around time, no numbers", "not stated"),
 ("REQ-FUNC-034", "USB 2.0 Rev 2.0, 7.2.1.2.1", "Host over-current protection with a report to software", "compliant"),
 ("REQ-IF-001, REQ-IF-002", "UTMI+ Rev 1.0, 2, 2.1.1 (unofficial copy)", "Levels 0 to 3, 8 and 16 bit, LineState filtering; encodings not stated", "not stated (partial)"),
 ("REQ-IF-003, REQ-IF-004", "ULPI Rev 1.1 (unofficial copy), Tables 6 to 10 listed, text not read in depth", "TX CMD, RX CMD, register access, pipeline delays", "not stated (not verified)"),
 ("REQ-IF-005", "AMBA APB IHI 0024 Issue D, 3.1 to 3.4", "APB4 with PSTRB, PPROT, PSLVERR through the generator", "compliant"),
 ("REQ-IF-006, REQ-IF-007", "AMBA AXI IHI 0022 v1.0 text (AXI3 era); AXI4 Issue H.c not available", "INCR bursts of at most 16 beats, 4 KB rule", "unsupported (no AXI4 text)"),
]

MARKET = [  # product, source and date, facts, comparison
 ("Synopsys DWC_otg USB 2.0 HS OTG 5.00b", "Databook DWC_otg_databook.pdf, July 2024, chapter 3 (user file); retrieved 2026-11-20",
  "Role modes with HNP, SRP and non-HNP, slave, internal and external DMA, descriptor DMA, dedicated TX FIFO per IN endpoint, LPM (+1.2K gates), HSIC, ADP, battery charger, point-to-point option, up to 15 endpoints and 16 host channels", "Ours adds optional split, SG, double buffering; omits HNP, SRP, ADP, HSIC, BC and dedicated FIFOs"),
 ("Synopsys DesignWare USB 2.0 HS OTG controller", "synopsys.com/designware-ip/interface-ip/usb/usb-2-0-hs-otg.html, retrieved 2026-11-20", "Dual-role device, 480/12/1.5 Mbps, AHB, UTMI+ Level 3 PHY interface, buffer and descriptor pre-fetching, multiple power domains", "Ours is AXI4 and APB4 and has no power-domain support (section 7.4 N/A)"),
 ("Cadence USB 2.0 OTG controller", "cadence.com brochure Design IP for USB 2.0 OTG Controller, retrieved 2026-11-20", "8-bit UTMI+, host and device, AXI interfaces, scatter-gather DMA; LPM is listed for the PHY", "Similar AXI and SG offer; ours adds ULPI and 16-bit UTMI+"),
 ("TI AM335x (Mentor MUSB)", "TRM spruh73q, December 2019, section 16.0.4 (downloaded 2026-11-20)", "HS/FS device, HS/FS/LS host, 16 TX and 16 RX endpoints, 32 KB FIFO, HNP and SRP, high-bandwidth isochronous, CPPI DMA, RNDIS and CDC modes; LPM and charger detection unsupported", "Ours has LPM option and ZLP assistance; no RNDIS/CDC accelerator"),
 ("Espressif ESP32-S3 (DWC2 core)", "TRM v1.8, section 32.2, retrieved 2026-11-20", "FS and LS only, HNP and SRP, dynamic FIFO, scatter-gather, buffer DMA and slave modes, 6 extra endpoints, 8 host channels", "Ours adds high-speed and more endpoints"),
 ("Raspberry Pi RP2040", "Datasheet section 4.1.1.1, retrieved 2026-11-20", "FS device, host FS and LS, 32 endpoints, double buffering, 15 hardware-polled interrupt endpoints, 4 KB", "Ours adopts double buffering and interval polling"),
]

PROXY = [
 ("CSR control flip-flops (rw, rwi, w1c bits)", "3 802", "6 868", "regs_usb2.json; banks 9 endpoint, 8 channel, 4 DMA (default) and 16 each (maximum)"),
 ("CSR status inputs (ro bits, not flip-flops)", "291", "355", "same source"),
 ("FIFO RAM", "4 KB (1 024 x 32)", "128 KB (32 768 x 32)", "PARA_USB2_FIFO_DEPTH default and maximum"),
 ("Crossing FIFO MEM-002", "2 x 8 x 36 = 576 bits", "same", "section 10.5"),
]


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()[:16]


def table_findings(fs):
    rows = ["| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |", "|---|---|---|---|---|---|"]
    for f in fs:
        rows.append("| %s | %s | %s | %s | %s | %s |" % (f["id"], f["severity"], f["locator"].replace("|", "/"), f["en"], f["vi"], f["action"]))
    return "\n".join(rows)


def build(audit=None, gate=None):
    # scorecard
    from collections import OrderedDict
    weights = {"application_fit": 1.0, "features": 1.0, "functions": 1.5, "interfaces": 1.5, "clock_reset_cdc": 1.5, "parameters": 1.0, "data_representation": 0.5,
               "asic_feasibility": 1.5, "sdc_timing": 1.5, "area_power": 1.0, "performance": 1.5, "software_ease": 1.0, "dft": 1.0, "security_ras": 1.0,
               "verification_quality": 1.5, "documentation": 0.5, "integration_effort": 1.0, "market_position": 1.0}
    sc = {"ip": "USB 2.0 Controller", "reviewed_spec": ROOT + "\\" + SPEC, "date": DATE,
          "areas": [{"id": k, "weight": weights[k], "score": AREAS[k][0], "justification": AREAS[k][1]} for k in weights],
          "findings": [{"id": f["id"], "area": f["area"], "severity": f["severity"], "label": f["label"], "locator": f["locator"], "title": f["title"],
                        "detail": f["en"], "action": f["action"]} for f in F]}
    json.dump(sc, open(OUT + r"\scorecard.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    gf = [{"id": f["id"], "severity": SEV_GATE[f["severity"]], "verdict": "fix HAS" if f["verdict"] == "fix HAS" else "not a defect", "root_cause": f["root_cause"],
           "evidence": f["evidence"], "traced": f["traced"], "area": f["area"], "title": f["title"]} for f in F]
    json.dump({"findings": gf}, open(OUT + r"\gate_findings.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    return sc


def review_md(score_md, gate_text, audit_text):
    byarea = {}
    for f in F:
        byarea.setdefault(f["area"], []).append(f)
    out = []
    out.append("# Specification review: USB 2.0 Controller / Đánh giá đặc tả: USB 2.0 Controller\n")
    out.append("| Field / Trường | Value / Giá trị |\n|---|---|")
    out.append("| IP | USB 2.0 Controller (device, host, dual-role; UTMI+ or ULPI) |")
    out.append("| Specification reviewed | %s |" % (ROOT + "\\" + SPEC))
    out.append("| Revision and date | version 0.1 draft, 2026-11-20 |")
    out.append("| Reviewer | Claude (skill vlsit-ip-spec-review) |")
    out.append("| Review date | %s |" % DATE)
    out.append("| Verdict / Kết luận | VERDICT_PLACEHOLDER |\n")
    out.append("Precedence: rule.md overrides SKILL.md, and SKILL.md overrides the files under reference/, when they differ. / Thứ tự ưu tiên: rule.md thắng SKILL.md, SKILL.md thắng các file trong reference/ khi khác nhau.\n")
    out.append("## 1. Executive summary / Tóm tắt điều hành\n")
    out.append("**EN.** FACT: the specification (version 0.1) defines a synthesizable USB 2.0 controller with device, host and dual-role operation, UTMI+ or ULPI PHY interfaces, an APB4 register block of 44 registers, AXI4 master DMA or AXI4 slave with DMA handshake, and 23 features; 59 requirements are each traced to a test. The review finds one Blocker, ELEVEN_MAJOR Major findings, TWENTYONE_MINOR Minor findings, and Observations. The Blocker is the missing safe clock-domain crossing for the multi-bit endpoint and channel registers (F-001). The three actions that matter most are: define a held-data crossing for the CSR banks (F-001, F-002), obtain official UTMI+, ULPI and AXI4 texts and finish the ULPI low power, split and UTMI+ mode tables (F-004 to F-008), and add the RAM bandwidth, turnaround budget and PHY timing numbers (F-003, F-009, F-010).\n")
    out.append("**VI.** FACT: spec (phiên bản 0.1) định nghĩa USB 2.0 controller synthesize được với device, host và dual-role, giao diện PHY UTMI+ hoặc ULPI, khối thanh ghi APB4 gồm 44 thanh ghi, DMA AXI4 master hoặc AXI4 slave với DMA handshake, và 23 feature; 59 yêu cầu đều được truy vết tới test. Review thấy một Blocker, ELEVEN_MAJOR phát hiện Major, TWENTYONE_MINOR phát hiện Minor và các Observation. Blocker là thiếu crossing clock-domain an toàn cho thanh ghi endpoint và channel nhiều bit (F-001). Ba việc quan trọng nhất: định nghĩa crossing giữ dữ liệu cho các bank CSR (F-001, F-002), lấy bản chính thức của UTMI+, ULPI và AXI4 rồi hoàn thiện bảng ULPI low power, split và chế độ UTMI+ (F-004 đến F-008), và bổ sung số băng thông RAM, ngân sách turnaround và timing PHY (F-003, F-009, F-010).\n")
    out.append("### 1.1 Top findings / Phát hiện quan trọng nhất\n")
    top = sorted(F, key=lambda f: ["Blocker", "Major", "Minor", "Observation"].index(f["severity"]))[:5]
    out.append(table_findings(top).replace("| Statement (EN) |", "| Finding (EN) |"))
    out.append("\n## 2. Scorecard / Bảng điểm\n")
    out.append(score_md)
    out.append("\n**EN.** The two lowest scores are clock, reset and CDC (1) because of the Blocker F-001, and functions, interfaces, SDC and performance (2) because each has two or more Major findings. **VI.** Hai điểm thấp nhất là clock, reset và CDC (1) do Blocker F-001, và chức năng, giao diện, SDC và hiệu năng (2) vì mỗi mục có từ hai phát hiện Major trở lên.\n")
    n = 3
    for areas, ten, tvi, pen, pvi in CH:
        out.append("## %d. %s / %s\n" % (n, ten, tvi))
        out.append("**EN.** " + pen + "\n")
        out.append("**VI.** " + pvi + "\n")
        fs = [f for a in areas for f in byarea.get(a, [])]
        if areas[0] == "interfaces":
            out.append("Compliance table (R-005) / Bảng tuân thủ:\n")
            out.append("| Requirement | Standard, revision, clause | Specification statement | Verdict |\n|---|---|---|---|")
            for r in STD:
                out.append("| %s | %s | %s | %s |" % r)
            out.append("")
        if areas[0] == "area_power":
            out.append("Proxy table (label: proxy, no mapped area; no library or corner) / Bảng proxy:\n")
            out.append("| Item | Default counts | Maximum counts | Basis |\n|---|---|---|---|")
            for r in PROXY:
                out.append("| %s | %s | %s | %s |" % r)
            out.append("")
        if areas[0] == "market_position":
            out.append("| Product | Source and date | Facts | Comparison with this specification |\n|---|---|---|---|")
            for r in MARKET:
                out.append("| %s | %s | %s | %s |" % r)
            out.append("")
        if fs:
            out.append("**Findings**\n")
            out.append(table_findings(fs))
        else:
            out.append("No finding in this chapter. Score: %s. / Không có phát hiện trong chương này." % AREAS[areas[0]][0])
        out.append("\n**Score / Điểm:** " + ", ".join("%s = %d" % (a, AREAS[a][0]) for a in areas) + "\n")
        n += 1
    out.append("## %d. Actions / Hành động\n" % n)
    out.append("**EN.** Fix in this order: P0 items block integration, P1 items block RTL freeze. **VI.** Sửa theo thứ tự: P0 chặn tích hợp, P1 chặn đóng băng RTL.\n")
    out.append("| Priority | Action | Owner | Evidence |\n|---|---|---|---|")
    for p, a, o, e in [("P0", "Define a held-data CSR crossing and rework CDC-001 to CDC-003", "spec and RTL architect", "F-001, F-002, F-014"),
                       ("P0", "Replace unofficial UTMI+, ULPI copies, add AXI4 text, inspect pages that differ", "spec owner", "F-006, F-007, F-025"),
                       ("P0", "Specify ULPI low power, clock restart, UTMI+ mode table, ID path, split rules", "spec owner", "F-004, F-005, F-008, F-016, F-019"),
                       ("P1", "Add RAM bandwidth table, turnaround cycle budget, PHY I/O timing and the SDC files", "spec owner, SoC", "F-003, F-009, F-010, F-011, F-029"),
                       ("P1", "Add area and power proxy table and evaluate shared register banks", "spec owner", "F-012"),
                       ("P1", "Add driver plan and integration checklist", "SW lead, integrator", "F-013, F-030"),
                       ("P2", "Close the minor requirement gaps and open-item owners and dates", "spec owner", "F-020 to F-024, F-027, F-028"),
                       ("P2", "Decide RAM parity and DMA window", "product owner", "F-017, F-018")]:
        out.append("| %s | %s | %s | %s |" % (p, a, o, e))
    n += 1
    out.append("\n## %d. Evidence appendix / Phụ lục bằng chứng\n" % n)
    out.append("**EN.** Inventory of the reviewed folder (rule R-001), gate result, audit sample and the limits of the review. **VI.** Kiểm kê thư mục được review (R-001), kết quả gate, mẫu kiểm tra và giới hạn của review.\n")
    out.append("- Folder inventory: %s, the CSR workbook VLSIT_USB20_CONTROLLER_CSR.xlsx and csr/regs_usb2.json, figures/ (8 FSM, 1 block diagram, 37 waveform with sources, figures/src), research/reference_ip_log.md, review/. There is no rtl/, verification/, sanity/, sdc/ or constraints/ folder.\n" % SPEC)
    out.append("- File hashes (sha256, first 16 hex): spec %s, workbook %s, regs_usb2.json %s." % (sha(ROOT + "\\" + SPEC), sha(ROOT + r"\VLSIT_USB20_CONTROLLER_CSR.xlsx"), sha(ROOT + r"\csr\regs_usb2.json")))
    out.append("- Requirements: 59 (FUNC 36, IF 10, CLK 2, RESET 2, PARAM 2, ERR 2, REG 1, PERF 1, RTL 1, VER 1, DFT 1); tests 29; properties 15; open items 41 (ASM, DEP, TBD without owner or date). Source: review/inventory.json.")
    out.append("- Gate: %s\n" % gate_text)
    out.append("- Audit of the review: %s\n" % audit_text)
    out.append("- Not assessed: mapped area and power (no synthesis input); timing closure (no RTL or SDC); ULPI clauses in depth (the converted text was listed, not read); the 650-page USB 2.0 conversion pages that differ by more than 5 %; the RTL, because none exists; the DWC_otg databook outside chapter 3 and the SoC manuals outside their feature lists; AXI4 behavior (no AXI4 text).")
    out.append("- Depth: findings were traced in depth for %d of %d findings; the rest are grouped by root cause (rule R-022); ask to go deeper." % (sum(1 for f in F if f["traced"]), len(F)))
    out.append("- Sources: web search results for Synopsys and Cadence pages retrieved 2026-11-20; documents supplied by the user (DWC_otg databook, USB 2.0 package) and downloaded SoC manuals (soc_manuals folder).")
    return "\n".join(out) + "\n"


def dated_md(gate_text, audit_text):
    c = {k: sum(1 for f in F if SEV_GATE[f["severity"]] == k) for k in ("Critical", "High", "Medium", "Low")}
    nfix = sum(1 for f in F if f["verdict"] == "fix HAS")
    nnone = len(F) - nfix
    o = ["# Specification review of USB20_CONTROLLER - %s\n" % DATE, "## 1. Summary\n", "| Item | Value |\n|---|---|",
         "| Design | `USB20_CONTROLLER` |", "| Review | Specification review |", "| Date | %s |" % DATE, "| Findings | %d |" % len(F),
         "| Critical | %d |" % c["Critical"], "| High | %d |" % c["High"], "| Medium | %d |" % c["Medium"], "| Low | %d |" % c["Low"],
         "| Waivable | 0 |", "| Fixable | %d |" % nfix, "",
         "Gate: %s" % gate_text, "", "Audit: %s" % audit_text, "",
         "Severity mapping: Blocker is Critical, Major is High, Minor is Medium, Observation is Low. The full bilingual review is REVIEW_USB20_CONTROLLER.md.", "",
         "## 2. Findings\n",
         "Each finding has an assessment, a verdict and, when it can be fixed, the RTL change and the reason it works. The fixes are changes of the specification (HAS) that precede RTL.\n"]
    for f in F:
        o.append("### %s %s\n" % (f["id"], f["title"]))
        o.append("- Severity: `%s`" % SEV_GATE[f["severity"]])
        o.append("- Evidence: `%s`" % f["evidence"])
        o.append("- Assessment: %s" % f["en"])
        o.append("- Verdict: `%s`" % ("fix" if f["verdict"] == "fix HAS" else "none"))
        if f["verdict"] == "fix HAS":
            o.append("- Fix: %s" % f["action"])
            o.append("- Why: %s" % f["why"])
            if f["snippet"]:
                o.append("\n```systemverilog\n%s\n```" % f["snippet"])
        o.append("")
    o += ["## 3. Actions\n", "| Action | Owner | Blocks sign-off |", "|---|---|---|",
          "| Define a held-data CSR crossing (F-001, F-002) | architect | yes |",
          "| Official UTMI+, ULPI, AXI4 texts and the mode tables (F-004 to F-008) | spec owner | yes |",
          "| RAM bandwidth, turnaround budget, PHY timing and SDC files (F-003, F-009 to F-011) | spec owner, SoC | RTL freeze |",
          "| Software and integration plans (F-013, F-030) | SW lead | integration |", "",
          "## 4. Limits\n",
          "- No synthesis, simulation or RTL exists, so area, power and timing closure were not assessed.",
          "- ULPI clauses were not read in depth; AXI4 text is absent; the USB 2.0 conversion was not inspected page by page.",
          "- Findings were traced in depth for %d of %d; the others are grouped by root cause and can be traced further on request." % (sum(1 for f in F if f["traced"]), len(F))]
    return "\n".join(o) + "\n"


if __name__ == "__main__":
    sc = build()
    print("built scorecard and gate findings", len(F))
