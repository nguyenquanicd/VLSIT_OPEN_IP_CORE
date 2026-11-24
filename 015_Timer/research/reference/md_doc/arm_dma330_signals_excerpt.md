---
protocol: "Arm CoreLink DMA-330 peripheral request interface signals"
revision: "ARM DDI 0424D r1p2, page A-7 excerpt"
source: "https://documentation-service.arm.com/static/5e8e25befd977155116a5ad9"
license: "Arm Limited proprietary technical reference manual"
redistribution: "forbidden"
retrieved: 2026-11-04
source_sha256: "ab5a380b1866a24e297027670a8824cc2c9dd418e69b4a86415dc1647d3e29e5"
converter: "vlsit_pdf_to_md.py (PyMuPDF)"
---

# Arm CoreLink DMA-330 peripheral request interface signals - revision ARM DDI 0424D r1p2, page A-7 excerpt

> **Key notes (written by the converter operator, not part of the source):**
> - Verbatim excerpt of page A-7, Table A-9, defining the DMA-330 peripheral request and acknowledge signals. Redistribution is forbidden; retain this excerpt locally for engineering reference and exclude it from version control.

> The text between the markers below is the source text, converted without rewording.

<!-- BEGIN VERBATIM SOURCE -->

<!-- page 132 -->

Signal Descriptions

A.4
Peripheral request interface

Table A-9 shows the peripheral request interface signals that the DMAC provides, after you
configure it to have one or more peripheral request interfaces.

Note
You can configure a DMAC to not have any peripheral request interfaces. See the CoreLink
DMA-330 DMA Controller Supplement to AMBA Designer ADR-400 User Guide for more
information.

Table A-9 Peripheral request interface

| Namea | Type | Source/ destination | Description |
|---|---|---|---|
| daready_<x> | Input | Peripheral | Indicates whether the peripheral can accept the information that the DMAC provides on datype_<x>[1:0]: 0 = peripheral not ready 1 = peripheral ready. |
| datype_<x>[1:0] | Output | Peripheral | Indicates the type of acknowledgement, or request, that the DMAC signals: = the DMAC has completed the single DMA transfer 0b00 = the DMAC has completed the burst DMA transfer 0b01 = DMAC requesting the peripheral to perform a flush request 0b10 0b11 = reserved. |
| davalid_<x> | Output | Peripheral | Indicates when the DMAC provides valid control information: 0 = no control information is available 1 = datype_<x>[1:0] contains valid information for the peripheral. |
| drlast_<x> | Input | Peripheral | Indicates that the peripheral is sending the last data transfer for the current DMA transfer: 0 = last data request is not in progress 1 = last data request is in progress. Note The DMAC only uses this signal when drtype_<x>[1:0] is or 0b01. 0b00 |
| drready_<x> | Output | Peripheral | Indicates whether the DMAC can accept the information that the peripheral provides on drtype_<x>[1:0]: 0 = DMAC not ready 1 = DMAC ready. |
| drtype_<x>[1:0] | Input | Peripheral | Indicates the type of acknowledgement, or request, that the peripheral signals: = single level request 0b00 0b01 = burst level request = acknowledging a flush request that the DMAC requested 0b10 = reserved. 0b11 |
| drvalid_<x> | Input | Peripheral | Indicates when the peripheral provides valid control information: 0 = no control information is available 1 = drtype_<x>[1:0] and drlast_<x> contain valid information for the DMAC. |

a.
Where <x> is the number for a peripheral request interface. The valid numbers for x depend on the configuration of the DMAC.

ARM DDI 0424D
Copyright © 2007, 2009-2010, 2012 ARM. All rights reserved.
A-7
ID072812
Non-Confidential

<!-- END VERBATIM SOURCE -->
