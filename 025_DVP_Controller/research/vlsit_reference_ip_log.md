# DVP Controller Reference-IP Research Log

Date: 2026-11-21
Purpose: Find implementation evidence that can inform the DVP Controller micro-specification. Search results are not treated as proof of compliance or reusable RTL.

## Search queries and sources

| Query / source | What was reviewed | Result |
|---|---|---|
| `DVP camera sensor capture FPGA` through `vlsit_ip_search.py search --source both --limit 10` | GitHub and Gitee candidate search | `overcookedlobster/arty-ov2640-vga` appeared with score 3; no license or qualified test evidence was established. No qualified IP. |
| `DVP 摄像头 FPGA 采集` through `vlsit_ip_search.py search --source both --limit 10` | Chinese-language GitHub/Gitee candidate search | Candidate pages included `Jingyusu888/ac880pro-zynq7020-ov5640-hdmi`, `AAAAAZURE/camera360`, and related camera repositories. Evidence was checked on the repository pages; none passed all reuse gates. |
| [ArteryTek AN0087, AT32 DVP Application Note](https://www.arterytek.com/download/APNOTE/AN0087_AT32_MCU_DVP_Application_Note_ZH_V2.0.1.pdf) | Official vendor note, pp. 10–11 and sync-mode discussion | Documents a vendor-specific peripheral with selectable PCLK capture edge and hardware-sync versus embedded-code sync modes. Confidence: high for the AT32 peripheral only; not a universal DVP rule or reusable reference IP. |
| [ZYNQ underwater stereo camera acquisition article (2024)](https://joi.usst.edu.cn/html/2024/3/20240310.htm) | Chinese-language journal article | Reports OV5640 capture, sensor initialization, AXI4-Stream/VDMA and external memory in a ZYNQ system. Confidence: medium for the reported system architecture; not independently reproduced here and not a reusable reference IP. |
| [Jingyusu888/ac880pro-zynq7020-ov5640-hdmi](https://github.com/Jingyusu888/ac880pro-zynq7020-ov5640-hdmi) | Chinese GitHub README, hardware/clock/throughput sections, verification and licensing statements | Describes OV5640 8-bit DVP capture at 1280×720, async FIFO, AXI4/DDR3L, Vivado 2018.3, timing reports and a board display. The README lists tests for FIFO/TMDS/video timing/etc.; a dedicated DVP-capture testbench was not established. Its own README limits its content to reading/study and prohibits commercial use and redistribution. Confidence: medium for the self-reported FPGA system, low for DVP-specific verification. Excluded for product reuse. |
| [AAAAAZURE/camera360](https://github.com/AAAAAZURE/camera360) | Chinese GitHub repository summary and visible file inventory | Claims a Tang Mega 138K design with three OV5640 DVP inputs, image stitching and 1280×720@60 output. The visible repository page did not establish a license or verification results. Confidence: low; excluded. |
| [love-sabers/FPGA_ISP](https://github.com/love-sabers/FPGA_ISP) | Chinese GitHub README sections on DVP capture, parameters, data packing and FPGA target | Describes PCLK/HREF/Vsync capture, 8-bit samples, RGB565 byte packing, FIFO use and frame discard. No clear project license or DVP testbench evidence was found. Confidence: low; excluded. Automated evaluation through the skill script failed with a DNS/network error; the page was reviewed through the available web source. |
| [CSDN OV5640 DVP tutorial](https://openvela.csdn.net/694bbc535b9f5f31781a5c82.html) | Chinese-language tutorial | Used only as a low-confidence explanatory cross-check; no licence, testbench, or independently verifiable FPGA/silicon evidence was established. Confidence: low; not used as reference RTL. |

## Candidate decisions

| Candidate | Direction | Evidence found | Licence evidence | Decision |
|---|---|---|---|---|
| `overcookedlobster/arty-ov2640-vga` | GitHub | Search score 3; no adequate FPGA/silicon and verification package was established from the search result | Not identified | EXCLUDED: licence and qualification evidence not met. |
| `Jingyusu888/ac880pro-zynq7020-ov5640-hdmi` | GitHub, Chinese project | Self-reports Zynq-7020/OV5640 FPGA display, Vivado implementation and multiple module testbenches; DVP-specific testbench not established | Project README says reading/study only; commercial use and redistribution prohibited | EXCLUDED: unsuitable reuse terms; DVP verification evidence also incomplete. Informative architecture evidence only. |
| `AAAAAZURE/camera360` and related `360_camera`, `camera`, `camera260`, `360camera` results | GitHub, Chinese results | Camera/DVP system claims; no qualifying RTL verification evidence established | No clear licence identified on reviewed page(s) | EXCLUDED: licence and verification gates not met. |
| `love-sabers/FPGA_ISP` | GitHub, Chinese project | README describes DVP capture and FPGA implementation; no DVP verification suite was established in the reviewed page | No clear project licence identified | EXCLUDED: licence and verification gates not met. |

**Qualified reference IPs: none.** A search score or self-reported system result alone is not qualification evidence. No repository was cloned or downloaded, and no code is included or proposed for reuse.

## Chinese-language source notes and confidence

| Source | English technical summary | Confidence and limit |
|---|---|---|
| [ArteryTek AN0087](https://www.arterytek.com/download/APNOTE/AN0087_AT32_MCU_DVP_Application_Note_ZH_V2.0.1.pdf) | The vendor's AT32 DVP block samples sensor-driven PCLK on a selectable edge and supports separate hardware sync or an embedded sync-code mode. The note also describes polarity and sync-code configuration. | High confidence for that vendor peripheral and note revision; not evidence that all DVP sensors use or require those modes. |
| [ZYNQ underwater stereo camera article](https://joi.usst.edu.cn/html/2024/3/20240310.htm) | The reported system initializes OV5640 externally, captures PCLK/VSYNC/HREF in programmable logic, and uses AXI4-Stream/VDMA plus external DDR for frame storage. | Medium confidence as an application architecture reported in a journal; not independently reproduced and not a controller implementation specification. |
| [Jingyusu888 OV5640 project](https://github.com/Jingyusu888/ac880pro-zynq7020-ov5640-hdmi) | The README describes an 8-bit OV5640 DVP path, conversion of consecutive bytes into RGB565, async FIFO crossing, AXI burst writes, and external DDR triple buffering. It reports a board display and timing/test results but says some clocks/bandwidth were not measured. | Medium confidence for the self-reported FPGA system; low for DVP-specific test closure. The stated license restrictions prevent product reuse. |
| [love-sabers/FPGA_ISP](https://github.com/love-sabers/FPGA_ISP) | The README describes sampling Vsync/HREF/data on rising PCLK, combining two 8-bit transfers into RGB565, buffering, and discarding initial frames. | Low confidence: repository claims only; no clear license or DVP testbench evidence. Not used as reference RTL. |
| [AAAAAZURE/camera360](https://github.com/AAAAAZURE/camera360) | The repository summary describes three OV5640 DVP camera inputs, FPGA image fusion, and 1280×720@60 output. | Low confidence: summary claims only; no qualifying verification or licence evidence was found. |
| [CSDN OV5640 tutorial](https://openvela.csdn.net/694bbc535b9f5f31781a5c82.html) | Describes byte/sample ordering and frame/line signal interpretation for one OV5640 receiver example. | Low confidence: tutorial material without a reusable licence or verification record. |

## Findings used to shape the specification discussion

1. The reviewed sensor corpus uses source-synchronous parallel data with sensor-generated PCLK and frame/line qualifiers. Signal names, polarities, active-level semantics and timing are sensor- and mode-specific; the controller must define a selected profile and cite exact sensor datasheets.
2. The reviewed product datasheets include 8-, 10- and 12-bit sample widths and examples of selectable sampling edge, polarity, qualifier format, and PCLK behavior. These findings support the user's choice of compile-time profiles; they do not prove universal camera compatibility.
3. One DVP sample per PCLK is not always one complete color pixel. For example, an 8-bit sensor output may emit two samples for a 16-bit RGB565 pixel. The DVP controller scope therefore needs to state whether it forwards raw bus samples or performs format packing; the user selected capture-only, so no color conversion is assumed.
4. A sensor cannot generally be backpressured by a slow downstream APB requester. Buffering and deterministic overflow reporting/recovery are required, and the APB read rate must be checked against the user's numeric workload.
5. A vendor DVP peripheral and some camera systems use embedded sync or external frame memory, but these are optional architecture examples. The user selected frame-valid plus line-valid/HREF and excluded embedded-code parsing and integrated DMA.
6. No qualified open-source DVP reference IP was identified. The micro-specification is based on the user's decisions, sensor datasheets, and the exact APB standard; no candidate RTL is copied.

## Limitations and work not performed

- Repository searches did not identify a reference IP that met the combined validation, DVP-relevant verification, and licence criteria.
- Automated `vlsit_ip_search.py evaluate` could not retrieve `love-sabers/FPGA_ISP` because of a DNS/network error; the repository page was reviewed separately, and the failure was not treated as qualification evidence.
- No repository was cloned/downloaded, no RTL was audited, and no claim is made about ASIC tapeout readiness of excluded candidates.
- This log is not a market survey, legal opinion, protocol standard, or freedom-to-operate assessment.
