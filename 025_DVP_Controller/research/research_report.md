# DVP Camera Interface Research for Controller Design

**Search date:** 2026-11-21  
**Status:** **INCOMPLETE source corpus** — 10/10 sensor datasheets and 9/10 peer-reviewed full-text papers are locally present and hash-checked. The approved P10 public author copy could not be downloaded.  
**Scope:** Source-synchronous parallel image-sensor output commonly called DVP; configuration buses and output processing are treated as adjacent integration functions.

## 1. Executive findings

1. The reviewed sensor documents use DVP-style parallel pixel outputs, but the term does not identify one universal electrical/timing protocol. The ten selected families differ in output width, pixel-clock phase, clock behavior during blanking, sync signal naming, polarity, and sync-format options. The evidence supports a configurable sensor profile, not a hard-coded “DVP standard” assumption.
2. The common capture model is a pixel data bus sampled with the sensor-provided pixel clock while frame and line qualifiers identify useful pixels. Examples include `PCLK + D[9:0] + HREF/VSYNC`, and onsemi parts with `PIXCLK + DOUT + LINE_VALID/FRAME_VALID`. A selected profile must bind the signal meaning and polarity.
3. Clock-to-data phase is sensor-specific. The OV7670 timing table specifies data-valid timing relative to a PCLK edge; the MT9P031 says outputs are launched on rising PIXCLK and recommends sampling on falling PIXCLK. A configurable capture edge is needed, then verified against the selected mode’s timing table and board delays.
4. Blanking clock behavior is not uniform. OV7670 and OV7725 document free-running versus gated pixel-clock behavior; MT9V024 specifies continuous PIXCLK through blanking. The capture logic must use validity qualifiers rather than assume blanking stops the clock or that each PCLK cycle carries an active pixel.
5. DVP sensor output is not backpressure-capable. Capture must accept every active pixel even if the system bus stalls. Use an asynchronous FIFO from PCLK to the SoC clock domain, sticky overflow/error status, and an explicit drop/abort policy. Use DMA or external frame memory when a complete frame or random access is required.
6. SCCB/I²C is a separate sensor-configuration interface, not part of the parallel pixel transfer. XCLK, reset, and power-down are board/control functions. A camera controller may integrate these blocks, but should expose them as distinct functions.
7. ITU-R BT.656 is a separate digital component-video interface with embedded SAV/EAV timing-reference codes for the specified 525/625-line, 4:2:2 systems. It is not evidence for a universal CMOS sensor DVP protocol. If required, add it as a distinct parser mode.
8. The source sample is purposive and not a market census. `n/10` observations below describe only the selected files and must not be interpreted as market share or universal prevalence.

## 2. Search protocol and source selection

The search was frozen on 2026-11-21. Queries covered manufacturer DVP/parallel camera-sensor datasheets, PCLK/VSYNC/HREF timing, FPGA image-acquisition research, open-access full text, and the relevant ITU recommendation. Technical claims were prioritized from manufacturer documents and standards bodies; peer-reviewed papers were included for implementation context. Abstract-only sources were not counted as full-text papers.

The product set includes five OmniVision families and five onsemi families, selected to expose timing and sync variation rather than estimate vendor share. The paper set includes direct DVP/system papers and adjacent camera-acquisition papers. P09 is a 3CCD system paper and is not evidence for CMOS DVP electrical timing. P10 was part of the approved batch but is absent locally, so the corpus is incomplete.

The downloader/checker validates local file presence, distinct product-family keys, distinct work identifiers, and SHA-256 integrity. It does not independently establish that a source is relevant, peer-reviewed, technically correct, or legally reusable. Those points were reviewed separately in this report and manifest.

## 3. What “DVP” means in this evidence set

In this report, **DVP** means a parallel, source-synchronous pixel-output interface on an image sensor. It commonly has:

- a sensor-generated pixel clock (`PCLK` or `PIXCLK`);
- a parallel pixel bus (for example, 8, 10, or 12 data bits);
- frame and line/pixel-valid indications, often named `VSYNC`, `HREF`, `FRAME_VALID`, or `LINE_VALID`;
- optional configuration and board-control signals outside the pixel stream.

The signal names do not guarantee identical semantics. `HREF` may denote a line-active level or be configurable to resemble a horizontal sync pulse; `LINE_VALID` can have selectable formats on some sensors; frame and line polarities can be programmable. A controller therefore needs a profile that records the chosen sensor mode and normalizes it into internal `sof`, `sol`, `pixel_valid`, `eol`, and `eof` events.

The reviewed set supports the observation that DVP is used as a category/name for sensor-specific parallel interfaces. It does **not** prove that no other formal standard exists anywhere. No universal normative DVP timing document was identified in the sources reviewed.

### DVP and BT.656 are not interchangeable

[ITU-R BT.656-5](https://www.itu.int/rec/R-REC-BT.656-5-200712-I/en) describes a digital component-video interface for the specified 525/625-line systems based on BT.601 4:2:2. It includes embedded timing-reference codes (SAV/EAV) and 8/10-bit words. Many CMOS sensor DVPs instead use separate frame/line qualifiers and raw or sensor-formatted pixel data. Treat BT.656 as a separate interface/parser option if the product needs it; do not silently reuse BT.656 assumptions for a sensor DVP port.

## 4. Sensor-family evidence

| ID | Family/document | Width and signals observed | Timing/configuration evidence and locator |
|---|---|---|---|
| D01 | [OV7670/OV7171](https://www.olimex.com/Products/Components/Camera/CAMERA-OV7670/resources/OV7670.pdf), OmniVision | 8-bit pixel output, PCLK, HREF, VSYNC | Datasheet p. 5 gives PCLK-to-data valid/setup/hold timing. p. 12 COM10 documents free-running or gated PCLK during horizontal blanking and polarity/reversal controls. |
| D02 | [OV2640](https://www.sunnywale.com/uploadfile/2023/0603/OV2640_FullDS_V2.2_Awin.pdf), OmniVision | Parallel data output through D[9:0]; format-dependent active width | pp. 13–14, Fig. 12/Table 10 and frame-timing figures show pixel-clock, data, HREF, and VSYNC relationships. The timing values are tied to operating mode. |
| D03 | [OV3640](https://www.welectron.com/mediafiles/productimg/arducam/Image_Sensor/OV3640_DS.pdf), OmniVision | 10-bit parallel output; HREF/HSYNC and frame timing options | p. 40 §6.1 describes DVP output and HSYNC mode; p. 60 Table 8-6 gives PCLK-to-HREF/data timing. The document notes values can vary with register settings. |
| D04 | [OV7725](https://cdn.sparkfun.com/datasheets/Sensors/LightImaging/OV7725.pdf), OmniVision | 8/10-bit image formats, D[9:0], PCLK, HREF/VSYNC | p. 15 COM10 covers free-run/gated PCLK, PCLK/HREF reversal, HREF-to-HSYNC mode, and VSYNC polarity. Mouser returned HTML; the local copy came from the public SparkFun mirror. |
| D05 | [OV5640](https://cdn-learn.adafruit.com/assets/assets/000/118/994/original/OV5640_datasheet.pdf), OmniVision | D[9:0] with HREF/HSYNC/VSYNC and PCLK | p. 93 Fig. 6-7/Table 6-7 lists DVP timing; values depend on register-selected configuration. The datasheet states proprietary/no-redistribution restrictions. |
| D06 | [MT9V034](https://www.onsemi.com/pdf/datasheet/mt9v034-d.pdf), onsemi | 10-bit parallel output, PIXCLK, LINE_VALID/FRAME_VALID | p. 8 output timing states one 10-bit pixel per PIXCLK while LINE_VALID is high and gives data setup/hold timing. p. 29 describes line-valid formats. |
| D07 | [MT9V022](https://www.onsemi.com/pdf/datasheet/mt9v022-d.pdf), onsemi | 10-bit parallel output, PIXCLK, line/frame validity | pp. 22–23 describe default, continuous, and XOR-style LINE_VALID/FRAME_VALID options. A fixed interpretation of the valid signals can therefore be wrong for a selected register mode. |
| D08 | [MT9V024](https://www.onsemi.com/pdf/datasheet/mt9v024-d.pdf), onsemi | 10-bit DOUT, PIXCLK, LINE_VALID/FRAME_VALID | p. 7 states a valid 10-bit value is output per PIXCLK when LINE_VALID is high; PIXCLK continues during blanking and its polarity can be inverted. |
| D09 | [MT9M034](https://www.onsemi.com/pdf/datasheet/mt9m034-d.pdf), onsemi | 12-bit linear output, PIXCLK, frame/line validity | pp. 29–30 provide PIXCLK-to-data/frame/line output timing. The front-page features list 12-bit linear raw output and dedicated frame/line signals. |
| D10 | [MT9P031](https://www.onsemi.com/pdf/datasheet/mt9p031-d.pdf), onsemi | 12-bit pixel output, PIXCLK, line/frame validity | p. 12 and timing table show outputs launched on rising PIXCLK and recommend capture on falling PIXCLK; polarity and relative phase are configurable. |

### Selected-set occurrences

| Feature coded from datasheets | Selected set |
|---|---:|
| Parallel pixel output | 10/10 |
| Sensor-generated pixel clock | 10/10 |
| Frame/line indication or qualifier | 10/10 |
| 8-bit data mode or 8-bit pixel format | Present in OV7670, OV2640/OV7725 modes; verify exact selected mode |
| 10-bit-capable port or mode | Present in OV2640, OV3640, OV7725, OV5640, MT9V034, MT9V022, MT9V024 |
| 12-bit output mode | MT9M034 and MT9P031 |
| Explicit blanking-clock behavior discussed | OV7670, OV7725, and MT9V024 examples |
| Explicit alternate edge/polarity/sync-format control | Examples include OV7670, OV7725, MT9V022, MT9V024, and MT9P031 |

These counts are conservative coding over the ten chosen datasheets, not market estimates. They do not imply every listed feature is enabled by default.

## 5. Paper corpus and relevance

The manifest holds nine complete local paper files:

| ID | Paper | Relevance |
|---|---|---|
| P01 | Khan & Wahid, “A DVP-Based Bridge Architecture to Randomly Access Pixels of High-Speed Image Sensors,” EURASIP Journal on Embedded Systems (2011), DOI [10.1155/2011/270908](https://doi.org/10.1155/2011/270908) | Direct DVP bridge architecture, capture buffering, random pixel access; publisher-hosted open-access PDF. |
| P02 | Bravo et al., “Efficient Smart CMOS Camera Based on FPGAs Oriented to Embedded Image Processing,” Sensors (2011), DOI [10.3390/s110302282](https://doi.org/10.3390/s110302282) | FPGA camera pipeline and embedded image processing context. |
| P03 | da Silva et al., “A Manycore Vision Processor for Real-Time Smart Cameras,” Sensors (2021), DOI [10.3390/s21217137](https://doi.org/10.3390/s21217137) | Downstream real-time smart-camera architecture and throughput context. |
| P04 | Zadnik & Žemva, “Image Acquisition Device for Smart-City Access Control Applications Based on Iris Recognition,” Sensors (2021), DOI [10.3390/s21186185](https://doi.org/10.3390/s21186185) | Explicitly reports FPGA acquisition over a digital video port; application-level design evidence. |
| P05 | Liu et al., “Toward a Smartphone Application for Estimation of Pulse Transit Time,” Sensors (2015), DOI [10.3390/s151027303](https://doi.org/10.3390/s151027303) | Camera application and image-processing constraints; not a DVP electrical specification. |
| P06 | Liu et al., “A Novel Method Based on Two Cameras for Accurate Estimation of Arterial Oxygen Saturation,” BioMedical Engineering OnLine (2015), DOI [10.1186/s12938-015-0045-1](https://doi.org/10.1186/s12938-015-0045-1) | Two-camera application; adjacent system context. |
| P07 | Frontoni et al., “Embedded Vision Sensor Network for Planogram Maintenance in Retail Environments,” Sensors (2015), DOI [10.3390/s150921114](https://doi.org/10.3390/s150921114) | Embedded camera-network processing context. |
| P08 | Lu, Wang & Fan, “Photometric Calibration and Image Stitching for a Large Field of View Multi-Camera System,” Sensors (2016), DOI [10.3390/s16040516](https://doi.org/10.3390/s16040516) | Multi-camera integration context; uses OV3640. |
| P09 | Lee et al., “Development of a Portable 3CCD Camera System for Multispectral Imaging of Biological Samples,” Sensors (2014), DOI [10.3390/s141120262](https://doi.org/10.3390/s141120262) | CCD system, not CMOS DVP; included only as adjacent camera synchronization/buffering context. |
| P10 | Liu, Wang & Liu, “Image Acquisition and Storage System of Binocular Camera Based on FPGA,” CAIBDA 2023, DOI [10.3233/FAIA230859](https://doi.org/10.3233/FAIA230859) | Approved target paper; public full text is shown at ResearchGate under CC BY-NC 4.0, but local PDF retrieval failed. Not counted as locally acquired. |

Only P01 is a direct architectural paper about generic DVP bridging. The local paper count is **9**, below the skill threshold of 10. P10 must remain marked missing until a full-text file can be obtained through a permitted public endpoint. This report therefore carries **INCOMPLETE** status even though the ten product-family threshold is met.

## 6. Recommended controller architecture

### Capture boundary

Use the external sensor PIXCLK as the capture clock for the input sampling registers. Capture the data bus and relevant frame/line qualifiers in that same clock domain. Do not synchronize each data bit independently through a two-flop synchronizer; independent bit synchronizers can destroy the coherent pixel word. Apply CDC only after the pixels/events have been captured as a word and enqueued in a correctly designed asynchronous FIFO.

Provide one programmable profile (or compile-time family profile) with:

- active bus width: 8, 10, or 12 bits, with explicit bit-lane mapping;
- sample edge: rising or falling PIXCLK;
- frame source and line/data-enable source selection;
- active-high/active-low polarity for frame and line signals;
- sync interpretation for level-valid versus pulse-style HREF/HSYNC where supported;
- optional validation of expected active pixels per line and lines per frame;
- optional PCLK-present timeout and frame/line timeout behavior.

### Data-path and backpressure

Normalize captured input to an internal event/stream such as {pixel_data, pixel_valid, sof, sol, eol, eof}. Keep format conversion and byte packing after electrical capture so RGB565, YUV, Bayer/raw, and sensor-specific packing do not complicate edge sampling.

Write every valid sample into an asynchronous FIFO. Since the sensor cannot be stalled by downstream ready, define FIFO overflow as a first-class fault: sticky status, counter, optional interrupt, and deterministic policy (discard the remainder of the frame or drop samples until the next frame boundary). Do not silently pause the DVP capture clock. Use DMA or frame memory for full-frame storage; a FIFO alone is a rate-matching buffer, not a frame buffer.

### Configuration and status registers to consider

| Register group | Suggested fields |
|---|---|
| Control | enable, soft reset, frame-boundary stop, profile select |
| Input profile | data width, data lane map, sample edge, input sync mode |
| Polarity | frame/line/pixel-valid active levels; optional clock polarity |
| Geometry | expected active pixels per line and active lines per frame |
| Stream | pixel format/packing, FIFO watermark, drop policy |
| Status | busy, current frame/line, FIFO level, sticky overflow, malformed frame/line, missing-clock timeout |
| Counters | captured frames/pixels, overflow count, length errors, timeout count |
| Separate sensor-control block | optional SCCB/I²C sequencer and XCLK/reset/power-down controls |

This is a research recommendation, not a frozen CSR specification. Define each register against the actual target SoC bus, reset scheme, interrupt policy, and chosen sensor before RTL implementation.

### Pin-count recommendation for broad parallel-sensor compatibility

Reserve the package/pad budget for:

- PCLK (1);
- D[11:0] (12; supports the widest bus in the selected ten-family corpus);
- frame-valid/VSYNC (1);
- line-valid/HREF or data-enable (1);
- optional HSYNC if a selected sensor mode needs a separate pulse (1).

This gives **15 mandatory capture pins** plus **one optional HSYNC**. Add optional SCCB SCL/SDA (+2), sensor XCLK (+1), reset (+1), and power-down (+1): **up to 21 pins** when all optional control pins and HSYNC are brought to the controller. Narrower sensors may leave upper data lanes unused. The board still must meet each sensor's I/O voltage and timing; reserving 12 bits does not make voltages or pin mapping universally compatible.

## 7. Clock, CDC, and physical-design requirements

- Treat the incoming sensor pixel clock as a clock input with an explicit clock constraint. Add input delay constraints for data, frame, line, and any other sampled signals relative to the selected sensor output timing.
- Confirm min/max clock-to-output, setup/hold, PCLK duty cycle, and PCB skew from the exact sensor revision and selected mode. The table values from one sensor cannot substitute for another.
- Synchronize only control/status crossings that are asynchronous and not part of the source-synchronous pixel word. Use a dual-clock FIFO or equivalent proven CDC structure for the pixel stream.
- Budget FIFO depth from worst-case downstream stall and active pixel burst, including arbitration latency and clock ratios. Verify that the chosen overflow policy is observable in software.
- Check I/O pad voltage tolerance, bank supply, pin timing, and any required level shifting. The selected docs span different I/O ranges; “DVP” does not imply 5-V tolerance or a common rail.
- Sensor initialization is mode-specific. SCCB register tables should be a software/configuration artifact or a separate sequencer profile; they are not a universal DVP protocol.

## 8. Suggested software bring-up sequence

1. Hold capture disabled; configure board-level reset, power-down, and sensor XCLK if used.
2. Program the sensor over SCCB/I²C using the exact module/sensor register sequence. Select resolution, output format, data width, sync mode, PCLK behavior, and polarity together.
3. Program the controller profile to match the sensor configuration and board pin mapping.
4. Set expected active dimensions, FIFO threshold, and overflow policy; clear sticky status and counters.
5. Enable capture before or at a safe frame boundary; discard the first partial frame if the application requires a clean frame.
6. Verify pixel/frame counters, line lengths, FIFO high-water mark, and error flags while capturing.
7. Stop at a frame boundary, disable the sensor stream if needed, then gate clocks or change configuration.

## 9. Patent and rights scan (preliminary)

This is a focused public search, not freedom-to-operate or legal advice. It covers selected US records only and does not establish claim scope, enforceability, family status in other countries, or product risk.

| Record | Public record summary | Relevance / limitation |
|---|---|---|
| [US9407844B1, Hardware partial frame elimination in a sensor interface](https://patents.google.com/patent/US9407844B1/en) | US grant; priority 2010-01-20, filed 2014-07-17, granted 2016-08-02; Google Patents currently labels it Active. | Frame-start/partial-frame handling is adjacent to capture control. Status is an aggregator assertion, not a legal conclusion; assess claims and family in relevant jurisdictions with counsel if productization requires it. |
| [US7471333B2, Image sensing device interface unit](https://patents.google.com/patent/US7471333B2/en) | US grant; priority 2004-03-25; Google Patents labels “Expired - Fee Related,” with an indicated expiry date of 2026-11-22. | Interface power management and missing-line detection are adjacent. Verify status through USPTO and assess continuation/family claims; do not infer freedom to operate. |
| [US6927790B2, Digital camera system providing for control of a camera's operational parameters and image capture](https://patents.google.com/patent/US6927790B2/en) | US grant; Google Patents labels it “Expired - Fee Related.” | Claims include sensor pixel-clock/FIFO concepts. This is background evidence only; expiration/status should be independently confirmed before relying on it. |

The OmniVision and onsemi datasheets carry manufacturer copyright/proprietary notices and remain research copies only. P01 is open access under a Creative Commons Attribution license (publisher PDF front page). P02–P09 are stored from the PMC open-access dataset with article-level CC BY notices. P10's publisher page states CC BY-NC 4.0; do not redistribute it commercially or without required attribution. No proprietary datasheet is included in the report as a rehosted attachment outside this research folder.

## 10. Open decisions before an implementation specification

- Select the actual sensor/module(s), board pinout, electrical I/O rail, and sensor register mode.
- Decide whether the core should support only separate frame/line qualifiers, or also a pulse-style HSYNC profile.
- Decide expected geometry enforcement and the exact partial-frame/overflow recovery policy.
- Define the SoC bus, DMA ownership, interrupts, reset behavior, and register compatibility requirements.
- Determine if BT.656 is a separate product requirement.
- Complete the source threshold by locally acquiring P10 through an accessible public endpoint or by approving an equivalent replacement full-text paper.

Until these are fixed, the architecture above is the recommended configurable baseline for a DVP controller, not an RTL-ready sign-off specification.
