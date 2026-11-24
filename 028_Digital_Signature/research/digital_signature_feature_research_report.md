# Digital-signature hardware IP: Ed* family, ECDSA and post-quantum signatures - feature, architecture and integration research

**Status: `READY`** for the mechanical evidence gate (10 product families, 11 peer-reviewed full-text papers; checker output below). `READY` only means the counts, files and hashes are consistent. It does not validate source quality, claim correctness or rights.
Research date: 2026-11-24. Language of artifacts: English (rule R-020).
Checker output: `READY: datasheets=10 papers=11 duplicate_file_hashes=0`.

## 1. Executive summary

**Target.** Hardware (Application-Specific Integrated Circuit, ASIC, and Field-Programmable Gate Array, FPGA) intellectual property (IP) that generates and/or verifies digital signatures: the Edwards-curve Digital Signature Algorithm (EdDSA) family (Ed25519, Ed448 and variants), the Elliptic Curve Digital Signature Algorithm (ECDSA), and post-quantum signatures (ML-DSA, the Module-Lattice-Based Digital Signature Algorithm of Federal Information Processing Standard, FIPS, 204).
**Question.** Which functions, architectures, security measures and integration properties do documented products and peer-reviewed papers show, and where are the gaps for a new IP (028)?

Top findings. Each is a statement about this corpus only (section 5); none is market share.

1. **Product documents mostly cover ECDSA, not EdDSA.** 6 of 10 families document ECDSA (D1, D4, D5, D7, D9, D10 in section 3), 3 of 10 name Ed25519 explicitly (D1, D2 and D10, the last being a reference-manual section), and only 1 of 10 names Ed448 (D7).
2. **Post-quantum signatures are present but thin.** 2 of 10 families document ML-DSA (D3, D8); only D3 states hedged, deterministic and pre-hash modes and a validation by the NIST Cryptographic Algorithm Validation Program (CAVP). D8 is a hybrid hardware-software accelerator that needs an external SHA-3, direct memory access (DMA) engine and true random number generator (TRNG).
3. **Timing and power side-channel protection is common in IP-core briefs; fault-injection protection is not stated.** 6 of 10 families explicitly claim timing or power-analysis resistance (D2, D3, D5, D7, D8, D9); 0 of 10 explicitly claim fault-injection countermeasures (2 documents mention physical or fault attacks only as a threat class, D1 p. 11 and D4, so they are ambiguous).
4. **The papers fill the fault gap on the attack side, not the design side.** 4 of 11 papers treat fault attacks or fault countermeasures (P5, P9, P10, P11); three of them show key-recovery attacks on lattice signatures including the hedged (randomised) mode that NIST made the default, so "randomised signing" does not by itself remove the fault risk (P10 abstract, P11 abstract).
5. **Measured hardware figures exist only for EdDSA/ECDSA papers on FPGA**, e.g. 6,200 signatures per second for a high-performance Ed25519 design on a Xilinx Zynq-7020 (P2 abstract) and 327 signatures and 189 verifications per second for Ed448 on Artix-7 (P3 abstract). Product briefs give resource or latency figures for only 3 of 10 families (D2, D5, D9) and always as vendor claims.
6. **No source documents safety or automotive-grade features of a signature block** (functional safety, error-correcting memory, redundancy). TA101 (D1) is marketed for automotive and states a planned FIPS 140-3 certification, not a safety level.

Confidence: **medium** that the listed features exist as documented; **low** for any ranking (10 families, vendor claims, three vendors contribute two or more families each). Not a legal clearance and not a market-share statement.

## 2. Scope and method

- **Source mode.** Search for everything (option B of rule R-026). User-supplied documents: 0. Found by search: 21. Candidates were shown to the user in three batches and approved in chat before download. One earlier batch partly failed (see section 3). Four candidates were blocked by their hosts (HTTP 403) and were not retrieved; the downloader's access limits were not circumvented (rule R-016).
- **Application context.** Not fixed by the user beyond "digital-signature IP, high-security algorithms, including Ed* versions". The recommended default, secure boot and root of trust in embedded/Internet of Things (IoT) SoCs, was proposed in chat but never answered, so conclusions are not specific to one application.
- **Search protocol (rule R-005).** Catalogs: a general web search engine (standard and extended modes), vendor pages, IACR Transactions on Cryptographic Hardware and Embedded Systems (TCHES), IACR ePrint, NSF Public Access Repository, MDPI, KU Leuven Lirias, DOAJ records. Search date: 2026-11-24 (all searches in one session). Language: English. Date limit: none. Representative queries (full list is not retained as exact strings because several were reformulated in-session; this is a limitation):
  1. `hardware crypto accelerator datasheet Ed25519 EdDSA ECDSA hardware support secure element SoC datasheet pdf`
  2. `ML-DSA FIPS 204 hardware IP core datasheet root of trust post-quantum signature accelerator product brief`
  3. `Ed25519 hardware implementation FPGA ASIC high-speed signature generation paper open access`
  4. `ML-DSA Dilithium hardware accelerator ASIC FPGA TCHES paper side-channel masked`
  5. `Xiphera EdDSA Ed25519 Ed448 IP core product brief`; `Secure-IC Securyzr ... datasheet digital signature`; `tches.iacr.org article download ECDSA OR EdDSA OR Dilithium ...`
- **Inclusion.** Products: a manufacturer product brief, datasheet or reference-manual section that documents a signature function, one family key per product family; peer-reviewed full-text papers that are open access or author-accepted manuscripts on a public repository.
- **Exclusion.** Preprints without a recorded published version (arXiv 2504.04731, ePrint 2025/2337), abstract-only pages, marketing HTML pages, duplicate versions, documents behind authentication or paywall, and downloads that turned out to be an access-denied page (ATECC608B, removed) or an HTML page (Kudelski FDTC 2017, removed).
- **Deduplication.** One family key per product family (manifest column `family_key`); one work key or digital object identifier (DOI) per paper; file hashes checked by the script.
- **Reading depth.** Product documents: read the first pages and keyword-searched the full text. Papers: abstracts and first pages read in full; body text searched by keyword counts, not read end to end. All paper-level counts in section 5 are therefore **abstract-level judgements**, not deep readings (limit L5).

## 3. Evidence inventory and quality

All entries are rows of [`vlsit_source_manifest.csv`](vlsit_source_manifest.csv); local files are in `vlsit_sources/` (3 PDFs have the extension `.bin` because the server sent an octet-stream content type; their first bytes are the PDF signature). Page numbers below are PDF page numbers of the saved file.

| ID | Family key | Document | Qualification note |
|---|---|---|---|
| D1 | `microchip_ta101` | Microchip TA101 CryptoAutomotive summary data sheet | Summary only; full datasheet under non-disclosure agreement (p. 1). Manufacturer. |
| D2 | `xiphera_xip4003c` | Xiphera XIP4003C product brief ver. 1.0, 2024-08-30 | Brief, not a full datasheet; full datasheet on request. |
| D3 | `xiphera_xip6220b` | Xiphera XIP6220B product brief ver. 1.1.2, 2025-11-18 | Brief; the resource sheet is a separate document, not retrieved. |
| D4 | `infineon_optiga_trust_m` | Infineon OPTIGA Trust M datasheet (45 pages) | Full datasheet; Common Criteria EAL6+ hardware (p. 1). |
| D5 | `xiphera_xip41x3c` | Xiphera XIP41x3C product brief ver. 1.0, 2024-08-30 | Brief; same vendor as D2 and D3. |
| D6 | `espressif_esp32_c6` | Espressif ESP32-C6 datasheet v1.6 | Full datasheet; no EdDSA or ECDSA signature function is stated (counter-evidence). |
| D7 | `secureic_scz_ip_pkc` | Secure-IC SCZ_IP_PKC product sheet | Sheet, 2 pages; no date or version on the sheet; names ECDSA and "EdDSA/Ed448" (p. 1). |
| D8 | `secureic_scz_ip_pqc_lattice` | Secure-IC SCZ_IP_PQC_Lattice product sheet | Sheet, 2 pages; states it is aligned with the NIST round-3 version of ML-DSA (p. 2). |
| D9 | `tes_ecdsa_ip` | TES Electronic Solutions ECDSA IP core brief V1.25.8, 2025-11-07 | Brief; curve secp256k1 only. |
| D10 | `microchip_pic32_pke` | Microchip PIC32MZ W1 Family Reference Manual, Section 26 (Asymmetric Crypto Engine) | **Weak datasheet evidence**: a reference-manual section, not a datasheet. Counted but flagged. |

D1 to D10 are the ten family keys of the manifest, one row per product family; section 5 denominators use these ten.

Papers (peer-reviewed; full text saved):

| ID | Paper | Venue and access basis |
|---|---|---|
| P1 | Kieu-Do-Nguyen et al., Low-Cost Area-Efficient FPGA-Based Multi-Functional ECDSA/EdDSA | Cryptography 6(2), 25, 2022; CC BY 4.0 (stated on p. 1) |
| P2 | Bisheh-Niasar et al., Cryptographic Accelerators for Digital Signature Based on Ed25519 | IEEE TVLSI 29(7), 2021; accepted manuscript on NSF Public Access; IEEE copyright |
| P3 | Bisheh-Niasar et al., Area-Time Efficient Hardware Architecture for Signature Based on Ed448 | IEEE TCAS-II 68(8), 2021; accepted manuscript on NSF Public Access |
| P4 | Owens et al., Efficient and Side-Channel Resistant Ed25519 on ARM Cortex-M4 | IEEE TCAS-I (2024); accepted manuscript; **software**, not hardware |
| P5 | Turan, Verbauwhede, Compact and Flexible FPGA Implementation of Ed25519 and X25519 | ACM TRETS 2019; KU Leuven repository copy, licence not stated |
| P6 | Masek, Novotny, Versatile Hardware Framework for Elliptic Curve Cryptography | IEEE DDECS 2022; author-hosted copy (peer-review status taken from the venue, not re-verified) |
| P7 | Deshpande et al., SDitH in Hardware | TCHES 2024(2), 215-251; CC BY 4.0 (p. 1) |
| P8 | Coron et al., Improved High-Order Masked Generation of Masking Vector and Rejection Sampling in Dilithium | TCHES 2024(4), 335-354; **software** masking |
| P9 | Ulitzsch et al., Loop Aborts Strike Back | TCHES 2023(4), 367-392; CC BY 4.0 (p. 1); attack paper |
| P10 | Krahmer et al., Correction Fault Attacks on Randomized CRYSTALS-Dilithium | TCHES 2024(3), 174-199; attack paper |
| P11 | ElGhamrawy et al., From MLWE to RLWE: A Differential Fault Attack on Randomized and Deterministic Dilithium | TCHES 2023(4), 262-286; CC BY 4.0 (p. 1); attack paper |

**Shortfalls and exclusions.** No candidate was counted that failed to download. Not retrieved: NXP SE050/SE051 (HTTP 404), Silicon Labs EFR32BG2B (HTTP 403), ePrint 2020/1244 and 2025/621 (HTTP 403), Kudelski FDTC 2017 (file was an HTML page), Microchip ATECC608B (file was an access-denied page). Preprints (arXiv 2504.04731, ePrint 2025/2337) were not counted. Corpus composition limits: Xiphera contributes three families (D2, D3, D5), Secure-IC two (D7, D8) and Microchip two (D1, D10); only one general-purpose MCU datasheet (D6); no SLH-DSA, LMS or XMSS hardware paper or product.

## 4. Feature and function taxonomy

| ID | Normalized feature | Source terminology | Function / user outcome | Evidence status | Confidence |
|---|---|---|---|---|---|
| F1 | Ed25519 signature (EdDSA on Edwards25519) | "Ed25519 - EdDSA sign, verify and KeyGen" (D1 p. 1); "Ed25519-based EdDSA" (D2 p. 1) | Deterministic signatures with 32-byte keys at about 128-bit security; used in TLS 1.3 and SSH | documented (3 explicit, 1 ambiguous) | medium |
| F2 | Ed448 signature | "Curve25519/Curve448, EdDSA/Ed448" (D7 p. 1); "Ed448 digital signature" (P3) | Higher security level (224 bits per P3) | documented once in products | low |
| F3 | ECDSA on NIST or Koblitz curves | "ECDSA sign, verify, KeyGen" (D1 p. 1); "ECDSA signature generation and verification" (D5 p. 2); "ANSI X9.63 secp256k1" (D9 p. 1) | Widely deployed signature in PKI, secure elements and blockchains | documented (6 explicit) | medium |
| F4 | ML-DSA (FIPS 204) | "ML-DSA-44/65/87 ... hedged and deterministic ... pre-hash" (D3 p. 1); "ML-DSA-II, III, V" (D8 p. 2) | Quantum-resistant signature for firmware and certificates | documented (2) | medium |
| F5 | Timing/power side-channel countermeasure | "execution time independent of the key value" (D2 p. 1); "DPA countermeasures" (D7 p. 1); SPA, DPA, DEMA, CPA, CEMA (D8 p. 2) | Resist key recovery by measurement | documented (6) | medium |
| F6 | Fault-injection countermeasure | not stated by any product; "fault-injection attacks" as a configurable option (P5 abstract) | Resist key recovery by induced faults | absent in products; documented in papers | medium |
| F7 | Standard compliance claim | RFC 8032 and FIPS 186-5 (D2 p. 1); FIPS 186-5 (D5 p. 2); FIPS 204 and CAVP validation (D3 p. 1) | Procurement and interoperability evidence | documented (3) | medium |
| F8 | Integration interface | AMBA APB/AHB/AXI (D7 p. 1); AXI control (D8 p. 2); 16-bit custom (D2 p. 2, D5 p. 3); 64-bit custom (D3 p. 3); memory interface (D9 p. 1) | How software or a controller drives the block | documented | medium |
| F9 | External dependency | "requires an external random number generator ... ECDSA also requires an external hash function" (D5 p. 2); TRNG, DMA, SHA-3 external (D8 p. 1) | Defines what the integrator must supply | documented (2) | medium |
| F10 | Secure boot use | "support for code authentication (secure boot)" (D1 p. 1); "Secure Boot" (D8 p. 2) | The main application that needs signature verification | documented (2 with signature) | low |

## 5. Corpus occurrence, not market share

Rates describe only this corpus. Product denominators are the 10 families (every document lists its supported algorithms or functions; a function not listed is counted as "not reported", not as absent). Paper denominators are the 11 papers. Paper counts are abstract-level judgements.

| Feature | Product families with explicit evidence / assessable | Product corpus rate | Papers discussing / eligible | Paper corpus rate | Not reported / ambiguous | Limits |
|---|---:|---:|---:|---:|---|---|
| F1 Ed25519 | 3 / 10 | 30 % | 5 / 11 | 45 % | products: D7 names EdDSA with Curve25519 but not Ed25519 explicitly (1 ambiguous); 6 not listed | P4 is software; D10 is a reference-manual section |
| F2 Ed448 | 1 / 10 | 10 % | 1 / 11 (P3) | 9 % | products: 9 not listed | n too small for a percentage to mean much |
| F3 ECDSA | 6 / 10 | 60 % | 2 / 11 (P1, P6) | 18 % | D6 ambiguous (accelerates ECDSA-class operations, p. 47, no sign/verify statement); 3 not listed | D4 cites FIPS 186-3 ECDSA (p. 9) |
| F4 ML-DSA | 2 / 10 | 20 % | 4 / 11 (P8-P11) | 36 % | products: 8 not listed | Non-lattice PQ signature P7 not counted here |
| F5 Side-channel protection | 6 / 10 | 60 % | 6 / 11 (P2, P3, P4, P5, P6, P8) | 55 % | D1 p. 11 lists attack classes (ambiguous) | Vendor claims, no measured evidence in briefs |
| F6 Fault-injection protection | 0 / 10 | 0 % | 4 / 11 (P5, P9, P10, P11) | 36 % | products: D1, D4 mention fault or physical attacks as a threat only (2 ambiguous) | 3 of the 4 papers are attacks, not defences |
| F7 Standards claim (FIPS 186-5, RFC 8032, or FIPS 204) | 3 / 10 | 30 % | n/a | n/a | D4 cites FIPS 186-3 | Only Xiphera briefs name current editions |
| F9 External dependency stated | 2 / 10 | 20 % | n/a | n/a | D3 states SHA-3/SHAKE inside the core (p. 2 figure) | Silence is not evidence of internal hashing |

Counting rules used: a family counts for F1 only if its document names Ed25519; F5 counts only an explicit claim in the product document; F6 counts only an explicit countermeasure statement, which no product gives. Sensitivity: if D7 and D6 ambiguities were counted as presence, F1 would be 4/10 and F3 would be 7/10. Hardware-versus-software split of the papers: 6 describe hardware (P1, P2, P3, P5, P6, P7) and 5 are software or algorithmic (P4, P8, P9, P10, P11).

Product availability, scholarly attention and application value are kept separate: the contrast "ECDSA common in products, Ed25519 common in hardware papers" is a corpus fact, not a statement about demand.

## 6. System architecture and microarchitecture

Figure: [`../spec/figures/signature_engine_architecture.drawio`](../spec/figures/signature_engine_architecture.drawio). Legend: solid = documented in at least one source; dashed = inferred; "?" = unknown. The figure is a **composite** of blocks named in several briefs, not the architecture of any one product.

Documented organisation by family (each statement is from the cited page):

- **Programmable arithmetic engine with microcode (D2, D5, D9, P5).** D2 p. 2 figure: dual-port RAM, arithmetic logic unit (ALU) and hierarchical control logic with command and response ports. D5 p. 3 figure: dual-port data memory, control logic, ALU and register bank, program read-only memory (ROM), a user and a "privileged" input/output (I/O). D9 p. 1: program ROM, constant ROM, coprocessor with register banks, input data memory interface and output register bank, "hardwired program in the program ROM". P5 abstract: a micro-code supported instruction set, one arithmetic unit for two moduli, in-place memory management, DSP slices.
- **Lattice engine (D3, D8).** D3 p. 2 figure: SHA-3/SHAKE, samplers, encoders/decoders, multi-port RAM bank, a datapath for the (inverse) number-theoretic transform and polynomial arithmetic, control, constant ROM. D8 p. 1: a hardware lattice accelerator with dedicated RAM plus a software library on a CPU, with SHA-3/SHAKE, DMA and TRNG as separate IPs.
- **Scalable public-key core (D7).** D7 p. 1 figure: a DPA-countermeasure block, a bus bridge (AMBA APB/AHB/AXI), a scalable DSP array, a sequencer and data RAM; "100 % CPU offload" (p. 2).
- **Operation set.** D2 p. 1: constant-time x-coordinate-only scalar multiplication (Montgomery ladder) and constant-time **fixed-base** scalar multiplication for Ed25519 signing. D5 p. 2: key generation, Diffie-Hellman shared secrets, ECDSA sign and verify, input-point validation, and a guard against nonce reuse.
- **Software contract.** Most briefs give a command/response or start/busy style port without register maps (D2, D3, D5); registers are not documented in any brief, so register-level behaviour is **unknown**.
- **Error handling and diagnostics.** Only D5 p. 2 mentions input validation and nonce-misuse prevention; D8 p. 2 mentions optional health tests. Other briefs do not describe error reporting (unknown).

Inferred, not documented: the shared reuse of one datapath for several curves is stated by P1 and P6 for their designs, not by the product briefs; any shared RAM between signing and hashing in D2/D5 is not stated.

## 7. Integration and physical interface requirements

None of the sources describes an off-chip pad or physical-layer interface for the signature block itself; the blocks are internal SoC IP, so pad, voltage, termination and package rows are **unknown by scope**, not omitted. D1, D4 and D10 describe standalone chips or MCU peripherals whose pin-level detail is outside the pages read.

| Feature / interface | Local block | External peer | Protocol / logical contract | Pad / PHY / electrical evidence | Clock / reset / power | Package / board / process | Open integration questions |
|---|---|---|---|---|---|---|---|
| Host port, AMBA (D7, D8) | Signature core | SoC CPU or DMA | APB/AHB/AXI wrapper (D7 p. 1; D8 p. 2) | unknown (internal) | not stated | "all ASIC and FPGA technologies" (D7 p. 1) | Wrapper version, burst behaviour, error response |
| Host port, narrow custom (D2, D5, D3) | Core command port | Wrapper written by the integrator | 16-bit (D2, D5) or 64-bit (D3) data, start, busy, valid | unknown (internal) | clk, rst (D2 p. 2; D3 p. 3); frequency not stated in briefs | FPGA resource tables are for Lattice FPGAs (D2, D5) | Who adds the register file and interrupts |
| Key-store interface (D2) | Core | Secret-key store | `sks_*` port (D2 p. 2) | unknown | not stated | not stated | Key lifetime and wipe behaviour |
| Hash and random-number sources (D5, D8) | Signature core | External hash, RNG, DMA | External per D5 p. 2, D8 p. 1 | unknown | not stated | not stated | Interface contract, entropy quality, latency |
| Memory interface (D9) | Core | External data memory | Input data memory interface and output register bank (D9 p. 1) | unknown | Fmax up to 40 MHz on Artix-7 and 8 MHz on 180 nm (D9 p. 1) | xFab 180 nm named | Memory map, handshake |
| Chip-level secure element (D1, D4) | Device | Host MCU | Interface not read in the pages checked | unknown | not stated | Not read | Out of scope for IP integration |

## 8. Configuration, registers and software usability

- **Documented in briefs:** configuration choices exist (curve, mode, security level) but no register map, driver API or initialisation sequence is documented in D2, D3, D5, D7, D8 or D9. Full datasheets are "available on request" (D2 p. 2, D5 p. 2), so the register-level and software-usability evidence needed for rule R-012 is **missing for the commercial IP cores**.
- **Supported modes worth carrying into a specification:** hedged and deterministic signing and pre-hash (D3 p. 1); non-exclusive key generation, sign and verify per function set (D1 p. 1, D5 p. 2); an optional health test (D8 p. 2).
- **Software dependency:** D8 needs a software library; D10 uses microcode loaded into crypto-engine SRAM (p. 2: "Flexible Microcode Update Using the Crypto Engine SRAM"), which implies a software-managed firmware load.
- **Diagnostics and failure handling:** only input validation and nonce-reuse prevention are documented (D5 p. 2). Verification-failure reporting and sticky error flags are not documented anywhere in the corpus.

## 9. Licensing, patent and dependency review

Lookup date: 2026-11-24. This section is not legal advice and gives no clearance.

| Item | Evidence | Status / uncertainty |
|---|---|---|
| Document copyright | Vendor documents carry vendor copyright; manifest `license_notice` is "Not stated; review source notice" for all datasheets. Open-access papers: P1, P7, P9, P11 state CC BY 4.0 on their first pages; P2, P3, P4 are IEEE-copyright accepted manuscripts from NSF Public Access; P5, P6, P8, P10 licence not read | Local copies are retained for research only; none is redistributed (rule R-018) |
| Implementation licence | Xiphera sells netlist/source delivery (search result for D2; not in the saved brief), Secure-IC delivers an AMBA wrapper RTL plus libraries (D8 p. 2); TES, Infineon and Microchip documents state no IP licence terms | Commercial terms unknown; no open-source RTL licence examined |
| Standards access terms | RFC 8032 (Informational, per search result on datatracker); FIPS 186-5 published by the U.S. Department of Commerce (Federal Register, 2023-02-03); FIPS 204 final on 2024-08-13 (D3 p. 1) | Freely readable; implementation licence is separate |
| Standards still evolving | FIPS 206 (FN-DSA, Falcon) was reported as a draft in secondary sources; **not verified on the NIST site**. NIST SP 800-208 (LMS/XMSS) and the National Security Agency CNSA 2.0 signature timeline were **not searched** | Unchecked revisions; check before fixing algorithm scope |
| Patents | The search tool used is a web search engine, not a patent database. Two patent numbers appeared as titles in search results (US 11,251,973 "Efficient calculation of ED25519/448 signature verification in an encryption device"; US 12,381,742 "Side channel attack resistant cryptographic accelerator"), but neither assignee, claim nor legal status was retrieved | **Unresolved.** Jurisdictions not searched: all except the United States title hits; European Patent Office, China National Intellectual Property Administration, Japan Patent Office: not checked. A missing hit is not evidence of freedom to operate |
| Third-party dependencies | Hash (SHA-3/SHAKE inside the ML-DSA core per D3 p. 2 figure; for Ed25519 and Ed448 RFC 8032 uses SHA-512 and SHAKE256 respectively, general knowledge not read from this corpus), random-number source and DMA are separate blocks (D5 p. 2, D8 p. 1) | Their licences and verification status would add to the dependency list |

## 10. Opportunities for new or improved features

Novelty is a hypothesis pending broader prior-art and legal review.

| Proposal | Unmet need and evidence | User / software benefit | Architecture and integration change | PPA, security and compatibility risks | Licensing uncertainty | Validation experiment | Confidence |
|---|---|---|---|---|---|---|---|
| A. Optional fault countermeasure in an Ed25519 signer (for example double computation plus verify-after-sign, parameterised, default off) | 0 of 10 products state fault protection (section 5); papers show practical fault attacks on lattice signatures including hedged mode (P9, P10, P11) and offer a fault option in an Ed25519 core (P5). Fault attacks on Ed25519 itself are not in the qualified corpus | Detects faulty signatures before release; lets integrators in safety or physical-access settings enable the check | Redundant datapath or a verification pass, a fault flag in the status register, a block-level reset on mismatch | Roughly doubles time or area when enabled (not measured); a mismatch signal can itself be a side channel; not required by RFC 8032 | Prior-art search needed; patent coverage unknown | Inject single-bit faults in an RTL simulation or FPGA and measure the fraction detected; compare area and latency with the unprotected core | medium for need, low for cost |
| B. A single signature engine with parameter-selected Ed25519, ECDSA P-256 and optionally Ed448, sharing one datapath and the hash | Papers show multi-algorithm single cores are feasible (P1: Ed25519 plus ECDSA P-256/384/521 with 10,259 slices on Virtex-7; P6: P-256, Ed25519, Curve25519); 4 of 10 product families list EdDSA while 6 of 10 list ECDSA | One integration and one driver for both signature families; fewer blocks in a secure-boot path | Shared arithmetic unit for two moduli, curve-select parameter, common hash interface | Area growth over a single-curve core; constant-time rules differ by curve (D5 p. 2 stresses constant time and operation-pattern independence) | Standards terms differ: FIPS 186-5 covers both | Synthesise Ed25519-only versus combined and compare area, latency and verification results against RFC 8032 and FIPS 186-5 vectors | medium |
| C. Verify-only low-area variant for secure boot | D1 p. 1-2 and D8 p. 2 name secure boot; the briefs do not separate sign and verify area (unknown) | Smaller IP where only verification is needed, with no secret-key handling | Remove key store and scalar-multiplication paths that are only used for signing; keep point decoding and checks | Verification needs variable-base multiplication and point validation, so the saving is smaller than "half a core" (P3: 327 signatures and 189 verifications per second at the same hardware, suggests verification is slower on that design); malleability and cofactor handling must follow the chosen rule | Same | Compare area of sign-capable and verify-only RTL on the same FPGA and ASIC library | low |
| D. Hybrid classical plus ML-DSA verification (Ed25519 together with ML-DSA) | D8 p. 2 and D3 p. 2 give ML-DSA for secure boot; no product in the corpus documents a hybrid signature check. A secure-boot hybrid core (Xiphera XIP7410B) appeared in a web-search result only and is not in the qualified corpus | Quantum transition path while keeping classical assurance | Shared SHA-3/SHA-512 hashing, shared RAM, two verification paths with an AND-combiner | Large area increase for ML-DSA; combining rules not standardised in this corpus | Unknown | Prototype on FPGA and measure resources and boot-time impact | low |

## 11. Trade-offs and recommendation

Options for the first IP version (no more than three):

1. **Ed25519 sign and verify, RFC 8032 pure mode, single curve (recommended start).** Smallest scope; matches the corpus gap that product briefs name Ed25519 less often (3 of 10) than ECDSA (6 of 10) while the hardware papers cover it most (5 of 11). Risk: lower product breadth.
2. **Multi-curve (Ed25519, Ed448, ECDSA P-256) single engine.** Broader coverage, higher area and verification cost; supported by P1 and P6 as feasible. Risk: schedule and constant-time effort per curve.
3. **Add ML-DSA later as a separate engine.** Lowest reuse with the elliptic-curve datapath (D3 shows a different datapath: number-theoretic transform, samplers, SHA-3); shared hashing may be the only common block (inference).

Decision criteria: target application, required algorithm list, area budget and whether fault protection is needed. The recommendation is **provisional** because no application was fixed by the user and no measured area or power data exists for any option.

## 12. Risks, gaps and next research steps

- **Source conflicts.** A web-search snippet quoted XIP4003C as "2804 logic elements (ECP5)"; the saved brief states "43213 logic elements (MAX 10)" (D2 p. 1). The brief was used; both numbers are vendor claims and neither was independently confirmed.
- **Corpus gaps.** No NXP, STMicroelectronics, Nordic, Silicon Labs or Rambus document was retrieved (404 or 403 or no direct PDF). No SLH-DSA, LMS/XMSS or FN-DSA hardware source. Only one general-purpose MCU datasheet and it does not document a signature function.
- **Depth gaps.** Paper counts are abstract-level (L5); briefs omit registers, latency, throughput under stated conditions, and error behaviour.
- **Rights and patents.** Patent search was not performed in a patent database; jurisdictions other than United States title hits unchecked; FIPS 206, NIST SP 800-208 and CNSA 2.0 not verified.
- **Requested files not downloaded.** ePrint 2020/1244, ePrint 2025/621, the FDTC 2017 PDF, the Silicon Labs EFR32BG2B data short and the ATECC608B datasheet were blocked; a user-authorised manual download could be registered as `user-authorized`.
- **Next steps.** Obtain complete datasheets of D2, D3, D5 (on request); register user-downloaded blocked papers; search a patent database with a qualified person; verify FIPS 206, SP 800-208 and CNSA 2.0 on the NIST and National Security Agency sites; add SLH-DSA, LMS and XMSS hardware papers; fix the application context before sizing.

## 13. Abbreviations and references

Glossary (scope: this report).

| Term | Meaning |
|---|---|
| AMBA, APB, AHB, AXI | Advanced Microcontroller Bus Architecture; Advanced Peripheral Bus; Advanced High-performance Bus; Advanced eXtensible Interface |
| ASIC, FPGA | Application-Specific Integrated Circuit; Field-Programmable Gate Array |
| CAVP | Cryptographic Algorithm Validation Program of the U.S. National Institute of Standards and Technology (NIST) |
| CPA, DPA, SPA, DEMA, CEMA | Correlation, Differential and Simple Power Analysis; Differential and Correlation Electromagnetic Analysis (side-channel attacks that measure power or emissions) |
| DMA, TRNG | Direct Memory Access; True Random Number Generator |
| ECDSA | Elliptic Curve Digital Signature Algorithm (FIPS 186-5) |
| EdDSA, Ed25519, Ed448 | Edwards-curve Digital Signature Algorithm and its two parameter sets (RFC 8032, FIPS 186-5) |
| FIPS | Federal Information Processing Standard |
| FN-DSA, ML-DSA, SLH-DSA | Fast-Fourier-transform-over-NTRU-lattice Digital Signature Algorithm (Falcon, FIPS 206 draft); Module-Lattice-Based Digital Signature Algorithm (FIPS 204); Stateless Hash-Based Digital Signature Algorithm (FIPS 205) |
| LMS, XMSS | Leighton-Micali Signature; eXtended Merkle Signature Scheme (stateful hash-based signatures, NIST SP 800-208) |
| IP, SoC, MCU, IoT | Intellectual Property; System-on-Chip; Microcontroller Unit; Internet of Things |
| NTT | Number-theoretic transform |
| PQC | Post-quantum cryptography |
| ROM, RAM | Read-only memory; random-access memory |
| TCHES, TVLSI, TCAS, TRETS, DDECS | IACR Transactions on Cryptographic Hardware and Embedded Systems; IEEE Transactions on Very Large Scale Integration Systems; IEEE Transactions on Circuits and Systems; ACM Transactions on Reconfigurable Technology and Systems; IEEE Symposium on Design and Diagnostics of Electronic Circuits and Systems |

References: all source documents are listed in section 3 and in `vlsit_source_manifest.csv` with URL, SHA-256 hash and acquisition time. Standards and status lookups made on 2026-11-24: RFC 8032 (IETF datatracker, searched), FIPS 186-5 final notice (Federal Register, 2023-02-03), FIPS 204 date (D3 p. 1), FIPS 206 draft status (secondary sources, not verified), SP 800-208 and CNSA 2.0 not searched.

## Limits and rule check (R-024, R-025)

- L1 Counts reflect 10 product families and 11 papers; several of the briefs (D2, D3, D5, D7, D8, D9) are marketing-level documents.
- L2 D10 is a reference-manual section and D1 a summary; both are flagged.
- L3 No measured data beyond vendor and paper claims; no result was reproduced.
- L4 Patent and standards coverage is incomplete (section 9).
- L5 Paper-level counts are abstract-level; a deep reading may change them.
- L6 The application context was never confirmed by the user.
- Mechanical gate: `READY` (script). Manual items still to be audited by a person: citation locators, feature counts, licences, diagram labels.
