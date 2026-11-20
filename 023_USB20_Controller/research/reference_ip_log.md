# Reference IP research log (rules R-010, R-011, R-012)

Date: 2026-11-20. Tool: `vlsit_ip_search.py search` (GitHub API, no token). Nothing was downloaded or copied.

| Query | Candidate | Licence | Evidence found | Decision |
|---|---|---|---|---|
| usb ulpi | ultraembedded/core_ulpi_wrapper (https://github.com/ultraembedded/core_ulpi_wrapper) | GPL-3.0 | FPGA, verification | QUALIFIED for the ULPI wrapper idea only; GPL-3.0 code is not copied; not downloaded |
| usb ulpi / usb host controller | ultraembedded/core_usb_host (https://github.com/ultraembedded/core_usb_host) | GPL-3.0 | FPGA only | Excluded: no verification evidence |
| usb ulpi | lambdaconcept/lambdaUSB (https://github.com/lambdaconcept/lambdaUSB) | BSD-2-Clause | FPGA only | Excluded: no verification evidence |
| usb ulpi | tomverbeure/usb_system (https://github.com/tomverbeure/usb_system) | none | FPGA, verification | Excluded: no licence |
| usb2 device | esynr3z/usb20dev (https://github.com/esynr3z/usb20dev) | MIT | FPGA only | Excluded: no verification evidence |
| usb2 device | www-asics-ws/usb2_dev (https://github.com/www-asics-ws/usb2_dev) | NOASSERTION | none | Excluded: no evidence, no licence |
| usb_cdc | ulixxe/usb_cdc (https://github.com/ulixxe/usb_cdc) | MIT | FPGA, verification | Qualified by the filter but full-speed device CDC only; not used as a reference for this scope |
| usb host controller | yeokm1/xhci98, others | various | none | Excluded |

Gitee search failed on 2026-11-20 (SSL handshake timeout), so no Chinese-language source was read (rule R-011); a manual Gitee search or links from the user are needed.

Design reference that is not a public IP: Synopsys DWC_otg USB 2.0 Hi-Speed OTG databook 5.00b (user supplied). Only its configuration-parameter choices (role, PHY interface, architecture, endpoints, channels, FIFO, LPM, point-to-point/split option) shaped section 8 of the specification; no text was copied.
