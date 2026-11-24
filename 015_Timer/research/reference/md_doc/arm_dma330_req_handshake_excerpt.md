---
protocol: "Arm CoreLink DMA-330 peripheral request interface"
revision: "ARM DDI 0424D r1p2, pages 38-42 excerpt"
source: "https://documentation-service.arm.com/static/5e8e25befd977155116a5ad9"
license: "Arm Limited proprietary technical reference manual"
redistribution: "forbidden"
retrieved: 2026-11-04
source_sha256: "ab5a380b1866a24e297027670a8824cc2c9dd418e69b4a86415dc1647d3e29e5"
converter: "vlsit_pdf_to_md.py (PyMuPDF)"
---

# Arm CoreLink DMA-330 peripheral request interface - revision ARM DDI 0424D r1p2, pages 38-42 excerpt

> **Key notes (written by the converter operator, not part of the source):**
> - Verbatim excerpt of pages 2-16 through 2-20 covering handshake and peripheral length management. Redistribution is forbidden; retain this excerpt locally for engineering reference and exclude it from version control.

> The text between the markers below is the source text, converted without rewording.

<!-- BEGIN VERBATIM SOURCE -->

<!-- page 38 -->

Functional Overview

2.6.1
Mapping to a DMA channel

The DMAC enables you to assign a peripheral request interface to any of the DMA channels.
When a DMA channel thread executes DMAWFP, the value programmed in the peripheral [4:0]
field specifies the peripheral associated with that DMA channel. See DMAWFP on page 4-18.

2.6.2
Handshake rules

The DMAC uses the DMA handshake rules that Table 2-2 shows, when a DMA channel thread
is active, that is, not in the Stopped state. See Peripheral request interface timing diagrams on
page 2-21 for more information.

Table 2-2 Handshake rules

| Rule | Descriptiona |
|---|---|
| 1 | drvalid can change from LOW to HIGH on any aclk cycle, but it must only change from HIGH to LOW when drready is HIGH. |
| 2 | drtype can only change when either: • drready is HIGH. • drvalid is LOW. |
| 3 | drlast can only change when either: • drready is HIGH. • drvalid is LOW. |
| 4 | davalid can change from LOW to HIGH on any aclk cycle, but it must only change from HIGH to LOW when daready is HIGH. |
| 5 | datype can only change when either: • daready is HIGH. • davalid is LOW. |

a.
All signals are only permitted to change state when aclk changes state.

2.6.3
Request acceptance capability configuration

During configuration of the DMAC, you can set the number of simultaneous active requests that
a DMAC is able to accept, for each peripheral request interface. An active request is where the
DMAC has not started the requested AXI data transfers.

For each peripheral interface, the DMAC has a request FIFO that it uses to capture the requests
from a peripheral. The depth of a FIFO depends on the number of simultaneous active requests
that the corresponding peripheral request interface is configured to support. To store the state of
an active request from the peripheral, the request FIFO uses two bits to store the state of:

•
drtype_<x>[0]. Indicates the request type, burst or single.

•
drlast_<x>. Indicates if the peripheral is requesting the last data transfer of the DMA
transfer.

When a request FIFO is full then the DMAC sets the corresponding drready_<x> LOW to
signal that the DMAC cannot accept any requests sent from the peripheral.

ARM DDI 0424D
Copyright © 2007, 2009-2010, 2012 ARM. All rights reserved.
2-16
ID072812
Non-Confidential

<!-- page 39 -->

Functional Overview

2.6.4
Peripheral length management

The peripheral request interface enables a peripheral to control the quantity of data that a DMA
cycle contains, without the DMAC being aware of how many data transfers it contains. The
peripheral controls the DMA cycle by using:
•
drtype[1:0] to select a single or burst transfer.
•
drlast to notify the DMAC when it commences the final request in the current series.

When the DMAC executes a DMAWFP periph instruction, it halts execution of the thread and waits
for the peripheral to send a request. When the peripheral sends the request, the DMAC sets the
state of the request flags depending on the state of the following signals:

drtype_<x>[1:0]
The DMAC sets the state of the request_type flag:

drtype_<x>[1:0]=0b00

request_type<x> = Single.

drtype_<x>[1:0]=0b01

request_type<x> = Burst.

drlast_<x>
The DMAC sets the state of the request_last flag:

drlast_<x>=0
request_last<x> = 0.

drlast_<x>=1
request_last<x> = 1.

Note
If the DMAC executes a DMAWFP single or DMAWFP burst instruction then the DMAC sets:
•
The request_type<x> flag to Single or Burst, respectively.
•
The request_last<x> flag to 0.

DMALPFE is an assembler directive that forces the associated DMALPEND instruction to have its nf bit
set to 0. This creates a program loop that does not use a loop counter to terminate the loop. The
DMAC exits the loop when the request_last flag is set to 1.

The DMAC conditionally executes the following instructions, depending on the state of the
request_type and request_last flags:

DMALD, DMAST, DMALPEND

When these instructions use the optional B|S suffix then the DMAC executes a

DMANOP if the request_type flag does not match.

DMALDP<B|S>, DMASTP<B|S>

The DMAC executes a DMANOP if the request_type flag does not match the B|S
suffix.

DMALPEND
When the nf bit is 0, the DMAC executes a DMANOP if the request_last flag is set.

Use the DMALDB, DMALDPB, DMASTB and DMASTPB instructions if you require the DMAC to issue a
burst transfer when the DMAC receives a burst request, that is, drtype_<x>[1:0] = 0b01. The
values in the CCRn Register control the amount of data that the DMAC transfers, see Channel
Control Registers on page 3-25.

Use the DMALDS, DMALDPS, DMASTS and DMASTPS instructions if you require the DMAC to issue a
single transfer when the DMAC receives a single request, that is, drtype_<x>[1:0] = 0b00. The
DMAC ignores the value of the src_burst_len and dst_burst_len fields in the CCRn Register and
sets the arlen[3:0] or awlen[3:0] buses to 0x0.

ARM DDI 0424D
Copyright © 2007, 2009-2010, 2012 ARM. All rights reserved.
2-17
ID072812
Non-Confidential

<!-- page 40 -->

Functional Overview

Example program for peripheral length management

Example 2-2 shows a DMAC program that transfers 64 words from memory to peripheral zero,
when the peripheral sends a burst request, that is, drtype_<x>[1:0] = 0b01. When the peripheral
sends a single request, that is, drtype_<x>[1:0] = 0b00, then the DMAC program transfers one
word from memory to peripheral zero.

To transfer the 64 words, the program instructs the DMAC to perform 16 AXI transfers. Each
AXI transfer consists of a 4-beat burst (SB=4, DB=4), each beat of which moves a word of data
(SS=32, DS=32).

Example 2-2 Peripheral length management program

# Set up for burst transfers (4-beat burst, so SB4 and DB4), (word data width, so SS32 and DS32)

DMAMOV CCR SB4 SS32 DB4 DS32
DMAMOV SAR ...
DMAMOV DAR ...

# Initialize peripheral ‘0’
DMAFLUSHP P0

# Perform peripheral transfers
# Outer loop - DMAC responds to peripheral requests until peripheral sets drlast_0 = 1
DMALPFE

# Wait for request, DMAC sets request_type0 flag depending on the request type it receives
DMAWFP 0, periph

# Set up loop for burst request: first 15 of 16 sets of transactions
# Note: B suffix - conditionally executed only if request_type0 flag = Burst
DMALP 15

DMALDB
DMASTB
# Only loop back if servicing a burst, otherwise treat as a NOP
DMALPENDB

# Perform final transaction (16 of 16). Send the peripheral acknowledgement of burst request completion
DMALDB
DMASTPB P0

# Perform transaction if the peripheral signals a single request
# Note: S suffix - conditionally executed only if request_type0 flag = Single
DMALDS
DMASTPS P0

# Exit loop if DMAC receives the last request, that is, drlast_0 = 1
DMALPEND

DMAEND

In Example 2-2, the program shows the use of the:

•
DMAWFP periph instruction. The DMAC waits for either a burst or single request from the
peripheral.

•
DMASTPB and DMASTPS instructions. The DMAC informs the peripheral when a transfer is
complete.

ARM DDI 0424D
Copyright © 2007, 2009-2010, 2012 ARM. All rights reserved.
2-18
ID072812
Non-Confidential

<!-- page 41 -->

Functional Overview

2.6.5
DMAC length management

DMAC length management is when the DMAC controls the total amount of data to transfer. The
peripheral uses the peripheral request interface to notify the DMAC when it requires the DMAC
to transfer data to or from the peripheral. The DMA channel thread controls how the DMAC
responds to the peripheral requests.

The following constraints apply to DMAC length management:

•
The total quantity of data for all the single requests from a peripheral must be less than the
quantity of data for a burst request for that peripheral.

Note
The CCRn Register controls how much data is transferred for a burst request and a single
request. ARM recommends that you do not update a CCRn Register when a transfer is in
progress for channel n. See Channel Control Registers on page 3-25.

•
When the peripheral sends a burst request then the peripheral must not send a single
request until the DMAC acknowledges that the burst request is complete.

Use the DMAWFP single instruction when you require the program thread to halt execution until
the peripheral request interface receives any request type.

If the head entry in the request FIFO is of request type:

Single
The DMAC pops the entry from the FIFO and continues program execution.

Burst
The DMAC leaves the entry in the FIFO and continues program execution.

Note
The burst request entry remains in the request FIFO until the DMAC executes a

DMAWFP burst instruction or a DMAFLUSHP instruction.

Use the DMAWFP burst instruction when you require the program thread to halt execution until the
peripheral request interface receives a burst request. If the head entry in the request FIFO is of
request type:

Single
The DMAC removes the entry from the FIFO and program execution remains
halted.

Burst
The DMAC pops the entry from the FIFO and continues program execution.

Use the DMALDP instruction when you require the DMAC to send an acknowledgement to the
peripheral when it completes the AXI read transfers. Similarly, use the DMASTP instruction when
you require the DMAC to send an acknowledgement to the peripheral when it completes the
AXI write transfers. The DMAC uses the datype_<x>[1:0] bus to signal a transfer
acknowledgement to peripheral <x>.

Note
The DMAC sends an acknowledgement for a read transaction when rvalid and rlast are HIGH
and for a write transaction when bvalid is HIGH. If your system is able to buffer AXI write
transfers then it might be possible for the DMAC to send an acknowledgement to the peripheral
but the transfer of write data to the end destination is still in progress.

Use the DMAFLUSHP instruction to reset the request FIFO for the peripheral request interface. After
the DMAC executes DMAFLUSHP, it ignores peripheral requests until the peripheral acknowledges
the flush request. This enables the DMAC and peripheral to synchronize with each other.

ARM DDI 0424D
Copyright © 2007, 2009-2010, 2012 ARM. All rights reserved.
2-19
ID072812
Non-Confidential

<!-- page 42 -->

Functional Overview

Example program for DMAC length management

Example 2-3 shows a DMAC program that can transfer 1027 words when a peripheral signals
16 consecutive burst requests and three consecutive single requests.

Example 2-3 DMAC length management program

# Set up for AXI burst transfer (4-beat burst, so SB4 and DB4), (word data width, so SS32 and DS32)

DMAMOV CCR SB4 SS32 DB4 DS32
DMAMOV SAR ...
DMAMOV DAR ...

# Initialize peripheral '0'
DMAFLUSHP P0

# Perform peripheral transfers
# Burst request loop to transfer 1024 words
DMALP 16

# Wait for the peripheral to signal a burst request. DMAC transfers 64 words for each burst request
DMAWFP 0, burst

# Set up loop for burst request: first 15 of 16 sets of transactions
DMALP 15

DMALD
DMAST
DMALPEND

# Perform final transaction (16 of 16). Send the peripheral acknowledgement of burst request completion
DMALD
DMASTPB 0

# Finish burst loop
DMALPEND

# Set up for AXI single transfer (word data width, so SS32 and DS32)
DMAMOV CCR SB1 SS32 DB1 DS32

# Single request loop to transfer 3 words
DMALP 3

# Wait for the peripheral to signal a single request. DMAC to transfer one word
DMAWFP 0, single

# Perform transaction for single request and send completion acknowledgement to the peripheral
DMALDS
DMASTPS P0

# Finish single loop
DMALPEND

# Flush the peripheral, in case the single transfers were in response to a burst request
DMAFLUSHP 0

DMAEND

ARM DDI 0424D
Copyright © 2007, 2009-2010, 2012 ARM. All rights reserved.
2-20
ID072812
Non-Confidential

<!-- END VERBATIM SOURCE -->
