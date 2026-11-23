# DVP Controller Research

Status: **INCOMPLETE** — 10/10 local sensor datasheets and 9/10 local peer-reviewed full-text papers. P10 is catalogued as an approved public source, but its public PDF endpoints could not be downloaded (publisher connection refused; ResearchGate returned HTTP 403). No login, CAPTCHA, or access-control bypass was used.

## Contents

- [Research report](research_report.md) — protocol evidence, controller recommendations, standards distinction, limitations, and preliminary patent scan.
- [Source manifest](vlsit_source_manifest.csv) — canonical list of acquired files with source URLs, rights notices, hashes, and metadata.
- [Checker source bundle](vlsit_sources) — canonical registered copies checked by the VLSIT feature-research tool.
- [Acquisition staging copies](sources) — original-name copies from the initial collection pass; vlsit_sources is the canonical deduplicated bundle.
- [Evidence matrix](evidence_matrix.csv) — sensor-specific signal/timing evidence with document locators.
- [Acquisition status](download_results.csv) — final status for all 20 planned sources.
- [Architecture diagram](dvp_controller_architecture.mmd) — proposed block and clock-domain structure.
- [Initial attempts](download_attempts_initial.csv) — first-batch results; superseded by download_results.csv.

## Recheck source bundle

Run in PowerShell:

~~~powershell
& 'C:\Users\PC\AppData\Local\Programs\Python\Python312\python.exe' 'C:\Users\PC\.agents\skills\vlsit-asic-ip-feature-research\scripts\vlsit_asic_ip_feature_research.py' check 'C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\025_DVP_Controller\research'
~~~

Expected result for the current bundle: INCOMPLETE: datasheets=10/10 papers=9/10. The report must not be treated as meeting the skill's 10+10 source threshold until a full-text P10 file is locally available and registered.

## Rights handling

The selected OmniVision and onsemi datasheets are manufacturer-copyrighted or proprietary documents obtained from public endpoints/mirrors. They are kept here for private research and must not be redistributed. The open-access papers retain their stated licenses (mostly CC BY 4.0). P10 is CC BY-NC 4.0, but no local copy is present. Cite each source before reuse and observe the applicable license.
