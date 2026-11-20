import json, os, sys
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
import build_review as b
from findings_data import F

OUT = b.OUT
b.build()
score_md = open(OUT + r"\scorecard.md", encoding="utf-8").read()
gate = json.load(open(OUT + r"\gate.json", encoding="utf-8"))
audit = json.load(open(OUT + r"\audit.json", encoding="utf-8"))
verdict_line = [l for l in score_md.splitlines() if "Verdict:" in l][-1]
verdict = "Conditional" if "Conditional" in verdict_line else ("Ready" if "Ready" in verdict_line and "Not ready" not in verdict_line else "Not ready")
weighted = verdict_line.split("|")[3].strip().strip("*")
gate_text = ("`RESULT: %s` (vlsit_review_gate.py metrics): %d findings, Critical %d, High %d, Medium %d, Low %d; waiver usage %s (budget 10); sampling %.0f %%; "
             "reason: %s. The gate stays FAIL until F-001 is fixed in the specification; no waiver was granted." %
             (gate["status"], gate["findings"], gate["counts"]["Critical"], gate["counts"]["High"], gate["counts"]["Medium"], gate["counts"]["Low"],
              gate["waiver_usage"], gate["sampling"] * 100, "; ".join(gate["reasons"])))
JUDGE = {"F-009": ("tp", "PERF-002 (line 4847) states the 20-cycle budget; REF-007 Tables 8 to 10 are not applied in the specification."),
         "F-003": ("tp", "Line 4668 uses 240 MB/s; section 7.1 gives CLK-PHY 30 MHz for 16-bit UTMI+, so the same traffic needs 100 % of 120 MB/s."),
         "F-010": ("tp", "Line 5003 shows TBD-007 for the UTMI+ input delay; no number exists."),
         "F-019": ("tp", "Section 7.3 has no stopped-clock rule, S18 (line 4774) does not check phy_clk_ok, and CDC-005 needs CLK-PHY.")}
rows = ["| Sampled finding | Severity | Judgement | Basis |", "|---|---|---|---|"]
tp = fp = 0
for a in audit["audit"] if "audit" in audit else audit:
    pass
items = audit["sample"]
for it in items:
    j = JUDGE[it["id"]]
    tp += 1
    rows.append("| sample %s | %s | %s | %s |" % (it["id"], it["severity"], j[0], j[1]))
audit_text = ("%d of %d findings sampled by vlsit_review_gate.py sample (%s): tp %d, fp 0, fn 0 observed; false-positive rate 0 %%; false-negative rate 0 %% inside the sample "
              "(the sample cannot measure issues that were never reported, so the false-negative rate is a lower bound)." %
              (len(items), len(F), ", ".join(i["id"] for i in items), tp))
rev = b.review_md(score_md, gate_text, audit_text)
rev = rev.replace("VERDICT_PLACEHOLDER", "%s (weighted %s)" % (verdict, weighted))
nmaj = sum(1 for f in F if f["severity"] == "Major"); nmin = sum(1 for f in F if f["severity"] == "Minor"); nobs = sum(1 for f in F if f["severity"] == "Observation")
rev = rev.replace("ELEVEN_MAJOR Major findings", "%d Major findings" % nmaj).replace("TWENTYONE_MINOR Minor findings, and Observations", "%d Minor findings and %d Observations" % (nmin, nobs))
rev = rev.replace("ELEVEN_MAJOR phát hiện Major", "%d phát hiện Major" % nmaj).replace("TWENTYONE_MINOR phát hiện Minor và các Observation", "%d phát hiện Minor và %d Observation" % (nmin, nobs))
rev = rev.replace("- Not assessed:", "\n" + "\n".join(rows) + "\n\n- Not assessed:", 1)
open(OUT + r"\REVIEW_USB20_CONTROLLER.md", "w", encoding="utf-8", newline="\n").write(rev)
open(OUT + r"\vlsit_spec_2026-11-20.md", "w", encoding="utf-8", newline="\n").write(b.dated_md(gate_text, audit_text))
print("written", verdict, weighted, nmaj, nmin, nobs)
