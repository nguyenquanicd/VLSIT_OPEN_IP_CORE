# Specification review of m_chacha_top - 2026-11-24

## 1. Summary

| Item | Value |
|---|---|
| Design | `m_chacha_top` (027_ChaCha) |
| Review | Specification review |
| Date | 2026-11-24 |
| Findings | 30 |
| Critical | 0 |
| High | 16 |
| Medium | 8 |
| Low | 6 |
| Waivable | 2 |
| Fixable | 28 |
| Score and verdict | weighted 3.00 of 5, Conditional (details in `REVIEW_CHACHA.md`) |
| Gate | PASS |

Severity scale of this report: Critical, High, Medium and Low correspond to the Blocker, Major, Minor and Observation of the scorecard. The reviewed file is `spec/VLSIT_CHACHA_HDS.md`; evidence locators are line numbers of that file. The reviewer is also the author of the specification.

## 2. Findings

Each finding has an assessment, a verdict and, when it can be fixed, the change and the reason it works. The 'RTL change' of a specification review is the specification or RTL contract change that the finding implies; no RTL exists yet.

### F-001 Every application number is the author's example

- Evidence: `VLSIT_CHACHA_HDS.md:2660` (§1.4, ASM-002, ASM-003)
- Severity: `High` (scorecard: Major, FACT)
- Group: open-decisions
- Assessment: The frame size (127 B), image block (1280 B), latency (tens of microseconds) and the link rate (1 to 5 Mbit/s) are recorded as assumptions ASM-002 and ASM-003; the user answered 'you decide', and no source in the research report covers the embedded-link case. The throughput target is TBD-001, so no configuration can be sized against a demand.
- Verdict: `fix`
- Fix: Obtain the real product numbers (message sizes, latency budget, link rate, core clock) from the user, replace ASM-002 and ASM-003, and close TBD-001 with a target in Gbit/s and a default frequency.
- Why: Sizing of FIFO depth, `PARA_MSG_MAX_B`, the default configuration and the pass criterion of TEST-019 all depend on these numbers.

### F-002 Feature table has no requirement mapping

- Evidence: `VLSIT_CHACHA_HDS.md:70` (§1.3 table, 21 cells)
- Severity: `Medium` (scorecard: Minor, FACT)
- Group: traceability
- Assessment: All nine FEAT rows carry 'Pending' in the Requirements column although REQ-FUNC, REQ-IF, REQ-CLK, REQ-REG, REQ-PARAM, REQ-ERR, REQ-PERF and REQ-SEC exist in section 3, so a feature cannot be traced to its requirement.
- Verdict: `fix`
- Fix: Fill the Requirements column with the REQ identifiers (FEAT-001: REQ-FUNC-001 to 006; FEAT-004: REQ-IF-002 to 005, 010; FEAT-005: REQ-IF-006 to 008; and so on) and add a FEAT-to-REQ check to the traceability table of section 19.
- Why: A feature with no requirement is a marketing line (review framework, area 2); the mapping makes the omission visible.

### F-003 Stand-alone ChaCha20 and Poly1305 are not offered

- Evidence: `VLSIT_CHACHA_HDS.md:2666` (§1.1, DEC-003)
- Severity: `Low` (scorecard: Observation, INFERENCE)
- Group: features-scope
- Assessment: DEC-003 limits the IP to the full AEAD, while the sampled Secure-IC engine D1 offers stand-alone encryption, stand-alone authentication and context switching. The storage-encryption use named earlier in the project needs a stand-alone cipher.
- Verdict: `waive`
- Why: The decision keeps the verification scope small; the risk is a later interface change.
- Risk: Accepted by the user decision DEC-003 on 2026-11-23; revisit if inline storage encryption becomes a requirement.
- Owner: user (product owner)
- Invalidation: A storage or stand-alone MAC use case is added to the product requirements.

### F-004 Boundary between associated data and message data is undefined

- Evidence: `VLSIT_CHACHA_HDS.md:2702` (§6.3, §10.2, TBD-018)
- Severity: `High` (scorecard: Major, INFERENCE)
- Group: open-decisions
- Assessment: The IP counts the first aad_len bytes as associated data, but it is not decided whether each part starts on a new beat or the parts are packed, nor how WSTRB marks a partial last beat. The packing logic, the padding to 16 bytes for Poly1305 and the software rule all depend on it.
- Verdict: `fix`
- Fix: Decide start-on-new-beat (software pads, WSTRB marks valid bytes of the last beat of each part) and write it as a REQ-FUNC requirement with a worked example from RFC 8439 section 2.8.2 in 32-, 64- and 128-bit windows.
- Why: Start-on-new-beat keeps the packer to byte-lane masking and makes the beat count of each part a simple division, which the DMA tail rule also needs.

### F-005 Key capture and an invalid key have no defined behavior

- Evidence: `VLSIT_CHACHA_HDS.md:2705` (§10.1, TBD-009, TBD-022)
- Severity: `High` (scorecard: Major, FACT)
- Group: open-decisions
- Assessment: The key-store port is provisional (a 256-bit value with one valid bit, no ready, no slot selection, clock domain assumed), and a start with the key not valid is rejected with no event. The ENUM_ST_KEY timing cannot be specified without the port protocol.
- Verdict: `fix`
- Fix: Define the port with the key-store owner (valid/ready or request/acknowledge, slot index, revocation) and add a `key_err` event or reuse `ctr_err`; then specify the ENUM_ST_KEY sampling cycle and a waveform.
- Why: The key interface is the security boundary; leaving it implicit makes the zeroization and the isolation claims unverifiable.

### F-006 DMA four-phase handshake has no cycle-level contract

- Evidence: `VLSIT_CHACHA_HDS.md:2687` (§6.3, TBD-004)
- Severity: `High` (scorecard: Major, FACT)
- Group: open-decisions
- Assessment: The handshake is project-defined and only its four phases are stated; the timing of the acknowledge release against the data beats, the request granularity and the DMA controller capability are open, and WF-007 to WF-009 draw an assumed ack release after the burst.
- Verdict: `fix`
- Fix: Write the rules per phase (earliest and latest cycle between req, ack, the first and last beat, minimum low time), get the integrator's DMA controller documentation, and turn SVA-001 into the exact property.
- Why: An external DMA controller must be built against a numbered rule; the current text cannot be checked by an assertion.

### F-007 AXI4 profile and transfer rules are not closed

- Evidence: `VLSIT_CHACHA_HDS.md:2708` (§6.2, ASM-007, TBD-015)
- Severity: `High` (scorecard: Major, FACT)
- Group: open-decisions
- Assessment: Narrow transfers (AxSIZE), the use of WSTRB, ID rules and the outstanding capacity are open; the profile (Required signals plus WLAST, BRESP, RRESP) is the author's proposal ASM-007, while Arm IHI 0022H.c section A9.3 suggests that a component include all signals for reuse.
- Verdict: `fix`
- Fix: Fix the profile: AxSIZE shall equal the data width (otherwise SLVERR), WSTRB all ones except the last beat of a part, one outstanding transaction per direction, and decide whether to tie-off optional signals at the top.
- Why: A fixed set of accepted transfer shapes bounds the burst checker and the verification matrix.

### F-008 Single-cycle events cross asynchronous clocks without a stated structure

- Evidence: `VLSIT_CHACHA_HDS.md:866` (§7.2, CDC-006, CDC-007)
- Severity: `High` (scorecard: Major, INFERENCE)
- Group: cdc-reset
- Assessment: CDC-006 and CDC-007 cross one-cycle event pulses (axi_err, the interrupt) between asynchronous domains by 'pulse synchronizers'. A pulse shorter than the destination period can be lost when the destination clock is slower, and the specification states neither a stretch, a toggle structure nor a minimum ratio.
- Verdict: `fix`
- Fix: Specify the structure as a toggle (or request/acknowledge) crossing with the event held until acknowledged, add the cell from `000_Common`, and add an SVA that no event is lost for every clock ratio of TEST-015.
- Why: A toggle crossing is correct for any ratio, while a plain pulse synchronizer is correct only when the destination is faster.

### F-009 Reset in a single domain is not specified

- Evidence: `VLSIT_CHACHA_HDS.md:2710` (§7.3, TBD-017)
- Severity: `High` (scorecard: Major, FACT)
- Group: cdc-reset
- Assessment: Release order core, AXI, APB is stated, but the effect of a reset asserted in one domain only (message in progress, FIFO pointers, half-finished DMA handshake, APB request in flight) is open, and no reset sequencing hardware is named.
- Verdict: `fix`
- Fix: Adopt a rule: a reset of any one domain resets the message sequencer and both window buffers through the coordinated software-reset handshake of the library FIFOs, drops the DMA requests, and is reported by an event; add TEST-016 cases for every domain.
- Why: The library FIFOs already carry a coordinated reset, so the rule reuses a checked mechanism instead of inventing one.

### F-010 Parameter defaults contradict the stated application

- Evidence: `VLSIT_CHACHA_HDS.md:902` (§8 table, §10.4, ASM-002)
- Severity: `High` (scorecard: Major, FACT)
- Group: defaults
- Assessment: PARA_FIFO_OUT_DEPTH is 16 beats of 64 bits (128 B) and PARA_MSG_MAX_B is 65535, while ASM-002 assumes 1280 B messages. In release mode a polling master that writes a 1280 B message before reading deadlocks (section 10.4), and the hold mode (PARA_HOLD_EN = 1) is an illegal combination with these defaults.
- Verdict: `fix`
- Fix: Set the delivered defaults to values that make both modes legal for the stated application and show a worked legal hold configuration.
- Why: With a 64-bit window, 256 beats give 2 KiB, which holds a 1280 B result; limiting PARA_MSG_MAX_B to 1280 satisfies the elaboration rule of section 8.

```systemverilog
// Parameter Description: Maximum accepted message length
// Parameter values: 64 to 65535, default 1280
// Parameter unit: byte
parameter logic [31:0] PARA_MSG_MAX_B     = 32'd1280,
// Parameter Description: Output window depth
// Parameter values: 4 to 16384, power of two, default 256
// Parameter unit: beat of PARA_AXI_DW bits
parameter logic [31:0] PARA_FIFO_OUT_DEPTH = 32'd256,
```

### F-011 Default of PARA_POLY_ARCH is stated twice

- Evidence: `VLSIT_CHACHA_HDS.md:897` (§8 table, §4 CFG-BASE)
- Severity: `Medium` (scorecard: Minor, FACT)
- Group: defaults
- Assessment: The parameter table gives 'TBD-003' as the default of PARA_POLY_ARCH, while CFG-BASE in sections 4 and 8 sets it to 1, so the delivered default is not defined in one place.
- Verdict: `fix`
- Fix: Set the default to 1 in the table and keep TBD-003 only as the reason to revisit it.
- Why: One value in the table removes the contradiction without deciding TBD-003.

### F-012 Byte order and nonce word placement are unconfirmed

- Evidence: `VLSIT_CHACHA_HDS.md:2691` (§9, ASM-010)
- Severity: `Medium` (scorecard: Minor, INFERENCE)
- Group: open-decisions
- Assessment: The little-endian lane order of the window stream and the placement of the salt and counter in the hardware nonce are the author's choices; a software team reading the window the other way round would break interoperability silently.
- Verdict: `fix`
- Fix: Confirm with the software owner and add the byte-level mapping of the RFC 8439 section 2.8.2 vector (key, nonce, AAD, plaintext) to section 9 as a worked example.
- Why: A worked vector is the quickest check of an endianness assumption.

### F-013 No critical-path statement for the two-round and parallel-multiplier options

- Evidence: `VLSIT_CHACHA_HDS.md:903` (§8, §13, §14)
- Severity: `High` (scorecard: Major, INFERENCE)
- Group: timing
- Assessment: PARA_RND_CYC = 2 chains eight quarter rounds (each an add, XOR and rotate in series) in one cycle, and PARA_POLY_ARCH = 2 uses a 130 by 128 bit multiplier. Neither the RTL contract nor section 13 states an estimated logic depth or a frequency range, so CFG-HP may close only at a fraction of the frequency that its throughput figure assumes.
- Verdict: `fix`
- Fix: Add a logic-depth estimate per configuration (adder depth, XOR and rotate levels) to section 13, state the expected frequency ratio between the three configurations, and restrict the quoted Gbit/s per GHz of CFG-HP to the frequency that the estimate supports.
- Why: The throughput per GHz is only meaningful at a frequency that the datapath can reach.

### F-014 The SDC is promised but not delivered

- Evidence: `VLSIT_CHACHA_HDS.md:2699` (§17.1, TBD-023)
- Severity: `High` (scorecard: Major, FACT)
- Group: timing
- Assessment: Section 17.1 says the constraint file is part of the delivery; `sdc/` holds only a placeholder, every period is a parameter, and the 60/40 budget split is the author's proposal ASM-008.
- Verdict: `fix`
- Fix: Write `sdc/chacha_top.sdc` with the three clock definitions, the clock groups per configuration, EXC-001 to EXC-005 and the parameters as Tcl variables; complete the numbers when TBD-002 is decided.
- Why: A parameterized file lets the CDC and timing flows run before the frequency is chosen.

### F-015 The datapath-only delay bounds are not validated

- Evidence: `VLSIT_CHACHA_HDS.md:2562` (§17.1.3, EXC-002 to EXC-004)
- Severity: `Medium` (scorecard: Minor, INFERENCE)
- Group: timing
- Assessment: EXC-002 to EXC-004 use `set_max_delay -datapath_only` with 'less than one period of the faster clock'. The value does not account for the pointer skew of a Gray code or for the generated register-block handshake, whose adapter model is a placeholder.
- Verdict: `fix`
- Fix: State the numeric rule (for example the smaller of the two periods minus the skew budget), take the library FIFO constraints as the reference, and check the result with the CDC tool.
- Why: The bound is what keeps a Gray pointer from changing more than one bit between two samples.

### F-016 Area and power are proxies with no target

- Evidence: `VLSIT_CHACHA_HDS.md:2367` (§13 state proxy table)
- Severity: `Low` (scorecard: Observation, FACT)
- Group: timing
- Assessment: The declared-state proxy (2591, 3615 and 6175 bits) is labelled as a proxy and excludes combinational logic; the sequencer bits (about 150) are the author's estimate; power has no target or activity.
- Verdict: `fix`
- Fix: Replace the proxy with mapped area and power from a named library once RTL exists; until then no area or power claim should be quoted outside the specification.
- Why: A proxy presented as mapped area misleads cost decisions (rule R-008).

### F-017 Throughput is bounded for ChaCha20 only and the requirement is not testable

- Evidence: `VLSIT_CHACHA_HDS.md:173` (§13 PERF-001, REQ-PERF-001, TEST-019)
- Severity: `High` (scorecard: Major, FACT)
- Group: performance
- Assessment: The Gbit/s per GHz figures (6.4 to 102.4) bound the ChaCha20 path; the Poly1305 cycles per 16-byte block are unquantified (TBD-003) and Poly1305 is a serial accumulation. REQ-PERF-001 is a 'should' with a 'small fixed overhead' that no section defines, so TEST-019 has no pass criterion.
- Verdict: `fix`
- Fix: Build the cycle model first, state Poly1305 cycles per block for the three architectures, set a numeric overhead for the sequencer, and rewrite REQ-PERF-001 as a 'shall' with numbers for CFG-BASE.
- Why: The slowest of ChaCha20, Poly1305 and the interface width sets the sustained rate, so all three must be quantified before the requirement can be verified.

### F-018 Per-message cost is unquantified for the short-frame use

- Evidence: `VLSIT_CHACHA_HDS.md:2365` (§10.4, PERF-002)
- Severity: `Medium` (scorecard: Minor, INFERENCE)
- Group: performance
- Assessment: Each message pays a one-time key block (20 cycles for CFG-BASE as a ChaCha20 bound) plus the fixed steps, which dominates frames of 8 to 64 bytes; PERF-002 has no number and no source of the research report measures it.
- Verdict: `fix`
- Fix: State the cycles from start to the first output beat for a 16-byte and a 64-byte message in each configuration, and set a latency requirement.
- Why: The link use case in ASM-003 is dominated by this cost, not by the asymptotic rate.

### F-019 Workable flow with polling and nonce discipline left to software

- Evidence: `VLSIT_CHACHA_HDS.md:2235` (§11.2 S05 and S09)
- Severity: `Low` (scorecard: Observation, INFERENCE)
- Group: traceability
- Assessment: The 14-step flow, the 16 registers and the capability register give a clear driver contract; the software-nonce default leaves nonce uniqueness to the driver, and start acceptance needs two reads (start, then busy).
- Verdict: `fix`
- Fix: Provide a reference driver sequence (pseudocode) with the nonce counter policy in the integration guide when the IP is delivered.
- Why: A tested driver sketch prevents the most common integration mistake, nonce reuse.

### F-020 No scan architecture and no test-controllable reset

- Evidence: `VLSIT_CHACHA_HDS.md:2698` (§16, TBD-025)
- Severity: `High` (scorecard: Major, FACT)
- Group: dft
- Assessment: The only test port is `i_dft_test_en`; the scan ports, scan mode, the reset override required by rule RST-04 and the test-mode priority are open, so the wrapper that owns the reset override cannot be written.
- Verdict: `fix`
- Fix: Agree the scan methodology with the SoC DFT owner, add `i_dft_scan_*` ports and a test reset override port to section 6.2, and put the override in the reset-synchronizer wrapper.
- Why: Reset controllability is a precondition of scan coverage; adding ports later changes the top-level interface.

### F-021 The data window has no access control

- Evidence: `VLSIT_CHACHA_HDS.md:2601` (§18 access control, TBD-005)
- Severity: `High` (scorecard: Major, FACT)
- Group: security
- Assessment: The register block can reject a non-secure access, but the AXI4 profile has no protection signal (ASM-007), so any master that reaches the window can read results or feed data; the key-store and firewall decisions do not exist yet.
- Verdict: `fix`
- Fix: Decide between adding AxPROT to the profile and checking it, or requiring an interconnect firewall in the integration guide; state the choice as a requirement and add a test.
- Why: In a security MCU the data window is part of the trust boundary; an implicit assumption that the fabric enforces access control is the common failure.

### F-022 Nonce reuse is not prevented in the delivered default

- Evidence: `VLSIT_CHACHA_HDS.md:2703` (§18, §9, TBD-019, REQ-SEC-001)
- Severity: `High` (scorecard: Major, INFERENCE)
- Group: security
- Assessment: RFC 8439 section 2.6 forbids reusing a nonce under one key. In the software-nonce build the IP has no guard, and the hardware counter rule (invalid after reset, monotonic, persistence) is a proposal under TBD-019, not a decision.
- Verdict: `fix`
- Fix: Adopt the TBD-019 rule (counter invalid until loaded, never decreasing) and, in the software-nonce build, add an optional comparator that rejects a nonce equal to the previous one under the same key; decide on persistence.
- Why: A nonce repeat breaks confidentiality and authenticity of the affected messages, so a cheap guard is worth the area.

### F-023 Insecure behavior is the default

- Evidence: `VLSIT_CHACHA_HDS.md:903` (§8 PARA_HOLD_EN, §18)
- Severity: `Medium` (scorecard: Minor, INFERENCE)
- Group: defaults
- Assessment: PARA_HOLD_EN defaults to 0, so a decryption streams unauthenticated plaintext to the host; for a security-oriented microcontroller the safe behavior should be the default.
- Verdict: `fix`
- Fix: Default PARA_HOLD_EN to 1 together with the buffer sizing of the parameter finding, and document release mode as an opt-in.
- Why: The default configuration is the one most integrators ship unchanged.

### F-024 No protection against physical attacks

- Evidence: `VLSIT_CHACHA_HDS.md:2700` (§18 side channels, TBD-024)
- Severity: `Low` (scorecard: Observation, FACT)
- Group: security
- Assessment: Power analysis, fault injection and a malicious bus master are listed as not addressed; the sampled SoC data sheets D5 to D7 apply DPA countermeasures to AES and ECC only, and source P3 shows a masked variant with an area and throughput cost.
- Verdict: `waive`
- Why: The gap is consistent with the sampled commercial practice and is documented, so it is a scope decision, not an error.
- Risk: Accepted for this release: the specification states the gap; reconsider if the product certification or threat model includes physical access.
- Owner: user (product owner)
- Invalidation: The target attacker model or a certification requires resistance to power analysis or fault injection.

### F-025 The verification plan is complete on paper only

- Evidence: `VLSIT_CHACHA_HDS.md:2461` (§15, verification/)
- Severity: `Medium` (scorecard: Minor, INFERENCE)
- Group: verification
- Assessment: Every requirement has a test (0 requirements without a test, 24 tests, 10 SVA, 8 COV), but `verification/` holds placeholders, the independent model, the DMA and key-store models and the AXI4 checker do not exist, and the formal tool is not chosen. The spec author also wrote the plan, so independence is not shown.
- Verdict: `fix`
- Fix: Create the RFC 8439 reference model and run it against the three RFC vectors before any RTL; have the model and the testbench written by a person other than the RTL author.
- Why: The RFC vectors are the cheapest independent check of the datapath.

### F-026 38 open items, at least eight block RTL generation

- Evidence: `VLSIT_CHACHA_HDS.md:2684` (§20, inventory)
- Severity: `High` (scorecard: Major, FACT)
- Group: open-decisions
- Assessment: The inventory reports 38 open items; TBD-001 (target), TBD-004 (DMA timing), TBD-009 (key port), TBD-015 (AXI profile), TBD-018 (packing), TBD-019 (nonce rule), TBD-020 (tag placement) and TBD-022 (invalid key) change ports, registers or behavior and must be closed or waived before RTL.
- Verdict: `fix`
- Fix: Close the eight items with the user in one decision round, record each as a DEC, and re-run the specification check; carry the rest as dated assumptions.
- Why: Each of the eight changes a port, a register field or a state transition, so leaving it open forces a rework of the generated RTL and the workbook.

### F-027 Rows of section 20 are not in identifier order

- Evidence: `VLSIT_CHACHA_HDS.md:2661` (§20 row order)
- Severity: `Low` (scorecard: Observation, FACT)
- Group: traceability
- Assessment: ASM-004 and ASM-005 precede ASM-010, ASM-008, ASM-009, ASM-007, ASM-006 and ASM-003, and DEC-015 to DEC-017 precede DEC-014.
- Verdict: `fix`
- Fix: Sort the table by identifier and add a created date to each item so that the age of an open item is visible.
- Why: A sorted table with dates is easier to review and lets a reviewer measure how long an item stayed open.

### F-028 The integrator cannot tell what to provide

- Evidence: `VLSIT_CHACHA_HDS.md:2681` (§20 DEP-001 to DEP-003, ASM-004)
- Severity: `High` (scorecard: Major, FACT)
- Group: open-decisions
- Assessment: The key-store owner and protocol, the DMA controller model, the clock domain of the key port and of the DMA handshake (ASM-004), and the reuse of the library FIFOs (DEP-003) are open, so there is no integration checklist.
- Verdict: `fix`
- Fix: Produce an integration checklist (clocks and reset relations, key-store port, DMA handshake, privilege decision, constants for i_protect_en and i_slverr_en, constraint file) and ask the user to confirm DEP-003.
- Why: Integration effort is dominated by the external dependencies, so they must be listed before the IP is handed over.

### F-029 Competitiveness is not demonstrated yet

- Evidence: `VLSIT_CHACHA_HDS.md:2364` (§1, §13, sources D1 to D7, P1 to P3)
- Severity: `Medium` (scorecard: Minor, INFERENCE)
- Group: performance
- Assessment: Against commercial cores the IP lacks context switching and the stand-alone modes of D1, and has no throughput, area or frequency figure comparable to D3 (up to 50 Gbit/s) or D4 (800 Gbit/s ASIC claim); against SoC secure engines it is faster at the Poly1305 level (212 microseconds for 1 kB in D5 page 64) but no measured figure exists to prove it.
- Verdict: `fix`
- Fix: After RTL, publish mapped area, frequency and cycles per message for the three configurations in the same units as the sources, and add the table to section 13.
- Why: A like-for-like table is the evidence a product team needs to choose this IP over a licensed core.

### F-030 The benchmark evidence base is incomplete

- Evidence: `VLSIT_CHACHA_HDS.md:2364` (research report §3, manifest)
- Severity: `Low` (scorecard: Observation, FACT)
- Group: performance
- Assessment: The research bundle is INCOMPLETE (7 of 10 product families, 3 of 10 papers), the throughput figures are vendor claims without conditions, and the Rambus CH-7xx automotive core could not be read.
- Verdict: `fix`
- Fix: Add the missing datasheets and papers supplied by the user and re-run the evidence checker before the market chapter is relied upon.
- Why: The comparison is only as strong as its sources.

## 3. Actions

| Action | Owner | Blocks sign-off |
|---|---|---|
| Close TBD-001, 004, 009, 015, 018, 019, 020 and 022 with the user and record each as a DEC (group open-decisions; F-001, F-004 to F-007, F-012, F-026, F-028) | user and spec | Yes, blocks RTL generation |
| Set the delivered defaults (output depth, maximum message length, hold mode) and fix the PARA_POLY_ARCH default (group defaults; F-010, F-011, F-023) | spec | Yes, blocks the delivered configuration |
| Define toggle-based event crossings and the single-domain reset rule (group cdc-reset; F-008, F-009) | spec and RTL | Yes, blocks CDC sign-off |
| Write `sdc/chacha_top.sdc`, add the critical-path estimate and validate the exception bounds (group timing; F-013 to F-016) | spec and SoC | Yes, blocks timing sign-off |
| Build the cycle model and quantify Poly1305, per-message cost and the requirement (group performance; F-017, F-018, F-029, F-030) | spec | No, blocks the performance claim |
| Decide the scan architecture and add the test ports (group dft; F-020) | SoC DFT | Yes, changes the top-level ports |
| Decide access control and the nonce guard (group security; F-021, F-022, F-024) | user and spec | Yes, changes the interface and registers |
| Create the RFC 8439 reference model and run the three vectors before RTL (group verification; F-025) | verification | No, precedes RTL |
| Map FEAT to REQ, sort section 20 and add dates (group traceability; F-002, F-019, F-027) | spec | No |

## 4. Limits

- RTL, SDC, simulation, mapped area, power and frequency do not exist, so no finding concerns them; the consistency of RTL with the specification was not assessed.
- The reviewer is also the author of the specification; the false-negative rate below is a lower bound, and an independent review is still needed.
- The commercial comparison uses the sources of the research report (7 of 10 families, 3 of 10 papers, saved 2026-11-22); no new web search was made.
- AXI4 statements come from a conversion of Arm IHI 0022H.c in which 53 pages differ by more than 5 percent in word count; only running-text statements were used.

**Gate (rule R-020).** `vlsit_review_gate.py metrics` printed: `RESULT: PASS, 30 finding(s)`. Unwaived Critical: 0. Waiver usage: 2/10 of the budget of 10; the two waivers are F-003 (owner user, invalidation: a storage or stand-alone MAC use case is added) and F-024 (owner user, invalidation: the attacker model or a certification requires resistance to power analysis or fault injection). Closure rate 93 percent; sampling 57 percent (17 of 30 findings traced).

**Depth (rule R-022).** 17 findings were traced in depth against the specification text, at most ten per group; the other 13 are aggregated by root cause in the groups table. The user is asked before any deeper analysis.

**Audit sample (rule R-021).** `vlsit_review_gate.py sample` drew 3 of 30 findings; each was re-read against the specification.

| Finding | Severity | Root cause | Result | Check |
|---|---|---|---|---|
| F-009 | High | cdc-reset | tp | TBD-017 (line 2710) states the effect of a one-domain reset is open; section 7.3 names no mechanism. |
| F-003 | Low | features-scope | tp | DEC-003 (line 2666) excludes the stand-alone modes; D1 lists stand-alone ChaCha20, stand-alone Poly1305 and context switching. |
| F-010 | High | defaults | tp | PARA_FIFO_OUT_DEPTH 16, PARA_AXI_DW 64, PARA_MSG_MAX_B 65535, PARA_HOLD_EN 0 (lines 898 to 905); ASM-002 assumes 1280 B messages (line 2660). |

False-positive rate of the sample: 0 of 3 (0 percent). False negatives found while checking the sample: 0 of 3 (0 percent), which is a lower bound because the reviewer is the author and the sample covers only the listed findings.

**Groups by root cause.**

| Group | Findings | Severities | Root cause |
|---|---|---|---|
| G-01 | F-008, F-009 | High | cdc-reset |
| G-02 | F-010, F-011, F-023 | High, Medium | defaults |
| G-03 | F-020 | High | dft |
| G-04 | F-003 | Low | features-scope |
| G-05 | F-001, F-004, F-005, F-006, F-007, F-012, F-026, F-028 | High, Medium | open-decisions |
| G-06 | F-017, F-018, F-029, F-030 | High, Low, Medium | performance |
| G-07 | F-021, F-022, F-024 | High, Low | security |
| G-08 | F-013, F-014, F-015, F-016 | High, Low, Medium | timing |
| G-09 | F-002, F-019, F-027 | Low, Medium | traceability |
| G-10 | F-025 | Medium | verification |

