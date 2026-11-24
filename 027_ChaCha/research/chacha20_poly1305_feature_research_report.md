# ChaCha20-Poly1305 hardware IP: feature, architecture and integration research

**Status: `INCOMPLETE`** (evidence gate: 7 of 10 product families, 3 of 10 peer-reviewed full-text papers; shortfall 3 and 7).
Search date: 2026-11-22. Language of artifacts: English (rule R-020). Bundle checker result at the time of writing: `INCOMPLETE: datasheets=7/10 papers=3/10 duplicate_file_hashes=0`.

## 1. Executive summary

**Target.** Hardware (Application-Specific Integrated Circuit, ASIC, and Field-Programmable Gate Array, FPGA) intellectual property (IP) that implements the ChaCha20 stream cipher and the Poly1305 message-authentication code, combined as the Authenticated Encryption with Associated Data (AEAD) construction of RFC 8439.
**Applications requested by the user.** Network/Virtual Private Network (VPN)/Transport Layer Security (TLS) offload, Internet of Things (IoT) and microcontroller (MCU), storage and inline disk encryption, drone and automotive.
**Question.** Which functions, architecture and integration properties do documented products and peer-reviewed papers show, and where are the gaps?

Top findings (each is a statement about this corpus only; see section 5):

1. All 7 sampled product families document ChaCha20, Poly1305, or both, but in two quite different forms: licensable IP cores (4 families, D1-D4) and fixed accelerators inside wireless System-on-Chips (SoCs) (3 families, D5-D7).
2. In the three Silicon Labs SoC documents, ChaCha20 and Poly1305 appear to belong only to the "Secure Vault High" feature set, not "Secure Vault Mid", and the Differential Power Analysis (DPA) countermeasure text names the AES and ECC accelerators, not ChaCha20 or Poly1305 (D5-D7; reading of table text layout, to be confirmed visually).
3. Only 3 of 7 families give a ChaCha20-Poly1305 throughput figure, and all three are vendor claims without stated clock, technology or test conditions (D2, D3, D4). The SoCs give only stand-alone Poly1305 timing (D5, D6).
4. None of the 10 sources mentions automotive, drone, Controller Area Network (CAN), functional safety, or error-correcting memory protection of keys. This is the clearest evidence gap for the user's drone/automotive target.
5. The three papers cover three different aspects (configurable-round throughput scaling, TLS 1.3 AEAD with fault detection, first-order masked AEAD), and only P3 treats side-channel protection. No product document reports a comparable protected ChaCha20-Poly1305 core.

Confidence: **medium** for the existence of the documented features, **low** for any ranking or prevalence statement (small corpus, vendor-claim evidence, three correlated SoC datasheets).
Not a legal clearance and not a market-share statement.

## 2. Scope and method

- **Source mode.** User documents first, search for the rest. User-supplied: 5 files saved by the user from public vendor and publisher pages (D5, D6, D7, D4, P2). Found and downloaded by search: 5 files (D1, D2, D3, P1, P3). The user approved both batches in chat.
- **Product generation.** Documents dated 2019-2026 by their metadata; revisions were not read for every sheet (see section 3).
- **Search protocol (frozen before extraction, rule R-005).**
  - Catalogs: general web search engine (standard and extended modes), Crossref application programming interface, vendor product pages, Zenodo, Springer, MDPI, IEEE Xplore (abstract level only), IACR ePrint (abstract level only).
  - Exact queries, all run on 2026-11-22:
    1. `ChaCha20-Poly1305 AEAD hardware IP core datasheet pdf`
    2. `ChaCha20 Poly1305 hardware accelerator ASIC FPGA implementation peer-reviewed IEEE paper`
    3. `crypto engine datasheet ChaCha20-Poly1305 AES-GCM inline security IP Rambus OR Synopsys OR "Secure-IC" OR CAST`
    4. `microcontroller OR SoC datasheet "ChaCha20" hardware accelerator Poly1305 nRF54 OR Silicon Labs OR Renesas OR Infineon OR NXP OR Microchip`
    5. `ChaCha20 hardware implementation low area high throughput open access paper MDPI OR Springer OR IEEE Access OR "Journal of Cryptographic Engineering"`
    6. `ChaCha20-Poly1305 hardware accelerator FPGA paper full text pdf open access TLS 1.3 IPsec WireGuard`
    7. `"ChaCha20" "Poly1305" datasheet crypto accelerator MCU OR SoC ... STMicroelectronics OR Silicon Labs OR Infineon OR NXP OR Renesas OR Espressif OR Telink`
    8. `AEAD security protocol engine datasheet ChaCha20-Poly1305 CAST OR Synopsys OR "Intrinsic ID" OR "Silex Insight" OR "Arm CryptoCell" OR ...`
    9. `Poly1305 hardware implementation ASIC FPGA paper conference journal low area MAC`
    10. `ChaCha stream cipher ASIC implementation power area lightweight IoT journal paper open access pdf ...`
    11. `datasheet pdf hardware crypto accelerator "ChaCha20-Poly1305" SoC OR MCU OR "security IP" Espressif OR Infineon OR NXP OR Renesas OR Microchip OR Telink OR Realtek OR Ambiq OR Alif`
    12. `"ChaCha20" "Poly1305" accelerator "product brief" OR "datasheet" ASIC security IP AES-GCM multi-protocol engine Rambus OR Synopsys OR Cadence OR Arm OR CAST OR ...`
    13. `ChaCha20-Poly1305 hardware paper IEEE OR ACM OR Springer OR Elsevier OR MDPI "ChaCha" FPGA ASIC high-throughput OR side-channel OR fault-detection pdf open access`
    14. Patent and licence queries listed in section 9.
  - Date limits: none set. Language: English. Search engine coverage is United States only, which is a blind spot for non-English vendor documents (rule R-025).
- **Inclusion.** A datasheet or product sheet from the manufacturer, directly accessible, describing ChaCha20 and/or Poly1305 in a real product or documented design. A peer-reviewed full-text paper with ChaCha20 and/or Poly1305 hardware content.
- **Exclusion (and why).** Vendor web pages without a downloadable document (Rambus Protocol-IP-68/197, Silex Insight, Design Gateway, Cerberus Laboratories, Nordic CRACEN web documentation); datasheets behind forms; IEEE ISOCC 2021 (paywalled; extended version P2 is counted instead); IACR ePrint 2016/330 (publication venue not confirmed on its page, and the design uses Salsa20 rather than ChaCha); theses, patents, wiki pages and open-source repositories (do not count as papers).
- **Deduplication.** By family key for products, by Digital Object Identifier (DOI) for papers. P2 is the extended version of the ISOCC 2021 paper (stated in P2, page 1), so ISOCC 2021 is not counted separately. A byte-identical second download of P2 was not registered.

## 3. Evidence inventory and quality

Source register (full metadata, URLs and SHA-256 hashes: `vlsit_source_manifest.csv`).

| Short ID | Document | Organization, year | Family key | Type | Authority / relevance / independence |
|---|---|---|---|---|---|
| D1 | Securyzr SCZ_IP_ChaChaPoly Crypto Engine product sheet V4.0 | Secure-IC, 2025 (PDF metadata) | `secureic_scz_ip_chachapoly` | Vendor product sheet | High / High / vendor claims |
| D2 | Securyzr SCZ-SP-BA454 IPsec Engine product sheet V1.2 | Secure-IC | `secureic_scz_sp_ba454_ipsec` | Vendor product sheet | High / Medium (ChaCha20-Poly1305 is one listed cipher) / same vendor as D1, D4 |
| D3 | ChaCha20-Poly1305 / Ascon Symmetric Encryption (XIP2113B, XIP2113H) | Xiphera | `xiphera_xip2113` | Vendor product brief | High / High / vendor claims |
| D4 | SCZ_IP_ChaChaPoly_S8 ChaCha20-Poly1305 Multi-Booster product sheet V4.0 | Secure-IC, 2025 | `secureic_scz_ip_chachapoly_s8` | Vendor product sheet | High / High / **partially independent of D1** (same vendor, distinct product code and architecture; user chose to keep it separate) |
| D5 | EFR32MG21 Multiprotocol Wireless SoC Data Sheet | Silicon Labs, 2024 (PDF metadata) | `silabs_efr32mg21` | Manufacturer datasheet | High / Medium / **correlated with D6, D7** (shared Series 2 secure-engine lineage, user chose to keep separate) |
| D6 | EFR32MG24 Wireless SoC Data Sheet Rev. 1.2 | Silicon Labs, 2024 | `silabs_efr32mg24` | Manufacturer datasheet | as D5 |
| D7 | EFR32FG23 Wireless SoC Data Sheet | Silicon Labs, 2025 | `silabs_efr32fg23` | Manufacturer datasheet | as D5 |
| P1 | A Hardware Perspective on the ChaCha Ciphers (Pfau, Reuter, Harbaum, Hofmann, Becker), IEEE System-on-Chip Conference (SOCC) 2019, DOI 10.1109/SOCC46988.2019.1570548289 | KIT repository copy | n/a | Accepted manuscript | High / High (ChaCha only, no Poly1305) / independent |
| P2 | ChaCha20-Poly1305 AEAD for TLS 1.3 (Serrano, Duran, Sarmiento, Pham, Hoang), Cryptography 6(2):30, 2022, DOI 10.3390/cryptography6020030 | MDPI, CC BY 4.0 | n/a | Journal article | High / High / independent |
| P3 | Towards a Side-Channel-Resistant and Scalable ChaCha20-Poly1305 Hardware Implementation (Rubio-Barbero et al.), Availability, Reliability and Security (Lecture Notes in Computer Science), Springer, 2026, DOI 10.1007/978-3-032-36885-0_11 | Zenodo copy, CC BY 4.0 | n/a | Conference chapter | High / High / independent |

Quality notes and limits:
- Peer review: P1 is the accepted manuscript, not the publisher version; its review status is inferred from IEEE publication. P3's review status is inferred from the Springer proceedings record (Crossref lookup, 2026-11-22); the Zenodo file has not been compared with the published version.
- Years for D5-D7 are PDF creation dates, not revision dates (D6 states Rev. 1.2). Revisions of D1-D3, D5, D7 were not read.
- I read the abstract, introduction and architecture parts of P1-P3, not every page. Numbers quoted from papers are from those parts.
- Vendor sheets state throughput and area without conditions; they are claims, not independent measurements.

Shortfall: 3 product families and 7 papers. See section 12.

## 4. Feature and function taxonomy

| ID | Normalized feature | Source terminology | Function / user outcome | Evidence status | Confidence |
|---|---|---|---|---|---|
| F-01 | ChaCha20-Poly1305 AEAD | "AEAD" (D1, D4); "ChaCha20 Poly1305" (D2, D5-D7 feature lists p.2); "ChaCha20-Poly1305" (D3) | Encrypt and authenticate in one pass, 16-byte tag per RFC 8439 | Documented | High |
| F-02 | Stated RFC conformance | "RFC7539 compliant" (D1, D4); "RFC 4106, 4301, 4303, 7634" (D2); D3 sheet says only "modern cryptographic standards" | Interoperability with TLS, IPsec peers | Partly documented | Medium |
| F-03 | Stand-alone ChaCha20 | "stand-alone encryption/decryption (ChaCha20)" (D1); "ChaCha20" under symmetric encryption (D5-D7) | Stream cipher use without a tag, for example storage encryption building blocks | Documented | Medium |
| F-04 | Stand-alone Poly1305 | "stand-alone authentication (Poly1305)" (D1); "Poly1305" under hashes (D5-D7) | MAC with externally supplied one-time key | Documented | Medium |
| F-05 | SoC bus integration | "AMBA AHB/AXI bridges (with optional scatter/gather DMA)" (D1, D4); "AMBA 4 AXI-Stream data, AMBA 4 APB control" (D2); FIFOs, commands/responses, key, nonce, tag ports (D3 p.2) | Memory-to-memory and streaming integration in an SoC | Documented, interface level only | Medium |
| F-06 | Quantified throughput claim | "up to 50 Gbps" (D3); "800 Gbps ASIC, 100 Gbps FPGA" (D4); "1 Gbps up to 100 Gbps" for the whole IPsec engine (D2) | Sizing for line-rate use | Vendor claim | Low |
| F-07 | Scalable area/throughput variants | "BALANCED" and "HIGH-SPEED" variants (D3 p.1); "scalable to reach the requested trade-off" (D1, D4) | Match IP size to application | Documented, no area at stated conditions except kLUT figures in D3 | Low |
| F-08 | Context switching | "Context switching" (D1) | Interleave several message streams on one engine | Documented, one family | Low |
| F-09 | Poly1305 one-time key from ChaCha20 | "Key generation for Poly1305: ChaCha20 / Dedicated input" (D1); "Poly1305 key generation by ChaCha20" (D4) | Follows the RFC 8439 construction; dedicated input allows a stand-alone MAC | Documented | Medium |
| F-10 | Isolated secure engine around the cipher | "Secure Vault" with its own CPU (D5-D7) | Keeps keys and crypto away from the application core | Documented for SoCs only | Medium |
| F-11 | Side-channel countermeasure covering ChaCha20-Poly1305 | DPA text names AES and ECC accelerators (D5-D7, "DPA Countermeasures" subsection); P3 first-order masking | Resistance against power analysis | Absent from product text for ChaCha, present in P3 | Medium |
| F-12 | Configurable round count (ChaCha8/12/20) | P1 | Trade security margin for speed | Papers only | Medium |
| F-13 | Fault detection for fragmented blocks | P2 abstract | Recover from fragmented TLS records | Papers only | Low |
| F-14 | IPsec ESP packet integration | "ESP encapsulation/decapsulation", 5-tuple classification, anti-replay (D2) | Line-rate VPN gateway | Documented, one family | Medium |
| F-15 | Automotive, drone, CAN or functional-safety claim | none | Needed for the user's target | **Not reported in any source** | n/a |

## 5. Corpus occurrence, not market share

Definitions. Numerator: distinct product families whose sheet explicitly documents the feature. Denominator: the 7 sampled families. Silence in a sheet is "not reported", never "absent"; no sheet states an explicit absence except the Secure Vault Mid column discussed under F-03 and F-04. Because many sheets are short marketing-style product sheets, the denominator is **not** reduced and the rate is labelled "documented in 7 sheets" rather than a prevalence. Per rule R-011, a family would be excluded from a denominator only if its sheet could not show the feature at all; I made no such exclusion, and that is a judgement the reader should challenge. Papers: P1-P3 only, N = 3.
Percentages are shown for completeness; with N = 7 and N = 3 they have no statistical meaning and the SoC rows are correlated.

| Feature | Product families documenting / 7 | Product corpus rate | Papers discussing / 3 | Paper corpus rate | Not reported / ambiguous | Limits |
|---|---:|---:|---:|---:|---|---|
| F-01 AEAD or both components | 7/7 | 100 % | 2/3 (P2, P3) | 67 % | 0 / 0 | SoCs list the two primitives separately and only in the "High" feature set (inferred from table layout); P1 covers ChaCha only |
| F-02 stated RFC conformance | 3/7 (D1, D2, D4) | 43 % | not counted | n/a | 4 | D3's other web pages mention RFC 8439 but the registered brief does not |
| F-03 stand-alone ChaCha20 | 4/7 (D1, D5, D6, D7) | 57 % | 3/3 | 100 % | 3 | D5-D7 correlated |
| F-04 stand-alone Poly1305 | 4/7 (D1, D5, D6, D7) | 57 % | 2/3 | 67 % | 3 | D5-D7 correlated; P1 has no Poly1305 |
| F-05 AMBA AHB/AXI bridge with optional DMA | 2/7 (D1, D4) | 29 % | 1/3 (P2: TileLink bus in a RISC-V system) | 33 % | 5 | D2 uses AXI-Stream and APB, no DMA stated; counted separately |
| F-06 throughput number for ChaCha20-Poly1305 | 3/7 (D2, D3, D4) | 43 % | 3/3 (P1 Gbit/s, P2 cycles per byte, P3 Gbps) | 100 % | 4 | Vendor figures lack technology and clock; D5, D6 give only Poly1305 timing |
| F-08 context switching | 1/7 | 14 % | 0/3 | 0 % | 6 | Single vendor sheet |
| F-09 Poly1305 key from ChaCha20 | 2/7 (D1, D4) | 29 % | not extracted | n/a | 5 | Papers implement the RFC construction but I did not extract a specific statement |
| F-11 side-channel protection of ChaCha20-Poly1305 | **0/7** | 0 % documented | 1/3 (P3) | 33 % | 7 | The SoC DPA text names AES/ECC; this is "not stated for ChaCha", not proof of absence |
| F-12 configurable round count | 0/7 | 0 % | 1/3 (P1) | 33 % | 7 | P1 states that the commercial Xiphera core of that time did not allow it (P1 p.1); not re-verified for current D3 |
| F-14 IPsec ESP integration | 1/7 (D2) | 14 % | 0/3 | 0 % | 6 | Single vendor sheet |
| F-15 automotive/drone/CAN/functional safety | **0/7** | 0 % | **0/3** | 0 % | 10 | Search was not targeted at automotive vendors beyond the queries listed; see section 12 |

These are occurrence rates in this researched corpus on 2026-11-22, with selection bias toward vendors that publish downloadable ChaCha documents. They are not market share, installed base or demand.

## 6. System architecture and microarchitecture

Figure: [chacha20_poly1305_architecture.drawio](../spec/figures/chacha20_poly1305_architecture.drawio) (green = block named in a source, yellow dashed = inferred relationship, red dashed = unknown).

Documented facts:
- **Block organization (D1, D4 p.1 block drawings).** An interface bridge (AMBA, SRAM, FIFO, DMA), a control block, a ChaCha20 engine and a Poly1305 engine. D4 draws a "High-Throughput Poly1305 Engine" next to the ChaCha20 engine. Data and control paths are drawn but not described in text.
- **Xiphera (D3 p.2 block drawing).** Input FIFO, "Parallel ChaCha20 cores", "Pipelined Poly1305 core", output FIFO; ports for commands, responses, control, key, nonce and tag. Variants: XIP2113B balanced and XIP2113H high-speed. The sizing text on p.1 ("Several Gbps / ~7.3 kLUTs", "10s of Gbps / ~24 kLUTs", "100s of Mbps / ~2.3 kLUTs") lost its column alignment in text extraction, so I assign them to B, H and the Ascon core only by plausibility; **verify visually before citing**.
- **Pipeline detail (P1 section IV).** The quarter-round is decomposed into add-rotate-XOR (ARX) cells with adjustable pipelining. Interleaving blocks from several matrices keeps a deep pipeline full because the diagonal round depends on the column round of the same block. P1 reports that a pipeline is more efficient than multiple independent block primitives, and a scalable range from 476 slices to 175 Gbit/s on FPGA (P1 title and abstract).
- **Poly1305 microarchitecture (P2, P3).** P2: multiply-accumulate unit with a 32-bit multiplier and accumulator, standalone AEAD core at 1.4 cycles per byte and 11.56 cycles per byte in a RISC-V system over TileLink, 10,808 look-up tables and 3731 flip-flops on a Virtex-7 (P2 abstract). P3: configurable pipelining of ChaCha20 rounds and a folded Karatsuba-based Poly1305 multiplier-accumulator, plus a first-order masked variant using threshold implementations, secure double-rate registers and a masked Galois-field multiplier; unprotected core up to 0.66 Gbps on Artix-7 (P3 abstract).
- **SoC form (D5-D7).** A hardware secure engine "containing its own CPU" isolates the cryptographic functions from the Cortex-M33 core; a "Cryptographic Accelerator" is described as autonomous. ChaCha20 and Poly1305 are reached through the secure engine (D5 PDF p.12-13, D6 p.13-14, D7 p.14-15). The internal datapath is not documented.

Inferences (not documented): that the host drives the engine through descriptors in memory when DMA is present; that the Poly1305 one-time key comes from the ChaCha20 block with counter zero as in RFC 8439 for D1/D4; that the SoC secure engine processes messages sequentially through a command interface.

Unknown: clock and reset structure, error and tag-failure signalling, register maps, interrupt behavior, memory ordering and endianness, behavior for zero-length or maximum-length messages, per-message setup latency. These matter for software and for short-frame protocols such as CAN FD (see section 8).

## 7. Integration and physical interface requirements

All engines in D1-D4 and P1-P3 are digital logic blocks. D5-D7 are complete SoCs with radio pads that are unrelated to the crypto block. No source describes a pad, PHY or off-chip interface for the crypto function itself.

| Feature / interface | Local block | External peer | Protocol / logical contract | Pad / PHY / electrical evidence | Clock / reset / power | Package / board / process | Open integration questions |
|---|---|---|---|---|---|---|---|
| Host data path D1, D4 | Interface bridge | SoC bus matrix, system memory | AMBA AHB or AXI, optional scatter/gather DMA | None (on-chip) | Not documented; "full synchronous design" and "low power features" only | Netlist or RTL, synthesis and STA scripts, self-checking test bench are the stated deliverables | Clock-domain count, reset style, DMA descriptor format, burst and alignment rules |
| Streaming data path D2 | IPsec engine and crypto core | Network MAC | AXI4-Stream data, APB control, datapath 32-1024 bits | None (on-chip) | Not documented | ASIC and FPGA | Back-pressure, packet-length limits, bypass behavior |
| Streaming interface D3 | Input/output FIFOs | System logic | Command/response, key, nonce, tag ports | None | Not documented | "Vendor agnostic FPGA/ASIC" | FIFO depth, key-load timing, tag-compare location |
| Secure engine D5-D7 | Secure Vault / hardware secure engine | Cortex-M33 application core | Via secure engine firmware; the API (Application Programming Interface) is not described in these data sheets | None for this function | Stand-alone Poly1305 current, 1 kB message: 4.4 mA (D5 PDF p.66, 32 kB value not read reliably, test conditions not read); 0.6 mA for 1 kB and 1.6 mA for 32 kB (D6 PDF p.95) | Silicon Labs chip variants; feature set selected by part number ("A = Secure Vault Mid, B = Secure Vault High", D6) | Part-number dependency, firmware version dependency (D6 notes footnotes about SE version), ChaCha20-Poly1305 as one call or two |

## 8. Configuration, registers and software usability

Documented: D1 offers stand-alone encryption, stand-alone authentication and context switching; D3 exposes key, nonce, tag and command/response ports; D2 uses an APB control interface. No sheet gives a register map, error codes, interrupt list, driver or API. D5-D7 are SoCs with vendor firmware in the secure engine; the data sheets do not document the call interface.

Observations that bear on the user's short-message targets (analysis, not a sourced claim):
- ChaCha20-Poly1305 adds a 16-byte tag. A CAN FD frame carries at most 64 data bytes, so an AEAD tag plus counter/nonce overhead consumes a large part of the frame. No source examines short-message efficiency. The sampled products report throughput, not per-message latency or setup cost, so the cost per short message is unknown. This is the central open question for a CAN-attached use (section 10, proposal 1).
- Software need: key and nonce management, nonce uniqueness, tag-failure handling and constant-time behavior. Only P2 and P3 discuss side channels, and only P3 evaluates masking.

## 9. Licensing, patent and dependency review

I am not a lawyer and this section is not legal advice or clearance.

| Item | Evidence | Source and date | Status / uncertainty |
|---|---|---|---|
| Document rights, D1-D7 | Marketing/data sheets of commercial vendors; no licence text in the files | Vendor pages, saved 2026-11-22 | Treat as copyright-protected, internal research use only; not redistributed |
| Document rights, P2 | CC BY 4.0, stated on the article page and in the PDF | MDPI, 2026-11-22 | Reuse with attribution permitted by that licence |
| Document rights, P3 | CC BY 4.0 (Zenodo record 24137616); Springer chapter has its own terms | Zenodo, Crossref, 2026-11-22 | Zenodo copy only |
| Document rights, P1 | IEEE notice: accepted version, personal use; redistribution needs IEEE permission | P1 page 1 | Do not redistribute |
| Implementation licence, D1-D4 | Commercial licensing; deliverables are netlist or RTL, no licence text in sheets | D1-D4 | Unknown terms, contact vendor |
| Implementation licence, D5-D7 | Silicon chip; the crypto block is not separately licensed in these sheets | D5-D7 | Not applicable to IP reuse |
| Standard terms | RFC 8439 (ChaCha20 and Poly1305 for IETF protocols) is an informational Request for Comments of the Crypto Forum Research Group; RFC 7539 is its predecessor; RFC 7634 covers use in IPsec (IKEv2) | IETF datatracker and RFC editor pages found by search, 2026-11-22 | IETF Trust copyright terms not reviewed in detail |
| Patent statement by the algorithm designer | The searches did not return a patent or public-domain statement from the designer's own site; none is claimed here | Search 2026-11-22 | **Unresolved**; check the designer's site and the IETF IPR disclosure pages for the RFCs |
| Patent records of hardware designs | Search results show United States Patent and Trademark Office documents 12675584 and 12309256 (both titled "Apparatus for cryptographic operations on information and associated methods", described as a ChaCha20 block-function circuit and a Poly1305 circuit), and earlier hits 12316742 ("Hardware circuit to perform round computations of ARX-based stream ciphers") and 10705842 (hardware accelerators for high-performance authenticated encryption) | USPTO public print service via web search, 2026-11-22 | Claims, assignee, legal status and family members not read. Jurisdiction searched: United States only (through a US-only search tool). Other jurisdictions and databases (Espacenet, WIPO, China, Japan) **not checked** |
| Third-party dependencies | D2 relies on integrated crypto cores and optional ternary content-addressable memory (TCAM) interface; D3 states "pure RTL without hidden CPU or software components" | D2, D3 | Dependencies of D1, D4 not stated |

A missing patent hit does not mean a feature is unpatented, royalty-free or cleared. Legal review is needed before any design reuse or product decision.

## 10. Opportunities for new or improved features

All proposals are hypotheses, not originality or patent findings.

| Proposal | Unmet need and evidence | User/software benefit | Architecture and integration change | PPA, security and compatibility risks | Licensing uncertainty | Validation experiment | Confidence |
|---|---|---|---|---|---|---|---|
| 1. Short-message AEAD mode with published per-message latency | Sampled sheets report only throughput (D2, D3, D4) and give no per-message cost; D1 offers context switching but no latency number; CAN FD frames are at most 64 data bytes (protocol knowledge, no source in this corpus). Evidence of the need for CAN is therefore indirect | Predictable latency for control loops; software can budget bus time | Fast key/nonce load path, small-message fast path in control logic, deterministic cycle counts | Extra control logic area, risk of nonce-reuse if the context path is complicated | Unknown; overlaps patent leads in section 9 | Cycle-accurate model of key load plus 8, 16, 32, 64-byte messages against a software baseline | Low |
| 2. Optional first-order masked ChaCha20-Poly1305 as an SoC feature | D5-D7 apply DPA countermeasures to AES and ECC only (as read in the text); P3 shows a masked variant with a stated area, power and performance overhead and a leakage test on 2x10^6 traces. | Side-channel resistance for key-bearing edge devices, relevant to drone and automotive units that can be physically accessed | Masked datapath, random-number supply, and secure register handling; area and throughput cost per P3 (not extracted here) | Cost grows with masking order; first order only; requires fresh randomness | Possibly encumbered by threshold-implementation patents (not checked) | Reproduce P3's leakage test on the target process or FPGA; compare overhead with an unmasked baseline | Medium |
| 3. Documented diagnostics: tag-failure code, fault detection, key-memory error check | No sampled datasheet reports error or safety features for the ChaCha function (F-15 zero); P2 adds a fault detector for fragmented blocks | Software can distinguish authentication failure from hardware fault; supports safety case | Status register, interrupt, optional parity/ECC on key and state storage | Area and verification cost; interaction with the safety standard is not evidenced | Unknown | Fault-injection campaign on RTL model of an engine; measure detection coverage | Low |

## 11. Trade-offs and recommendation

For a drone or automotive node that needs authenticated messages on CAN-class buses, three options are viable (assumptions: short messages, small silicon budget, secure key storage, no sampled source targets this domain):

| Option | Benefit | Cost and risk | Evidence |
|---|---|---|---|
| A. Licensed ChaCha20-Poly1305 core (D1/D3-class) | Fast integration, vendor deliverables | Licence terms unknown, no short-message latency data, no safety data | D1-D4 |
| B. SoC-style secure engine offload (D5-D7-class) | Keys isolated, no extra datapath | Feature depends on part number and firmware; Poly1305 1 kB timing of 212 µs (MG21) and 514 µs (MG24) is slow compared with core-level claims (D5 p.64, D6 p.93) | D5-D7 |
| C. Own core based on published architectures (P1-P3) | Full control of area, masking, diagnostics | Design and verification effort, patent review required | P1-P3 |

I do not recommend one on this evidence. The decision criteria that would settle it are per-message latency, safety evidence and licence terms, none of which the corpus provides. If the user wants the next step, the cheapest high-value experiment is proposal 1's latency model, which needs no vendor input.

## 12. Risks, gaps and next research steps

- **Evidence thresholds not met:** 3 product families and 7 papers short. The report must be read as `INCOMPLETE` and as a preliminary scan.
- **Excluded and inaccessible items:** Rambus, Silex Insight, Design Gateway, Cerberus Laboratories and Nordic CRACEN (web pages or gated); IEEE ISOCC 2021 (paywalled); IACR ePrint 2016/330 (venue unconfirmed); Zenodo version versus Springer version of P3 not compared.
- **Verification debt:** (a) the Secure Vault Mid/High assignment of ChaCha20 and Poly1305 in D5-D7 comes from text layout and should be confirmed visually; (b) the throughput and kLUT assignment in D3 p.1; (c) document revisions of D1, D3, D5, D7; (d) P1 and P3 review status inferred.
- **Correlated sources:** D5-D7 are one design lineage; D1 and D4 are one vendor. Rates should not be quoted as independent.
- **Search blind spots:** United States-only search tool; no vendor-by-vendor search for Chinese, Japanese or Korean automotive suppliers; no standards body or Automotive standards (for example functional safety) review; patents searched only through web results.
- **Next steps:** obtain three or more further datasheets (candidate families: other secure-element and automotive MCU vendors, plus gated IP datasheets supplied by the user); find peer-reviewed papers on ChaCha/Poly1305 in automotive or in-vehicle network security; search patent databases directly for claims of the four leads; extract P1-P3 numbers fully (area, power, overhead) into a comparison table.

## 13. Abbreviations and references

Glossary (scoped): AEAD, Authenticated Encryption with Associated Data; ARX, add-rotate-XOR; DPA, Differential Power Analysis; FIFO, first-in first-out buffer; DMA, Direct Memory Access; MAC, message authentication code; AMBA, Advanced Microcontroller Bus Architecture; AHB, Advanced High-performance Bus; AXI, Advanced eXtensible Interface; APB, Advanced Peripheral Bus; ESP, Encapsulating Security Payload; TCAM, ternary content-addressable memory; TVLA, Test Vector Leakage Assessment; SoC, System-on-Chip; LUT, look-up table; IPR, intellectual property rights.

References (locators are PDF pages of the retained copies; all are in `vlsit_sources/`):
- D1 Secure-IC, SCZ_IP_ChaChaPoly product sheet V4.0, pp.1-2. https://secure-ic.com/scz_ip_chachapoly_product_sheet
- D2 Secure-IC, SCZ-SP-BA454 IPsec engine product sheet V1.2, p.1. https://secure-ic.com/scz_sp_ba454_ipsec_engine_product_sheet_web
- D3 Xiphera, ChaCha20-Poly1305 / Ascon Symmetric Encryption, pp.1-2. https://xiphera.com/wp-content/uploads/Xiphera_ChaCha20-Poly1305_Ascon_Symmetric_Encryption.pdf
- D4 Secure-IC, SCZ_IP_ChaChaPoly_S8 Multi-Booster product sheet V4.0, p.1. https://www.secure-ic.com/products/securyzr/chacha20-poly1305-mb/
- D5 Silicon Labs, EFR32MG21 Data Sheet, pp.2, 12-13, 64, 66. https://www.silabs.com/documents/public/data-sheets/efr32mg21-datasheet.pdf
- D6 Silicon Labs, EFR32MG24 Data Sheet Rev. 1.2, pp.2, 13-14, 93, 95. https://www.silabs.com/documents/public/data-sheets/efr32mg24-datasheet.pdf
- D7 Silicon Labs, EFR32FG23 Data Sheet, pp.2, 14-15. https://www.silabs.com/documents/public/data-sheets/efr32fg23-datasheet.pdf
- P1 Pfau et al., SOCC 2019, DOI 10.1109/SOCC46988.2019.1570548289. https://publikationen.bibliothek.kit.edu/1000123496/149036858
- P2 Serrano et al., Cryptography 6(2):30, 2022, DOI 10.3390/cryptography6020030. https://www.mdpi.com/2410-387X/6/2/30
- P3 Rubio-Barbero et al., DOI 10.1007/978-3-032-36885-0_11. https://zenodo.org/records/24137616
- Standards (context only, not counted): RFC 8439, RFC 7539, RFC 7634. https://www.rfc-editor.org/rfc/rfc8439
- Source manifest with hashes: `vlsit_source_manifest.csv`; manifest source IDs map to D1-D7 and P1-P3 in the order of the register in section 3.
