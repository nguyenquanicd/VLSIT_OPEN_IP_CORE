# General-Purpose Input/Output (GPIO) with Direct Memory Access (DMA) support: feature research report

Status: **INCOMPLETE** (evidence gate: datasheets 10/10, peer-reviewed full-text papers 0/10).
Search date: 2026-11-21. Output directory: `VLSIT_OPEN_IP_CORE/024_GPIO/research`.
Evidence register: `vlsit_source_manifest.csv`. Retained source files: `vlsit_sources/` (internal research use only, not for redistribution).

## 1. Executive summary

**Target and question.** What do documented microcontroller and system-on-chip (SoC) products offer for combining GPIO with DMA, in both directions: (a) a DMA engine reading or writing GPIO data, and (b) a GPIO pin or event starting or pacing a DMA transfer? The application context is any embedded system (user decision, 2026-11-21); the research feeds the `024_GPIO` Intellectual-Property (IP) block of this repository.

**Status and why.** The report is `INCOMPLETE` because no peer-reviewed full-text paper that substantively discusses GPIO together with DMA was found and retained. The one paper retained (D-P1, a DMA controller design) does not discuss the feature and is excluded from the count. Three further candidate papers (Sensors 2024 and 2015, via PubMed Central) could not be retrieved by the script (HTTP 403 from the publisher site and from the PubMed Central render service) and one (Electronics 2023) has no open copy found; none of the four was read. The paper corpus occurrence rate is therefore **not computable**.

**Top findings (product-document corpus of 10 families, see section 5).**

1. Four distinct GPIO-DMA mechanisms appear in the documents: (F1) DMA write access to a GPIO output register with a per-bit mask, (F2) a pin directly requesting DMA, (F3) a GPIO event routed to a DMA task through an event fabric, and (F4) a DMA-fed dedicated pin-driving engine (programmable or parallel I/O).
2. **Only 1 family documents F1 explicitly** (MSPM0 G-series: `DMAMASK` register, PDF p670); one family documents that its DMA cannot reach the fast GPIO registers at all (RP2040: the single-cycle I/O block is not on the main system bus, PDF p28). Eight families do not state it either way.
3. **F2 (pin requests DMA) is documented in 2 of 8 assessable families** (TM4C123 `GPIODMACTL`, PDF p691; MSP430FR5994 external trigger pin `DMAE0`, PDF p21). Five assessable families list their DMA request sources exhaustively and have no GPIO entry (RP2040 p99, RP2350 p1016-1017, CC13x2 p1296, ESP32-S3 p397, ESP32-P4 p661), and the MSPM0G manual routes GPIO through events instead (p648, medium confidence).
4. **F3 (event fabric) is documented in 3 families** (MSPM0G, ESP32-C6, ESP32-P4), the newer designs of the set. The MSPM0G case is an inference from two statements (medium confidence).
5. **F4 (DMA-fed pin engine) is documented in 4 of 6 assessable families** (RP2040 and RP2350 PIO, ESP32-C6 and ESP32-P4 PARLIO).
6. The corpus is **three vendors** (Raspberry Pi, Espressif, Texas Instruments); it excludes ST, NXP, Microchip, Silicon Labs and Nordic because their documents could not be retrieved lawfully by the script (section 2). The rates describe this corpus only and are **not** market share.

**Confidence.** Medium for the facts quoted with page locators; low for any statement about families not in the corpus. Limits are in section 12.

## 2. Scope and method

**Research question (frozen 2026-11-21).** Which documented hardware features let GPIO and DMA work together, how are they organised (controller, datapath, arbitration, configuration), and what do they imply for an open GPIO IP with DMA support?

**Scope.** Features in both directions (user choice "both directions"). Any embedded application. Datasheets, databooks and reference manuals of microcontrollers and SoCs from manufacturers. Reference manuals are treated as databooks. Application notes, forum posts and patents are context only.

**Catalogs and queries (web search, standard mode, 2026-11-21).**

1. `GPIO DMA microcontroller direct memory access GPIO port data register pattern generation peer-reviewed`
2. `DMA-driven GPIO bit banging high speed parallel output microcontroller paper Sensors Electronics MDPI`
3. `STM32 DMAMUX request generator EXTI GPIO trigger DMA reference manual`
4. `Kinetis PORT pin control DMA request on pin edge GPIO FGPIO reference manual DMA`
5. `RP2040 datasheet PIO DMA GPIO pins DREQ`
6. `ESP32-C6 parallel IO PARLIO GDMA GPIO technical reference manual`
7. `"DMA" "GPIO" microcontroller high-speed logic analyzer OR waveform generator OR parallel interface open access journal article`
8. `peripheral interconnect event system microcontroller DMA GPIO trigger low power peer-reviewed paper`
9. `Raspberry Pi DMA GPIO sampling real-time pulse generation paper journal`
10. `programmable I/O offload PIO microcontroller GPIO DMA architecture paper`
11. `WS2812 LED driver DMA timer GPIO microcontroller paper Electronics OR Sensors OR IEEE`
12. `DMA controller design microcontroller peripheral request GPIO FPGA implementation journal article open access`
13. `"Experimental timing and control using microcontrollers" Prawnblaster Review of Scientific Instruments OR journal published`
14. `"PELS" "Peripheral Event Linking System" Ottaviano Benini published conference proceedings`
15. `microcontroller "DMA" parallel data acquisition GPIO sampling external ADC STM32 journal Sensors mdpi.com`
16. `bit-banging protocol DMA GPIO software-defined interface microcontroller paper proceedings`
17. `I/O subsystem DMA GPIO interrupt latency embedded SoC architecture peer-reviewed IEEE`
18. `open source GPIO IP core DMA RISC-V SoC peripheral PULP OpenTitan GPIO paper`
19. Four domain-restricted searches (`mdpi.com`; IEEE, Springer, ScienceDirect, ACM; IEEE, MDPI, Hindawi, ScienceDirect, PubMed Central; and the same plus arXiv) with terms on DMA, GPIO, event systems, autonomous peripherals and pattern generation.

**Inclusion.** Manufacturer datasheet or reference manual of a real product family; directly downloadable without credentials; English; the document must describe a DMA controller or GPIO block. **Exclusion.** Duplicate revisions or mirrors of one family; marketing pages; documents that needed a login or returned an access error.

**Language and date limits.** English only; no start-date limit; the newest documents are dated 2026.

**Access basis and exclusions of sources.** Direct downloads were checked with HTTP requests before the user approved the batch. These were **not retrieved** and nothing was bypassed: ST reference manuals (no connection could be established), NXP (HTTP 404), Microchip and Silicon Labs and Nordic (HTTP 403), Analog Devices (no connection). Four candidate papers returned HTTP 403 to the script (see section 3). The user can supply authorised copies of these documents (`register` command, access basis `user-authorized`).

**Deduplication.** Datasheets by distinct product-family key (10 distinct keys, 10 distinct SHA-256 values; checker output `duplicate_file_hashes=0`). The RP2040 and RP2350 are different chips from one vendor and are counted as two families; the three ESP32 manuals are three different SoC lines.

## 3. Evidence inventory and quality

Checker result (`vlsit_asic_ip_feature_research.py check`): `INCOMPLETE: datasheets=10/10 papers=0/10 duplicate_file_hashes=0`. The checker verifies file presence, hashes and key uniqueness only, not quality or truth.

| ID | Family key | Document | Publisher | Date / revision | Quality note (authority, relevance, currency, independence) |
|---|---|---|---|---|---|
| D1 | raspberrypi_rp2040 | RP2040 Datasheet, RP-008371-DS-2 | Raspberry Pi Ltd | copyright 2022-2026 | High authority, high relevance; current; vendor claims only |
| D2 | raspberrypi_rp2350 | RP2350 Datasheet, RP-008373-DS-4 | Raspberry Pi Ltd | copyright 2022-2026 | High, high; current |
| D3 | broadcom_bcm2835 | BCM2835 ARM Peripherals, RP-008249-DS-1 | Broadcom (hosted by Raspberry Pi) | 2012 | High authority, medium relevance (old, the DREQ map was not read); not current |
| D4 | espressif_esp32c6 | ESP32-C6 Technical Reference Manual | Espressif | version 1.2 | High, high |
| D5 | espressif_esp32s3 | ESP32-S3 Technical Reference Manual | Espressif | version 1.8 | High, medium |
| D6 | espressif_esp32p4 | ESP32-P4 Technical Reference Manual | Espressif | version 1.0 | High, high |
| D7 | ti_tm4c123 | TM4C123GH6PM Datasheet | Texas Instruments | 12 June 2014 | High, high; older generation |
| D8 | ti_mspm0g | MSPM0 G-Series Technical Reference Manual, SLAU846F | Texas Instruments | revised November 2026 | High, high; current |
| D9 | ti_msp430fr5994 | MSP430FR5994 Datasheet | Texas Instruments | revision not read | High, medium |
| D10 | ti_cc13x2_cc26x2 | CC13x2/CC26x2 Technical Reference Manual, SWCU185G | Texas Instruments | revised June 2024 | High, medium |
| P1 | (paper) | Design and Implementation of a DMA Controller for Embedded Applications, Int. J. Technology 10(2), 309-319, 2019 | Universitas Indonesia | accepted February 2019 | **Excluded from the count**: no peer-review statement in the text and GPIO appears once, as an AMBA peripheral. Kept in the bundle as background only; `peer_reviewed` is set to `no` in the manifest |

**Independence.** The three Texas Instruments documents and the three Espressif manuals are each from one vendor and share vocabulary and design approach; the 10 families are not 10 independent vendor viewpoints.

**Candidate papers not retrieved (not counted).** Electronics 2023, 12(20), 4206 (DOI 10.3390/electronics12204206): publisher site returned HTTP 403; no PubMed Central copy found. Sensors 2024, 24(15), 4982 (DOI 10.3390/s24154982, PubMed Central PMC11315031), Sensors 2024, 24(15), 4871 (DOI 10.3390/s24154871, PMC11314752) and Sensors 2015, 15(12), 29878 (DOI 10.3390/s151229878, PMC4721798): the publisher site and the Europe PubMed Central render service both returned HTTP 403 to the script. Their relevance to GPIO with DMA is unknown (titles suggest DMA storage, low-power timing and sensor-to-FPGA capture). The access restriction was respected.

**Context sources, not counted and not peer reviewed:** the PELS (Peripheral Event Linking System) preprint (arXiv 2311.09645; a Design, Automation and Test in Europe (DATE) 2024 poster with the same title exists, but a proceedings entry was not found); "Experimental timing and control using microcontrollers" (arXiv 2406.17603; no journal version found, DMA refills the PIO instruction FIFO); STMicroelectronics community threads and the X-CUBE-PARAL-COM package page; NXP community threads; a Hackaday project on the STM32H7. These are used only to point at open questions in section 12.

## 4. Feature/function taxonomy

| ID | Normalized feature | Source terminology | Function / user outcome | Evidence status | Confidence |
|---|---|---|---|---|---|
| F1 | DMA write access to a GPIO output register, with a per-bit mask and a stated CPU/DMA arbitration rule | "GPIO DMA Interface", `DMAMASK`, "DOUT serviceable by DMA" (D8) | Memory-to-pin patterns (waveform, LED sequence) while the CPU sleeps | Explicit in 1 family; explicit absence of the path in 1 family | High for D8 and D1 |
| F2 | A GPIO pin directly requests or triggers a DMA channel | `GPIODMACTL` "pin as a source for the μDMA trigger" (D7); "DMAE0 External DMA trigger" (D9) | Pin edge or level starts a transfer (data capture on an external strobe) | Explicit in 2 families; exhaustive request tables without GPIO in 4 | High |
| F3 | A GPIO event reaches a DMA through an event fabric or an event-task matrix | Event publisher/subscriber (D8); Event Task Matrix, ETM (D4, D6) | Peripheral chaining without the CPU; wake-free sequencing | Explicit pair of statements in D4, D6; inference in D8 | Medium to high |
| F4 | A dedicated pin-driving or pin-capturing engine fed by DMA | Programmable I/O, PIO (D1, D2); Parallel IO controller, PARLIO (D4, D6); LCD_CAM (D5) | Wide or custom-protocol I/O at DMA throughput without bit-banging | Explicit in 4 families; ambiguous in 1 (D5) | High |

Out of scope for the rates: timer- or PWM-paced DMA into a GPIO port, and set/clear/toggle register aliases as a DMA-safe update method. They are mentioned where a source states them (D1 p19, D3 p90) but were not systematically extracted.

## 5. Corpus occurrence, not market share

Denominator definition: a family is *assessable* for a feature when its document either states the feature or contains an exhaustive DMA request or peripheral table (so that a missing entry is an explicit absence), not merely when it is silent. Silence is "not reported".

| Feature | Families with explicit evidence / assessable families | Product corpus rate | Papers discussing / eligible papers | Paper corpus rate | Not reported / ambiguous | Limits |
|---|---:|---:|---:|---:|---|---|
| F1 DMA writes GPIO output with mask | 1 / 2 | not enough evidence (denominator 2) | 0 / 0 | not computable | 8 (D2, D3, D4, D5, D6, D7, D9, D10) | Only D8 states it; D1 states the opposite for its SIO path |
| F2 pin requests DMA | 2 / 8 | 25 % of this corpus | 0 / 0 | not computable | 2 (D3: request map not read; D4: peripheral list says "including") | Numerator is two TI families; absence in D1, D2, D10, D5 and D6 rests on request tables read as exhaustive; D8 absence is medium confidence (p648) |
| F3 GPIO event to DMA by event fabric | 3 / 3 | not enough evidence (denominator 3) | 0 / 0 | not computable | 7 | D8 is an inference; D10 has an event fabric with port capture events (PDF p333) but no statement that it reaches the µDMA (ambiguous) |
| F4 DMA-fed pin engine | 4 / 6 | 67 % of this corpus | 0 / 0 | not computable | 4 (D3, D5 ambiguous, D8, D9) | Absence in D7 and D10 rests on the channel tables |

These are occurrence rates inside a vendor-biased corpus of 10 documents (3 vendors). They say nothing about market share or how many products implement a feature. Commercial availability, scholarly attention (no data) and application value are separate judgments.

## 6. System architecture and microarchitecture

Figure: `gpio_dma_architecture.drawio` (editable draw.io; solid lines are documented, dashed lines are inferred, dotted grey items are unknown). Legend and sources are inside the figure.

**F1, DMA write path to the pins (D8).** The GPIO block exposes the output register `DOUT31_0` on a peripheral bus (power domain PD1) that the DMA can reach; the manual says this is mainly so that the DMA can load output values (PDF p19). The `DMAMASK` register marks which bits the DMA may modify; if both the DMA and the CPU write the same bit, a set mask bit gives the DMA priority and a clear mask bit gives the CPU priority (p670). The CPU keeps a single-cycle I/O path (p19). The feature is "not available on all devices" (p667). Use case stated by the source: a pre-loaded pin sequence while the CPU sleeps (p670).

**Contrast, no DMA path (D1).** The RP2040 single-cycle I/O block, which holds the fast GPIO registers, is not attached to the main system bus and only the processors and the debugger can access it (PDF p28). Its answer to pin-pattern work is F4: the PIO, which has dedicated connections to the bus fabric, the GPIO pins and the interrupt controller, and a DMA interface with a sustained throughput of up to one word per clock (both p304), paced by DREQ lines for each PIO FIFO (p99). The DREQ table (40 entries) lists PIO, SPI, UART, PWM, I2C, ADC and XIP sources and no GPIO (p99). The RP2350 keeps this structure with 55 entries (PIO0-PIO2, PWM, I2C, ADC, XIP, HSTX, CoreSight, SHA-256; PDF p1016-1017).

**F2, pin requests DMA (D7, D9).** TM4C123: the register GPIO DMA Control (`GPIODMACTL`) configures a GPIO pin as a source of the µDMA trigger; its 8-bit `DMAEN` field enables this per pin (PDF p691), and the µDMA channel table lists GPIO ports among the request sources of some channels (Table 9-1, PDF p587). MSP430FR5994: pin P1.0 carries the function `DMAE0` described as "External DMA trigger" (PDF p14 and p21).

**F3, event fabric (D8, D4, D6, D10).** MSPM0G: peripherals publish and subscribe through generic event channels; the DMA module has one event publisher and two event subscribers (PDF p540); GPIO has publisher ports and the manual gives the example of a GPIO event starting an ADC conversion (p648); an event subscriber also exists in the DMA (p646). The direct GPIO-to-DMA route is an **inference** from these statements. ESP32-C6 and ESP32-P4: a GPIO ETM task can be triggered by the ETM event of any peripheral, and a peripheral task can be triggered by a GPIO event (C6 p264, P4 p1009); the GDMA controller supports ETM, so its tasks can be triggered by other peripherals' events and its events can trigger other peripherals (C6 p137, P4 p672); with the ETM enable bit set, only ETM tasks (not the CPU) start a GDMA channel (P4 p673). Together they document GPIO event to DMA start, the GPIO tasks being set, clear and toggle, with a rule for simultaneous tasks (C6 p265; P4 p1010 also mentions a priority).

**F4, DMA-fed pin engine (D4, D6, D5).** ESP32-C6 GDMA has three transmit and three receive channels shared by SPI2, UHCI (UART), I2S, AES, SHA, ADC and PARLIO ("Parallel IO Controller"; PDF p131, p1383). ESP32-P4 assigns PARLIO, LCD, CAM, two SPIs, AES and SHA to the AXI GDMA channels (p661-662). ESP32-S3's peripheral-selection register lists SPI2, SPI3, UHCI0, I2S0, I2S1, LCD_CAM, AES, SHA, ADC_DAC and RMT and calls other values invalid (p397); whether LCD_CAM is a parallel pin engine was not confirmed from the pages read (ambiguous).

**Pacing and credit.** DMA-to-peripheral pacing by request lines is documented in the Raspberry Pi parts (credit-based DREQ, D1 p99 and D2 p1017) and in BCM2835 (level-sensitive DREQ with a Panic signal; D3 p38, PERMAP field p51). The relation to GPIO is only through the peripherals that drive pins.

**Not documented in the sources read:** burst behaviour of DMA writes into a GPIO register, the maximum pin toggle rate by DMA, and any error reporting when a DMA write targets a masked bit. These are open questions (section 12).

## 7. Integration and physical interface requirements

| Feature / interface | Local block | External peer | Protocol / logical contract | Pad / physical-layer / electrical evidence | Clock / reset / power | Package / board / process | Open integration questions |
|---|---|---|---|---|---|---|---|
| F1 DMA to GPIO output (D8) | GPIO `DOUT31_0` on peripheral bus PD1 | Any external device on the pins | Memory-to-peripheral write, per-bit `DMAMASK` | Not stated in the pages read: pad type, drive, voltage **unknown** | Bus interface is in power domain PD1; GPIO logic is in PD0 (p19) | Device-dependent ("not available on all devices", p667) | Latency of the PD1 to PD0 crossing; DMA write rate |
| F2 pin to DMA (D9) | Pin P1.0 / DMAE0 | External strobe source | External trigger input | Pin table: `DMAE0` input, LVCMOS buffer, supply DVCC (PDF p14) | The `DMAE0` row has no reset state; the port pin P1.0 shows OFF | Pin shared with TA0.1, RTCCLK and analog inputs (p14) | Minimum pulse width and synchronisation of the trigger: not read |
| F2 pin to DMA (D7) | GPIO port `GPIODMACTL` | External strobe | µDMA trigger enable per pin | Not read | Not read | Not read | Which pin maps to which µDMA channel (Table 9-1, only part read) |
| F3 event fabric (D4, D6) | GPIO ETM tasks and events, GDMA ETM tasks | None (on-chip) | Event Task Matrix channel | Not applicable on-chip | Not read | Not read | Latency from GPIO event to GDMA start: not documented in the pages read |
| F4 PIO / PARLIO (D1, D2, D4, D6) | PIO state machines, PARLIO | Any external parallel device | FIFO or descriptor-fed pin pattern | Pad cell, drive and voltage **unknown** (a logical interface name does not establish electrical compatibility); PARLIO clock-output GPIO is mentioned only in a driver page outside this corpus | Not read | Not read | Maximum parallel clock rate; pin-count limits |

For every row marked unknown, the vendor's electrical-characteristics section must be read before a design commitment.

**Integration trade-off matrix (R-014).**

| Category | Finding | Evidence or open question |
|---|---|---|
| Power | A DMA-driven pin sequence lets the CPU stay asleep | D8 p670; the energy saved was not measured in the source |
| Performance, bandwidth, latency | Maximum DMA-to-pin rate and trigger-to-transfer latency are not stated in the pages read | Open question; unreviewed practitioner reports exist (section 12) |
| Area | Not stated by any source; the IP-level cost of a mask register and merge logic is a hypothesis in section 10 | Open question |
| Clock and reset | GPIO bus interface and GPIO logic can be in different power domains (PD1, PD0) | D8 p19; a pin trigger needs synchronisation (hypothesis, section 10) |
| Memory | Pattern tables and capture buffers live in system memory; buffer size and double-buffering are not described | Open question |
| Security | Peripherals, GPIOs and DMA channels can be assigned individually to security domains | D2 p14 and p34 (RP2350); not read for other families |
| Safety | No source read states safety or diagnostic features for GPIO with DMA | Unknown; follow up in vendor safety manuals |
| Test | Not read | Unknown |
| Software and driver | Feature is device-dependent and is checked in the device datasheet; no capability register is described | D8 p667 |
| Backward compatibility | The per-pin enable or mask defaults to the CPU-controlled behaviour | D7 p691 (reset 0), D8 p670 |
| Package and pin count | A dedicated DMA trigger function shares its pin with other functions | D9 p14 |
| Process | Not relevant to the feature description; no source ties the feature to a process node | Not applicable |

## 8. Configuration, registers and software usability

- **Per-pin enable and mask (D7, D8).** Both put the control in the GPIO block: `GPIODMACTL.DMAEN` (8 bits, reset 0, PDF p691) and `DMAMASK` (PDF p670). A bit that is not set leaves the pin under CPU control, which preserves the legacy software model (backward compatibility by default-off).
- **Discoverability.** D8 notes the feature is device-dependent and must be checked in the device datasheet (p667), so software needs a capability flag or documentation lookup.
- **Failure handling.** None of the sources read states an error or status flag for a DMA write rejected by the mask (unknown).
- **Software flow of the DMA pattern case (D8).** Pre-load a table in memory, set `DMAMASK` for the allowed bits, configure the DMA with the GPIO register as destination, start; the CPU may sleep (p670). The steps are the document's description, not a driver sequence.

## 9. Licensing, patent and dependency review

This is technical research, not legal advice and not a freedom-to-operate opinion.

**Document rights (per source, manifest `license_notice`).** D1, D2: documentation licensed under Creative Commons Attribution-NoDerivatives 4.0 International (colophon, PDF p2), with portions © Synopsys; D3: © 2012 Broadcom Corporation, all rights reserved; D4-D6: Espressif Disclaimer and Copyright Notice, which states that no licences to intellectual property rights are granted; D7: © 2007-2014 Texas Instruments Incorporated; D8: © 2026 Texas Instruments Incorporated; D9, D10: notice not located in the pages read. Local retention for research does not grant redistribution rights; nothing is embedded in this report except short locators.

**Implementation licence.** None of these documents is an implementation licence. The open-source GPIO blocks seen in search results (OpenTitan GPIO, PULP GPIO) were not downloaded or read; their licences are **unknown** in this study.

**Patent evidence (identified, claims not read).** Lookup date 2026-11-21; database: United States Patent and Trademark Office (USPTO) full-text results reached through web search; jurisdiction: United States only; no other jurisdiction or register (for example the European Patent Office or the World Intellectual Property Organization) was searched.

| Number | Title (as shown by the search) | Relevance | Status |
|---|---|---|---|
| US 6,931,466 | Reprogrammable input-output pins for forming different chip or board interfaces | Possible relevance (pin groups configurable as programmed I/O or DMA I/O) | Unresolved; claims not read |
| US 8,127,070 | Programmable I/O interface | Possible relevance (small processor with DMA FIFO) | Unresolved; claims not read |
| US 8,943,238 | Operations using direct memory access | Possible relevance (DMA pattern generation mode) | Unresolved; claims not read |
| US 10,515,036 | Bit manipulation capable direct memory access | Possible relevance (DMA bit manipulation) | Unresolved; claims not read |

These are **identified evidence of possible relevance only**. Database status can lag official registers and legal scope needs qualified counsel. No statement is made that the features are unpatented, free to implement or cleared.

**Standards and third-party dependencies.** The features here are vendor-specific and not defined by a standard. The Advanced Microcontroller Bus Architecture (AMBA) trademark licence is mentioned in P1 as an Arm item; no other dependency was studied. Open question: whether any implementation of F3 relies on a licensed event-routing technique (see the PELS context source).

## 10. Opportunities for new or improved features

Design implications for the `024_GPIO` IP. Novelty is a hypothesis pending prior-art and legal review.

| Proposal | Unmet need and evidence | User/software benefit | Architecture and integration change | PPA, security, compatibility risks | Licensing uncertainty | Validation experiment | Confidence |
|---|---|---|---|---|---|---|---|
| P-A Mask-guarded DMA write path to output data (F1) | D1 p28: DMA cannot reach the fast GPIO block on RP2040; D8 p670 documents the mask approach; most families in the corpus do not state it (8 of 10) | Pin patterns while the CPU sleeps without bit-banging | A DMA-writable data register on the peripheral bus with a per-bit allow mask and a stated CPU/DMA priority rule | Area: one mask register and a merge mux per bit; security: a per-pin allow mask also confines a DMA master; compatibility: default mask 0 keeps legacy behaviour | Possible relevance of US 8,943,238 and US 10,515,036 (claims not read) | RTL simulation with a DMA model writing patterns at several rates, plus concurrent CPU writes to the same bit; measure the arbitration outcome | Medium |
| P-B Set, clear and toggle write aliases as the DMA target | D1 p19 notes some GPIO registers have set/clear/xor aliases; D3 p90 lists GPSET/GPCLR; DMA read-modify-write would be unsafe | DMA changes selected pins without disturbing others, without a mask register | Add alias addresses to the register map | Minimal area; a software model must document that aliases are write-only | Not assessed | Directed test: concurrent writers to different bits of one port | Medium |
| P-C Per-pin DMA trigger enable (F2) | D7 p691 and D9 p21 document it; D1, D2, D5, D6, D10 request tables have no GPIO source | A pin edge starts a transfer (capture on an external strobe) | Per-pin enable and edge select feeding a DMA request line; two-flop synchroniser on each pin | Clock-domain crossing on the pin; request/acknowledge protocol with the chosen DMA; pins have no electrical qualification in this study | Not assessed | Simulate asynchronous pin edges against the DMA handshake including metastability checks | Medium |
| P-D GPIO events and tasks on an event bus (F3) | D4 p264 and D6 p1009 document GPIO events/tasks; D8 p648 documents the publisher side | CPU-free chaining of a pin event with timers and DMA | Event-output and task-input ports on the GPIO block with a documented priority among simultaneous tasks (D4 p265) | Wiring and verification cost depends on the SoC event fabric; the IP only exposes ports | Possible relevance (PELS-type systems; not reviewed) | Integrate with a simple event matrix in simulation; measure event-to-DMA latency | Low to medium |

A dedicated DMA-fed pin engine (F4) is a separate block (PIO, PARLIO) and is not proposed for a GPIO IP; it is the alternative to P-A for wide patterns.

## 11. Trade-offs and recommendation

Options for the `024_GPIO` DMA interface (no more than three):

1. **Minimal:** P-A with P-B (data path only). Lowest cost, covers the memory-to-pin use case, no new inputs. Risk: no pin-triggered capture.
2. **Balanced (recommended for a first release, subject to the user's priorities):** P-A + P-B + P-C. Adds the capture direction with one request line per enabled pin group. Cost: synchronisers and a handshake; the evidence for F2 is two TI families.
3. **Event-centred:** P-D in addition. Adds ports for an event fabric; useful only if the target SoC has one.

Decision criteria: DMA protocol of the host SoC (request/acknowledge versus a bus master), need for sleep-mode patterns, pin count and the ability to verify the asynchronous-pin path. The recommendation is a design hypothesis from a 10-family corpus and does not rest on peer-reviewed evidence.

## 12. Risks, gaps and next research steps

- **Papers:** 0/10; the paper search did not find work on GPIO with DMA; four candidate papers were not retrievable and not read. Next: obtain authorised copies (user to supply) or search IEEE Xplore and ACM with institutional access.
- **Missing vendors:** ST (DMAMUX with EXTI as request-generator trigger), NXP (Kinetis `PORT` DMA request, i.MX RT), Microchip, Silicon Labs, Nordic, Renesas, Infineon. Secondary sources (forum and SDK pages) describe these mechanisms but are not evidence in this study. Next: user-supplied reference manuals.
- **Source conflicts:** none found among the sources read; D8 documents the feature as device-dependent.
- **Not extracted:** DMA burst and rate limits for GPIO, DMA-paced timer patterns, error handling, the BCM2835 DREQ map (D3 PERMAP list), the part of the TM4C123 channel table beyond the GPIO entries, MSP430FR5994 DMA access to port registers, and the CC13x2 event-to-DMA route.
- **Practitioner reports (context only, unreviewed):** forum and project pages report that a single DMA stream writing a GPIO from RAM tops out near 28.5 MHz on one STM32H7 and that several streams can give timing errors; these were not verified and are not evidence here.
- **Patents:** United States only, titles only, claims not read.
- **Selection bias:** three vendors; documents of 2012 to 2026; assessability depends on how exhaustively each document lists request sources.

## 13. Abbreviations and references

| Abbreviation | Meaning |
|---|---|
| ADC | Analog-to-Digital Converter |
| AMBA | Advanced Microcontroller Bus Architecture |
| CPU | Central Processing Unit |
| DMA | Direct Memory Access, data movement without the processor handling each word |
| DREQ | DMA request line from a peripheral |
| ETM | Event Task Matrix (Espressif event routing between peripherals) |
| GDMA | General DMA controller of the ESP32 family |
| GPIO | General-Purpose Input/Output |
| IP | Intellectual Property (a reusable hardware block) |
| PARLIO | Parallel I/O controller (ESP32-C6 and ESP32-P4) |
| PIO | Programmable I/O block (RP2040, RP2350); outside the RP context "programmed I/O" means CPU-driven I/O |
| SIO | Single-cycle I/O block of the RP2040 |
| SoC | System-on-Chip |
| µDMA | Micro DMA controller (Texas Instruments TM4C and CC13x2) |

References (all PDF page numbers are PDF page indices of the retained files; manifest rows give family keys and hashes):

- D1 Raspberry Pi Ltd, RP2040 Datasheet, RP-008371-DS-2: p19, p28, p99, p304.
- D2 Raspberry Pi Ltd, RP2350 Datasheet, RP-008373-DS-4: p15, p24, p1016-1017.
- D3 Broadcom, BCM2835 ARM Peripherals: p38, p49-51, p90.
- D4 Espressif, ESP32-C6 Technical Reference Manual v1.2: p131, p137-138, p264-265, p1383.
- D5 Espressif, ESP32-S3 Technical Reference Manual v1.8: p397, p689.
- D6 Espressif, ESP32-P4 Technical Reference Manual v1.0: p661-662, p672-673, p1009-1010.
- D7 Texas Instruments, TM4C123GH6PM Datasheet (12 June 2014): p587-588, p691.
- D8 Texas Instruments, MSPM0 G-Series Technical Reference Manual, SLAU846F: p19, p540, p646-649, p667, p670.
- D9 Texas Instruments, MSP430FR5994 Datasheet: p14, p21.
- D10 Texas Instruments, CC13x2/CC26x2 Technical Reference Manual, SWCU185G: p329, p333, p1296.
- P1 Ahmed, Aljumah, Ahmad, "Design and Implementation of a Direct Memory Access Controller for Embedded Applications", Int. J. Technology 10(2):309-319, 2019, DOI 10.14716/ijtech.v10i2.795 (excluded from the count).
- Context only: PELS, arXiv 2311.09645; "Experimental timing and control using microcontrollers", arXiv 2406.17603.

Restricted source documents are kept in `vlsit_sources/` and are not republished by this report.
