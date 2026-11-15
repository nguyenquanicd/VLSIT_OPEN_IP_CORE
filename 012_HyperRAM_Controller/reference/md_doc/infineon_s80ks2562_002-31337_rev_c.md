---
protocol: "Infineon S80KS2562 HyperRAM datasheet"
revision: "002-31337 Rev C"
source: "https://www.infineon.com/assets/row/public/documents/10/49/infineon-s80ks2562-1.8-v-256-mb-hyperbus-interface-hyperram-self-refresh-dram-datasheet-en.pdf"
license: "Infineon Technologies AG copyright; all rights reserved"
redistribution: "forbidden"
retrieved: 2026-10-27
source_sha256: "3f8e3992fd679a51022d133fe68ef446c49c52d1aeec6d0577617dc1127dc70e"
converter: "vlsit_pdf_to_md.py (PyMuPDF)"
---

# Infineon S80KS2562 HyperRAM datasheet - revision 002-31337 Rev C

> **Key notes (written by the converter operator, not part of the source):**
> - none recorded

> The text between the markers below is the source text, converted without rewording.

<!-- BEGIN VERBATIM SOURCE -->

<!-- page 1 -->

# S80KS2562

# 256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ interface

## 1.8 V

## Features

• Interface
- HYPERBUS™ Interface
- 1.8 V Interface support

• Single-ended clock (CK) - 11 bus signals
• Optional differential clock (CK, CK#) - 12 bus signals
- Chip select (CS#)
- 8-bit data bus (DQ[7:0])
- Hardware reset (RESET#)
- Bidirectional read-write data strobe (RWDS)

• Output at the start of all transactions to indicate refresh latency
• Output during read transactions as read data strobe
• Input during write transactions as write data mask

• Performance, power, and packages
- 200-MHz maximum clock rate
- DDR - transfers data on both edges of the clock
- Data throughput up to 400 MBps (3,200 Mbps)
- Configurable burst characteristics

• Linear burst
• Wrapped burst lengths:
16 bytes (8 clocks)
32 bytes (16 clocks)
64 bytes (32 clocks)
128 bytes (64 clocks)
• Hybrid option - one wrapped burst followed by linear burst
- Configurable output drive strength
- Power modes

• Hybrid sleep mode
• Deep power down
- Array refresh

• Partial memory array(1/8, 1/4, 1/2, and so on)
• Full
- Package

• 24-ball FBGA
- Operating temperature range

• Industrial (I): –40 °C to +85 °C
• Industrial Plus (V): –40 °C to +105 °C
• Automotive, AEC-Q100 Grade 3: –40 °C to +85 °C
• Automotive, AEC-Q100 Grade 2: –40 °C to +105 °C
• Automotive, AEC-Q100 Grade 1: –40 °C to +125 °C

• Technology
- 25-nm DRAM

Datasheet
Please read the Important Notice and Warnings at the end of this document
002-31337 Rev. *C
www.infineon.com
page 1 of 54
2021-09-27

<!-- page 2 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Performance summary

## Performance summary

| Read transaction timings |  | Unit |
|---|---|---|
| Maximum clock rate at 1.8 V VCC/VCCQ | 200 | MHz |
| Maximum access time (tACC) |  | 35 ns |
| Maximum current consumption |  | Unit |
| Burst read or write (linear burst at 200 MHz) 20 | mA/22 | mA |
| Standby (105 °C) | 1.55 | mA |
| Deep power down (105 °C) |  | 15 μA |
| Logic block diagram |  |  |

X Decoders

CS#

Memory

CK/CK#

RWDS

Control

Y Decoders

I/O

Logic

DQ[7:0]

Data Latch

RESET#

Data Path

Datasheet
2 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 3 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Table of contents

## Table of contents

1 General description.........................................................................................................................5
1.1 HYPERBUS™ interface.............................................................................................................................................5
2 Product overview ...........................................................................................................................8
2.1 HYPERBUS™ interface.............................................................................................................................................8
3 Signal description...........................................................................................................................9
3.1 Input/output summary...........................................................................................................................................9
4 HYPERBUS™ transaction details.....................................................................................................10
4.1 Command/address bit assignments....................................................................................................................10
4.2 Read transactions (Memory array and registers) ................................................................................................15
4.3 Write transactions (Memory array write).............................................................................................................16
4.4 Write transactions (Register write) ......................................................................................................................18
5 Memory space ..............................................................................................................................19
5.1 HYPERBUS™ interface...........................................................................................................................................19
6 Register space ..............................................................................................................................20
6.1 HYPERBUS™ interface...........................................................................................................................................20
6.2 Device identification registers..............................................................................................................................20
6.2.1 Density and row boundaries .............................................................................................................................21
6.3 Register space access ...........................................................................................................................................21
6.3.1 Configuration register 0.....................................................................................................................................22
6.3.2 Configuration register 1.....................................................................................................................................26
7 Interface states ............................................................................................................................28
8 Power conservation modes............................................................................................................29
8.1 Interface standby..................................................................................................................................................29
8.2 Active clock stop ...................................................................................................................................................29
8.3 Hybrid sleep ..........................................................................................................................................................29
8.4 Deep power down.................................................................................................................................................30
9 Electrical specifications.................................................................................................................31
9.1 Absolute maximum ratings ..................................................................................................................................31
9.2 Input signal overshoot..........................................................................................................................................31
9.3 Latch-up characteristics.......................................................................................................................................32
9.3.1 Latch-up specification.......................................................................................................................................32
9.4 Operating ranges ..................................................................................................................................................32
9.4.1 Temperature ranges ..........................................................................................................................................32
9.4.2 Power supply voltages.......................................................................................................................................32
9.5 DC characteristics .................................................................................................................................................33
9.5.1 Capacitance characteristics ..............................................................................................................................36
9.6 Power-up initialization .........................................................................................................................................37
9.7 Power down ..........................................................................................................................................................38
9.8 Hardware reset......................................................................................................................................................39
10 Timing specifications ..................................................................................................................40
10.1 Key to switching waveforms...............................................................................................................................40
10.2 AC test conditions...............................................................................................................................................40
10.3 CLK characteristics .............................................................................................................................................41
10.4 AC characteristics................................................................................................................................................43
10.4.1 Read transactions ............................................................................................................................................43
10.4.2 Write transactions............................................................................................................................................45
10.5 Timing reference levels.......................................................................................................................................46
11 Physical interface .......................................................................................................................47
11.1 FBGA 24-ball 5 x 5 array footprint ......................................................................................................................47
11.2 Package diagrams...............................................................................................................................................48
12 Ordering information ..................................................................................................................49

Datasheet
3 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 4 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Table of contents

12.1 Ordering part number.........................................................................................................................................49
12.2 Valid combinations.............................................................................................................................................50
12.3 Valid combinations - Automotive grade / AEC-Q100.........................................................................................50
13 Acronyms ...................................................................................................................................51
14 Document conventions................................................................................................................52
14.1 Units of measure.................................................................................................................................................52
Revision history ..............................................................................................................................53

Datasheet
4 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 5 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

General description

## 1 General description

The 256 Mb HYPERRAM™ device is a high-speed CMOS, self-refresh DRAM, with HYPERBUS™ interface. The DRAM
array uses dynamic cells that require periodic refresh. Refresh control logic within the device manages the refresh
operations on the DRAM array when the memory is not being actively read or written by the HYPERBUS™ interface
master (host). Since the host is not required to manage any refresh operations, the DRAM array appears to the
host as though the memory uses static cells that retain data without refresh. Hence, the memory is more
accurately described as pseudo static RAM (PSRAM).
Since the DRAM cells cannot be refreshed during a read or write transaction, there is a requirement that the host
limit read or write burst transfers lengths to allow internal logic refresh operations when they are needed. The
host must confine the duration of transactions and allow additional initial access latency, at the beginning of a
new transaction, if the memory indicates a refresh operation is needed.

## 1.1 HYPERBUS™ interface

HYPERBUS™ is a low signal count, DDR interface, that achieves high-speed read and write throughput. The DDR
protocol transfers two data bytes per clock cycle on the DQ[7:0] input/output signals. A read or write transaction
on HYPERBUS™ consists of a series of 16-bit wide, one clock cycle data transfers at the internal HYPERRAM™ array
with two corresponding 8-bit wide, one-half-clock-cycle data transfers on the DQ signals. All inputs and outputs
are LV-CMOS compatible. Device are available as 1.8 V VCC/(VCCQ (nominal) for array (VCC) and I/O buffer (VCCQ)
supplies, through different ordering part numbers (OPN).
Command, address, and data information is transferred over the eight HYPERBUS™ DQ[7:0] signals. The clock
(CK#, CK) is used for information capture by a HYPERBUS™ slave device when receiving command, address, or
data on the DQ signals. Command or address values are center-aligned with clock transitions.
Every transaction begins with the assertion of CS# and command-address (CA) signals, followed by the start of
clock transitions to transfer six CA bytes, followed by initial access latency and either read or write data transfers,
until CS# is deasserted.

| CS# CK# , CK RWDS DQ[7:0] | tRWR=Read Write Recovery High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives | t = Access ACC Latency Count RWDS | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[7:0] and RWDS |
|---|---|---|---|
| Figure 1 Read | transaction, single initial latency | count |  |

The RWDS is a bidirectional signal that indicates:

• when data will start to transfer from a HYPERRAM™ device to the master device in read transactions (initial read
latency)

• when data is being transferred from a HYPERRAM™ device to the master device during read transactions (as a
source synchronous read data strobe)

• when data may start to transfer from the master device to a HYPERRAM™ device in write transactions (initial
write latency)

• data masking during write data transfers

Datasheet
5 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 6 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

General description

During the CA transfer portion of a read or write transaction, RWDS acts as an output from a HYPERRAM™ device
to indicate whether additional initial access latency is needed in the transaction.
During read data transfers, RWDS is a read data strobe with data values edge-aligned with the transitions of
RWDS.

| CS# C K # , C K RWDS DQ[7:0] | tRWR=Read Write Recovery Additional Latency Latency Count 1 High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives RWDS | tACC = Access Latency Count 2 | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[7:0] and RWDS |
|---|---|---|---|
| Figure 2 Read During write data transfers, and prevented from to a memory). Data merging of multiple center-aligned with | transaction, additional latency count RWDS indicates whether each data byte changing the byte location in a memory) or not masking may be used by the host to byte align non-word aligned writes in a single burst write. clock transitions. | transfer is masked masked with RWDS write data within a During write transactions, | with RWDS HIGH (invalid Low (valid and written memory or to enable data is |
| CS# C K # , C K RWDS DQ[7:0] | tRWR =Read Write Recovery tACC = Access Latency Count High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives RWDS | CK and are center Dn Dn A B Host drives and RWDS | Data aligned Dn+1 Dn+1 A B DQ[7:0] |
| Figure 3 Write Read and write transactions Each individual read | transaction, single initial latency count are burst oriented, transferring the next or write transaction can use either a wrapped | sequential word or linear burst sequence. | during each clock cycle. |
|  | 16 word group alignment boundaries Linear Burst |  |  |

4h
5h
6h
7h
8h
9h
Ah Bh Ch
Dh Eh
Fh 10h 11h 12h 13h

Initial address = 4h

Wrapped Burst

4h
5h
6h
7h
8h
9h
Ah Bh Ch
Dh Eh
Fh
0h
1h
2h
3h

Figure 4
Linear versus wrapped burst sequence

Datasheet
6 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 7 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

General description

During wrapped transactions, accesses start at a selected location and continue to the end of a configured word
group aligned boundary, then wrap to the beginning location in the group, then continue back to the starting
location. Wrapped bursts are generally used for critical word first cache line fill read transactions. During linear
transactions, accesses start at a selected location and continue in a sequential manner until the transaction is
terminated when CS# returns HIGH. Linear transactions are generally used for large contiguous data transfers
such as graphic images. Since each transaction command selects the type of burst sequence for that transaction,
wrapped and linear bursts transactions can be dynamically intermixed as needed.

Datasheet
7 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 8 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Product overview

## 2 Product overview

The 256 Mb HYPERRAM™ device is 1.8 V array and I/O, synchronous self-refresh DRAM. The HYPERRAM™ device
provides a HYPERBUS™ slave interface to the host system. The HYPERBUS™ interface has an 8-bit (1 byte) wide
DDR data bus and use only word-wide (16-bit data) address boundaries. Read transactions provide 16 bits of data
during each clock cycle (8 bits on both clock edges). Write transactions take 16 bits of data from each clock cycle
(8 bits on each clock edge).

| RESET# CS# CK CK# | VCC VCCQ DQ[7:0] RWDS VSS VSSQ |
|---|---|
| interface[1] Figure 5 HYPERRAM™ |  |

## 2.1 HYPERBUS™ interface

Read and write transactions require two clock cycles to define the target row address and burst type, then an
initial access latency of tACC. During the CA part of a transaction, the memory will indicate whether an additional
latency for a required refresh time (tRFH) is added to the initial latency; by driving the RWDS signal to the HIGH
state. During the CA period, the third clock cycle will specify the target word address within the target row. During
a read (or write) transaction, after the initial data value has been output (or input), additional data can be read
from (or written to) the row on subsequent clock cycles in either a wrapped or linear sequence. When configured
in linear burst mode, the device will automatically fetch the next sequential row from the memory array to
support a continuous linear burst. Simultaneously accessing the next row in the array while the read or write data
transfer is in progress, allows for a linear sequential burst operation that can provide a sustained data rate of
400 MBps [1 byte (8 bit data bus) * 2 (data clock edges) * 200 MHz = 400 MBps].

Note

1. CK# is used in differential clock mode, but optional.

Datasheet
8 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 9 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Signal description

## 3 Signal description

## 3.1 Input/output summary

HYPERRAM™ signals are shown in Table 1. Active Low signal names have a hash symbol (#) suffix.

Table 1
I/O summary

| Symbol |  | Type |  | Description |
|---|---|---|---|---|
| CS# | Input |  | Chip select. Bus transactions Bus transactions are terminated master device has a separate CS# | are initiated with a HIGH to LOW transition. with a LOW to HIGH transition. The for each slave. |
| CK#[2] CK, | Input |  | Differential clock. Command, with respect to the crossing of clock is optional. Single ended clock. CK# is not clock is not required to be free-running. | address, and data information is output the CK and CK# signals. Use of differential used, only a single ended CK is used. The |
| DQ[7:0] | Input/output |  | Data input/output. Command, transferred on these signals during | address, and data information is Read and Write transactions. |
| RWDS | Input/output |  | Read-write data strobe. During transactions, RWDS is a slave initial latency is required. Slave edge-aligned with RWDS. Slave transactions to function as a data (HIGH = additional latency, LOW | the command/address portion of all bus output and indicates whether additional output during read data transfer, data is input during data transfer in write mask. = no additional latency). |
| RESET# | Input, internal | pull-up | Hardware RESET. When LOW, return to the STANDBY state. HIGH-Z state when RESET# is weak pull-up, if RESET# is left unconnected state. | the slave device will self initialize and RWDS and DQ[7:0] are placed into the LOW. The slave RESET# input includes a it will be pulled up to the HIGH |
| VCC | Power supply |  | Array power. |  |
| VCCQ | Power supply |  | Input/output power. |  |
| VSS VSSQ | Power supply Power supply |  | Array ground. Input/output ground. |  |
| RFU | No connect |  | Reserved for future use. May signal/ball location should be routing channel for future compatibility. a signal in the future. | or may not be connected internally, the left unconnected and unused by PCB The signal/ball may be used by |
| Note 2. CK# is used if not connected | in differential to | clock mode, the host controller, | but optional connection. but do not leave it floating. | Tie the CK# input pin to either VCCQor VSSQ |

Datasheet
9 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 10 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

## 4 HYPERBUS™ transaction details

## 4.1 Command/address bit assignments

All HYPERRAM™ bus transactions can be classified as either read or write. A bus transaction is started with CS#
going LOW with clock in idle state (CK = LOW and CK# = HIGH). The first three clock cycles transfer three words of
command/address (CA0, CA1, CA2) information to define the transaction characteristics. The Command/Address
words are presented with DDR timing, using the first six clock edges.
The following characteristics are defined by the command/address information:

• Read or write transaction

• Address space: memory array space or register space
- Register space is used to access device identification (ID) registers and configuration registers (CR) that identify

the device characteristics and determine the slave specific behavior of read and write transfers on the HYPER-
BUS™ interface.

• Whether a transaction will use a linear or wrapped burst sequence.

• The target row (and half-page) address (upper order address)

• The target column (word within half-page) address (lower order address)

| CS# CK , CK# DQ[7:0] | CA0[47:40] | CA0[39:32] | CA1[31:24] CA1[23:16] | CA2[15:8] |  | CA2[7:0] |  |
|---|---|---|---|---|---|---|---|
| Figure 6 Command-address Table 2 CA bit assignment | to | sequence[3-6] (CA) DQ signals |  |  |  |  |  |
| Signal CA0[47:40] | CA0[39:32] | CA1[31:24] | CA1[23:16] | CA2[15:8] |  | CA2[7:0] |  |
| DQ[7] CA[47] |  | CA[39] | CA[31] | CA[23] | CA[15] |  | CA[7] |
| DQ[6] CA[46] |  | CA[38] | CA[30] | CA[22] | CA[14] |  | CA[6] |
| DQ[5] CA[45] |  | CA[37] | CA[29] | CA[21] | CA[13] |  | CA[5] |
| DQ[4] CA[44] |  | CA[36] | CA[28] | CA[20] | CA[12] |  | CA[4] |
| DQ[3] CA[43] |  | CA[35] | CA[27] | CA[19] | CA[11] |  | CA[3] |
| DQ[2] CA[42] |  | CA[34] | CA[26] | CA[18] | CA[10] |  | CA[2] |
| DQ[1] CA[41] |  | CA[33] | CA[25] | CA[17] | CA[9] |  | CA[1] |
| DQ[0] CA[40] |  | CA[32] | CA[24] | CA[16] | CA[8] |  | CA[0] |

Notes

3. Figure 6 shows the initial three clock cycles of all transactions on the HYPERBUS™.
4. CK# of differential clock is shown as dashed line waveform.
5. CA information is “center-aligned” with the clock during both read and write transactions.
6. Data bits in each byte are always in high to low order with bit 7 on DQ7 and bit 0 on DQ0.

Datasheet
10 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 11 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

Table 3
Command/Address bit assignments[7-10]

| CA bit# | Bit name | Bit function |
|---|---|---|
| 47 | Identifies the transaction as a read R/W# R/W# = 1 indicates a read transaction R/W# = 0 indicates a write transaction | or write. |
| Address 46 | Indicates whether the read or write space. space AS = 0 indicates memory space (AS) AS = 1 indicates the register space The register space is used to access | transaction accesses the memory or register device ID and configuration registers. |
| 45 | Indicates whether the burst will be Burst type Burst type = 0 indicates wrapped Burst type = 1 indicates linear burst | linear or wrapped. burst |
| Row 44-16 | Row & upper column component A31-A3 & upper Any upper Row address bits not used column to 0 by the host controller master address address bit boundary between row dependent. | of the target address: system word address bits by a particular device density should be set interface. The size of rows and therefore the and column address is slave device |
| 15-3 | Reserved for future column address Reserved Reserved bits are don’t care in current 0 by the host controller master interface | expansion. HYPERBUS™ devices but should be set to for future compatibility. |
| Lower 2-0 | column Lower column component of the target address selecting the starting word within | address: system word address bits A2-A0 a half-page. |
| Notes 7. A row is a group in the calculation 8. The column address is split into an lower portion 9. The initial read a slave interface. to 16 byte half-pages. 10. HYPERBUS™ 29 Row & upper 3 Lower column Each address 29 + 3 = 32 address Future expansion = 35 Tera-word | of words relevant to the internal memory array of a distributed refresh interval for HYPERRAM™ selects the burst transaction starting word upper and lower portion. The upper portion selects selects the word within a half-page where a read access time starts when the row and upper column Continuous linear read burst is enabled by protocol address space limit, assuming: column address bits address bits selects a word wide (16 bit = 2 byte) data value bits = 4G addresses supporting 8GB (64Gb) of the column address can allow for 29 row = 70 Tera-byte address space. | structure. The number of rows is also used memory. location within a row. The column address an 8-word (16-byte) half-page and the or write transaction burst starts. (half-page) address bits are captured by memory devices internally interleaving access maximum address space &upper column + 16 lower column address bits |

Datasheet
11 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 12 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

| CS# CK , CK# RWDS DQ[7:0] | Dn A | Dn B | Dn+1 A | Dn+1 B | Dn+2 A |
|---|---|---|---|---|---|
| Figure 7 Data placement during | transaction[11-15] a read |  |  |  |  |

Data placement during memory read/write is dependent upon the host. The device will output data (read) as it
was written in (write). Hence both Big Endian and Little Endian are supported for the memory array.
Data placement during register read/write is Big Endian.

Notes

11. Figure 7 shows a portion of a read transaction on the HYPERBUS™. CK# of differential clock is shown as
dashed line waveform.
12. Data is “edge-aligned” with the RWDS serving as a read data strobe during read transactions.
13. Data is always transferred in full word increments (word granularity transfers).
14. Word address increments in each clock cycle. Byte A is between RWDS rising and falling edges and is followed
by byte B between RWDS falling and rising edges, of each word.
15. Data bits in each byte are always in high to low order with bit 7 on DQ7 and bit 0 on DQ0.

Datasheet
12 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 13 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

Table 4
Data bit placement during read or write transaction

| Address space | Byte order | Byte position | Word data bit | DQ | Bit order |
|---|---|---|---|---|---|
|  |  |  | 15 | 7 |  |

14
6

13
5

12
4

A

11
3

10
2

9
1

8
0

Big-
endian

7
7

6
6

5
5

4
4

B

3
3

When data is being accessed in memory space:
The first byte of each word read or written is the “A” byte and the
second is the “B” byte.
The bits of the word within the A and B bytes depend on how the data
was written. If the word lower address bits 7-0 are written in the A byte
position and bits 15-8 are written into the B byte position, or vice
versa, they will be read back in the same order.

2
2

1
1

0
0

Memory

7
7

6
6

Memory space can be stored and read in either little-endian or
big-endian order.

5
5

4
4

A

3
3

2
2

1
1

0
0

Little-
endian

15
7

14
6

13
5

12
4

B

11
3

10
2

9
1

8
0

Datasheet
13 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 14 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

Table 4
Data bit placement during read or write transaction  (continued)

| Address space | Byte order | Byte position | Word data bit | DQ | Bit order |
|---|---|---|---|---|---|
|  |  |  | 15 | 7 |  |

14
6

13
5

12
4

When data is being accessed in register space:
During a read transaction on the HYPERBUS™ two bytes are trans-
ferred on each clock cycle. The upper order byte A (Word[15:8]) is
transferred between the rising and falling edges of RWDS
(edge-aligned). The lower order byte B (Word[7:0]) is transferred
between the falling and rising edges of RWDS.

A

11
3

10
2

9
1

8
0

Register
Big-
endian

7
7

During a write, the upper order byte A (Word[15:8]) is transferred on
the CK rising edge and the lower order byte B (Word[7:0]) is trans-
ferred on the CK falling edge.
So, register space is always read and written in Big-endian order
because registers have device dependent fixed bit location and
meaning definitions.

6
6

5
5

4
4

B

3
3

2
2

1
1

0
0

| CS# CK , CK# RWDS DQ[7:0] | Dn A | Dn B | Dn+1 A | Dn+1 B | Dn+2 A |
|---|---|---|---|---|---|
| Figure 8 Data placement during | a write | transaction[16-19] |  |  |  |

Notes

16. Figure 8 shows a portion of a write transaction on the HYPERBUS™.
17. Data is “center-aligned” with the clock during a write transaction.
18. RWDS functions as a data mask during write data transfers with initial latency. Masking of the first and last
byte is shown to illustrate an unaligned 3 byte write of data.
19. RWDS is not driven by the master during write data transfers with zero initial latency. Full data words are
always written in this case. RWDS may be driven LOW or left HIGH-Z by the slave in this case.

Datasheet
14 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 15 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

## 4.2 Read transactions (Memory array and registers)

The HYPERBUS™ master begins a transaction by driving CS# LOW while clock is idle. The clock then begins
toggling while CA words are transferred.
In CA0, CA[47] = 1 indicates that a read transaction is to be performed. CA[46] = 0 indicates the memory space is
being read or CA[46] = 1 indicates the register space is being read. CA[45] indicates the burst type (wrapped or
linear). Read transactions can begin the internal array access as soon as the row and upper column address has
been presented in CA0 and CA1 (CA[47:16]). CA2 (CA(15:0]) identifies the target word address within the chosen
row.
The HYPERBUS™ master then continues clocking for a number of cycles defined by the latency count setting in
configuration register 0. The initial latency count required for a particular clock frequency is based on RWDS. If
RWDS is LOW during the CA cycles, one latency count is inserted. If RWDS is HIGH during the CA cycles, an
additional latency count is inserted. Once these latency clocks have been completed the memory starts to simul-
taneously transition the RWDS and output the target data.
New data is output edge-aligned with every transition of RWDS. Data will continue to be output as long as the
host continues to transition the clock while CS# is LOW. Note that burst transactions should not be so long as to
prevent the memory from doing distributed refreshes.
Wrapped bursts will continue to wrap within the burst length and linear burst will output data in a sequential
manner across row boundaries. When a linear burst read reaches the last address in the array, continuing the
burst beyond the last address will provide data from the beginning of the address range. Read transfers can be
ended at any time by bringing CS# HIGH when the clock is idle.
The clock is not required to be free-running. The clock may remain idle while CS# is HIGH.

| CS# Additional Latency tRWR= Read Write Recovery CK# , CK RWDS High = 2x Latency Count Low = 1x Latency Count Latency Count 1 DQ[7:0] 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives RWDS | tACC = Access Latency Count 2 | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[7:0] and RWDS |
|---|---|---|
| Figure 9 Read transaction with additional initial latency[20-28] |  |  |

Notes

20. Transactions are initiated with CS# falling while CK = LOW and CK# = HIGH.
21. CS# must return HIGH before a new transaction is initiated.
22. CK# is the complement of the CK signal.CK# of a differential clock is shown as a dashed line waveform.
23. Read access array starts once CA[23:16] is captured.
24. The read latency is defined by the initial latency value in a configuration register.
25. In this read transaction example the initial latency count was set to four clocks.
26. In this read transaction a RWDS HIGH indication during CA delays output of target data by an additional four
clocks.
27. The memory device drives RWDS during read transactions.
28. For register read, the output data Dn A is RG[15:8], Dn B is RG[7:0], Dn+1 A is RG[15:8], Dn+1 B is RG[7:0].

Datasheet
15 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 16 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

| CS# CK , CK# RWDS DQ[7:0] | t =Read Write Recovery t = Initial Acces RWR ACC High = 2x Latency Count Low = 1x Latency Count 4 cycle latency 47:40 39:32 31:24 23:16 15:8 7:0 Command-Addres Host drives DQ[7:0] and Memory drives RWDS | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[7:0] and RWDS |
|---|---|---|
| Figure 10 Read | latency[29, 30] transaction without additional initial |  |

## 4.3 Write transactions (Memory array write)

The HYPERBUS™ master begins a transaction by driving CS# LOW while clock is idle. Then the clock begins
toggling while CA words are transferred.
In CA0, CA[47] = 0 indicates that a write transaction is to be performed. CA[46] = 0 indicates the memory space is
being written. CA[45] indicates the burst type (wrapped or linear). Write transactions can begin the internal array
access as soon as the row and upper column address has been presented in CA0 and CA1 (CA[47:16]). CA2
(CA(15:0]) identifies the target word address within the chosen row.
The HYPERBUS™ master then continues clocking for a number of cycles defined by the latency count setting in
configuration register 0. The initial latency count required for a particular clock frequency is based on RWDS. If
RWDS is LOW during the CA cycles, one latency count is inserted. If RWDS is HIGH during the CA cycles, an
additional latency count is inserted.
Once these latency clocks have been completed, the HYPERBUS™ master starts to output the target data. Write
data is center-aligned with the clock edges. The first byte of data in each word is captured by the memory on the
rising edge of CK and the second byte is captured on the falling edge of CK.
During the CA clock cycles, RWDS is driven by the memory.
During the write data transfers, RWDS is driven by the host master interface as a data mask. When data is being
written and RWDS is HIGH, the byte will be masked and the array will not be altered. When data is being written
and RWDS is LOW, the data will be placed into the array. Because the master is driving RWDS during write data
transfers, neither the master nor the HYPERRAM™ device are able to indicate a need for latency within the data
transfer portion of a write transaction. The acceptable write data burst length setting is also shown in configu-
ration register 0.
Data will continue to be transferred as long as the HYPERBUS™ master continues to transition the clock while CS#
is LOW. Note that burst transactions should not be so long as to prevent the memory from doing distributed
refreshes. Legacy format wrapped bursts will continue to wrap within the burst length. Hybrid wrap will wrap
once then switch to linear burst starting at the next wrap boundary. Linear burst accepts data in a sequential
manner across page boundaries. Write transfers can be ended at any time by bringing CS# HIGH when the clock
is idle.

Notes

29. RWDS is LOW during the CA cycles. In this read transaction, there is a single initial latency count for read data
access because, this read transaction does not begin at a time when additional latency is required by the
slave.
30 For register read the output data Dn A is RG[15:8] Dn B is RG[7:0] Dn+1 A is RG[15:8] Dn+1 B is RG[7:0]

Datasheet
16 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 17 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

When a linear burst write reaches the last address in the memory array space, continuing the burst will write to
the beginning of the address range.
The clock is not required to be free-running. The clock may remain idle while CS# is HIGH.

| CK DQ[7:0] | CS# Additional Latency tRWR = Read Write Recovery , CK# RWDS High = 2x Latency Count Low = 1x Latency Count Latency Count 1 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives RWDS | tACC = Initial Access Latency Count 2 | CK and Data are center aligned Dn Dn Dn+1 Dn+1 A B A B Host drives DQ[7:0] and RWDS |
|---|---|---|---|
| Figure 11 | Write transaction with additional initial latency[31-37] |  |  |
| CK# DQ[7:0] | CS# tRWR=Read Write Recovery tACC = Access , CK High = 2x Latency Count Low = 1x Latency Count RWDS Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives RWDS | CK are Dn A Host and RWDS | and Data center aligned Dn Dn+1 Dn+1 B A B drives DQ[7:0] |
| Figure 12 | latency[33-37] Write transaction without additional initial |  |  |

Notes

31. Transactions must be initiated with CK = LOW and CK# = HIGH.
32. CS# must return HIGH before a new transaction is initiated.
33. During CA, RWDS is driven by the memory and indicates whether additional latency cycles are required.
34. In this example, RWDS indicates that additional initial latency cycles are required.
35. At the end of CA cycles the memory stops driving RWDS to allow the host HYPERBUS™ master to begin driving
RWDS. The master must drive RWDS to a valid LOW before the end of the initial latency to provide a data mask
preamble period to the slave.
36. During data transfer, RWDS is driven by the host to indicate which bytes of data should be either masked or
loaded into the array.
37. The figure shows RWDS masking byte Dn A and byte Dn+1 B to perform an unaligned word write to bytes Dn
B and Dn+1 A.

Datasheet
17 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 18 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

HYPERBUS™ transaction details

## 4.4 Write transactions (Register write)

A write transaction starts with the first three clock cycles providing the command/address information indicating
the transaction characteristics. CA0 may indicate that a write transaction is to be performed and also indicates
the address space and burst type (wrapped or linear).
Writes without initial latency are used for register space writes. HYPERRAM™ device write transactions with zero
latency mean that the CA cycles are followed by write data transfers. Writes with zero initial latency, do not have
a turn around period for RWDS. The HYPERRAM™ device will always drive RWDS during the CA period to indicate
whether extended latency is required for a transaction that has initial latency. However, the RWDS is driven
before the HYPERRAM™ device has received the first byte of CA i.e., before the HYPERRAM™ device knows whether
the transaction is a read or write to register space. In the case of a write with zero latency, the RWDS state during
the CA period does not affect the initial latency of zero. Since master write data immediately follows the CA period
in this case, the HYPERRAM™ device may continue to drive RWDS LOW or may take RWDS to HIGH-Z during write
data transfer. The master must not drive RWDS during Writes with zero latency. Writes with zero latency do not
use RWDS as a data mask function. All bytes of write data are written (full word writes).
The first byte of data in each word is presented on the rising edge of CK and the second byte is presented on the
falling edge of CK. Write data is center-aligned with the clock inputs. Write transfers can be ended at any time by
bringing CS# HIGH when clock is idle. The clock is not required to be free-running.

| CK#, CK RWDS DQ[7:0] | High: 2X Latency Count Low: 1X Latency Count CA CA CA CA CA CA [47:40] [39:32] [31:24] [23:16] [15:8] [7:0] Command - Address (Host drives DQ[7:0], Memory drives RWDS) | RG RG [15:8] [7:0] Write Data |
|---|---|---|
| operation[38, Figure 13 Register write | 39] |  |

Notes

38. Latency is not applicable during the register write. The RWDS driven LOW or HIGH after the CS# LOW should
be ignored by the host. The register write data byte immediately follows the last CA byte (zero clock latency).
39. RWDS is not driven by the host during register write. The HyperRAM ignores the RWDS status and always
writes full data. RWDS may be driven Low or left High-Z by the slave during write data transfer.

Datasheet
18 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 19 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Memory space

## 5 Memory space

## 5.1 HYPERBUS™ interface

Table 5
Memory space address map (word based - 16 bits)

| Unit type | Count | System address | word bits | CA bits | Notes |
|---|---|---|---|---|---|
| Rows within 256 Mb 32768 device | (rows) |  | A23 - A9 | 36 - 22 | - |
| Row 64 (half-pages) |  |  | A8 - A3 | Each row has 64 half-pages. 21 - 16 half-page has 8 words. 512 words (1K bytes). | Each Each column has |
| Half-page 8 | (words) |  | A2 - A0 | Half-page (HP) address as upper column address. 2 - 0 HP address is also column address. | is also referenced A word within a referenced as lower |

Datasheet
19 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 20 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Register space

## 6 Register space

## 6.1 HYPERBUS™ interface

When CA[46] is 1, a read or write transaction accesses the register space.

Table 6
Register space address map

| Register | System address CA bits | — 47 | — 46 | — 45[40] | 31-27 44-40 | 26-19 39-32 |  | 18-11 31-24 |  | 23-16 | 10-3 | — 15-8 | 2-0 7-0 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Identification register read[41] | 0 |  | C0h or | E0h |  |  | 00h |  | 00h |  | 00h | 00h | 00h |
| Identification register read[41] | 1 |  | C0h or | E0h |  |  | 00h |  | 00h |  | 00h | 00h | 01h |
| Configuration register read | 0 |  | C0h or | E0h |  |  | 00h |  | 01h |  | 00h | 00h | 00h |
| Configuration register write | 0 |  | 60h |  |  |  | 00h |  | 01h |  | 00h | 00h | 00h |
| Configuration register read | 1 |  | C0h or | E0h |  |  | 00h |  | 01h |  | 00h | 00h | 01h |
| Configuration register write | 1 |  | 60h |  |  |  | 00h |  | 01h |  | 00h | 00h | 01h |
| Notes 40. CA45 may be either writes are supported. 41. The burst type (wrapped/linear) effect. | 0 or 1 for | either definition | wrapped | or linear is not supported | read. CA45 in |  | must be register | reads. | 1 as only Hence |  | linear single C0h/E0h | word register have the | same |

## 6.2 Device identification registers

There are two read only, nonvolatile word registers, that provide information on the device selected when CS# is
LOW.
The device information fields identify:

• Manufacturer

• Type

• Density

• Row address bit count

• Column address bit count

Table 7
Identification register 0 (ID0) bit assignments

| Bits | Function |  | Settings (Binary) |
|---|---|---|---|
| [15:14] MCP | die address | 00 - Default |  |
| [13] | Reserved | 0 - Default |  |
| [12:8] Row address | bit count | 01110b - 256 Mb; | fifteen row address bits (256 Mbit) |

[7:4]
Column address bit count
1000b - Nine column address bits (default)

[3:0]
Manufacturer
0110b

Datasheet
20 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 21 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Register space

:

Table 8
Identification register 1 (ID1) bit assignments

| Bits | Function |  | Settings (Binary) |
|---|---|---|---|
| [15:4] | Reserved | 0000_0000_0000b | (default) |
| [3:0] Device | type | 0001 - HYPERRAM™ | 2.0 |
| 6.2.1 Density and row | boundaries |  |  |

The DRAM array size (density) of the device can be determined from the total number of system address bits used
for the row and column addresses as indicated by the row address bit count and column address bit count fields
in the ID0 register. For example: a 256 Mb HYPERRAM™ device has 9 column address bits and 15 row address bits
for a total of 24 word address bits = 224 = 16 Mwords = 32 MB. The 9 column address bits indicate that each row
holds 29 = 512 words = 1 KB. The row address bit count indicates there are 32,784 rows to be refreshed within each
array refresh interval. The row count is used in calculating the refresh interval.
ID0 value for the 256 Mb HYPERRAM™ is 0x0E86.

## 6.3 Register space access

Register default values are loaded upon power-up or hardware reset. The registers can be altered at any time
while the device is in the STANDBY state.
Loading a register is accomplished with write transaction without initial latency using a single 16-bit word write
transaction.
Each register is written with a separate single word write transaction. Register write transactions have zero
latency, the single word of data immediately follows the CA. RWDS is not driven by the host during the write
because RWDS is always driven by the memory during the CA cycles to indicate whether a memory array refresh
is in progress. Because a register space write goes directly to a register, rather than the memory array, there is no
initial write latency, related to an array refresh that may be in progress. In a register write, RWDS is also not used
as a data mask because both bytes of a register are always written and never masked.
Reserved register fields must be written with their default value. Writing reserved fields with other than default
values may produce undefined results.
Notes

• The host must not drive RWDS during a write to register space.

• The RWDS signal is driven by the memory during the CA period based on whether the memory array is being
refreshed. This refresh indication does not affect the writing of register data.

• The RWDS signal returns to high impedance after the CA period. Register data is never masked. Both data bytes
of the register data are loaded into the selected register.
Reading of a register is accomplished with read transaction with single or double initial latency using a single
16 bit read transaction. If more than one word is read, the output becomes indeterminate. The contents of the
register is returned in the same manner as reading the memory array, as shown in Figure 9, with one or two
latency counts, based on the state of RWDS during the CA period. The latency count is defined in the configuration
register 0 read latency field (CR0[7:4]).

Datasheet
21 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 22 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Register space

## 6.3.1 Configuration register 0

Configuration register 0 (CR0) is used to define the power state and access protocol operating conditions for the
HYPERRAM™ device. Configurable characteristics include:

• Wrapped burst length (16, 32, 64, or 128 byte aligned and length data group)

• Wrapped burst type
- Legacy wrap (Sequential access with wrap around within a selected length and aligned group)
- Hybrid wrap (Legacy wrap once then linear burst at start of the next sequential group)

• Initial latency

• Variable latency
- Whether an array read or write transaction will use fixed or variable latency. If fixed latency is selected the

memory will always indicate a refresh latency and delay the read data transfer accordingly. If variable latency
is selected, latency for a refresh is only added when a refresh is required at the same time a new transaction
is starting.

• Output drive strength

• Deep power down (DPD) mode

Table 9
Configuration register 0 (CR0) bit assignments

| CR0 bit |  | Function |  | Settings (Binary) |
|---|---|---|---|---|
| [15] Deep | power | down enable | 1 - Normal operation (default). this value to “1” after DPD 0 - Writing 0 causes the | HYPERRAM™ will automatically set exit device to enter deep power down |
| [14:12] | Drive | strength | 000 - 34 ohms (default) 001 - 115 ohms 010 - 67 ohms 011 - 46 ohms 100 - 34 ohms 101 - 27 ohms 110 - 22 ohms 111 - 19 ohms |  |
| [11:8] |  | Reserved | 1 - Reserved (default) Reserved for future use. should be set to 1 for future | When writing this register, these bits compatibility. |
| [7:4] | Initial | latency | 0000 - 5 clock latency @ 0001 - 6 Clock latency @ 0010 - 7 clock latency @ 0011 - Reserved 0100 - Reserved ... 1101 - Reserved 1110 - 3 clock latency @ 1111 - 4 clock latency @ | 133 MHz Max frequency 166 MHz Max frequency 200 MHz Max frequency (default) 85 MHz Max frequency 104 MHz Max frequency |
| [3] Fixed |  | latency enable | 0 - Variable latency - 1 or RWDS during CA cycles. 1 - Fixed 2 times initial | 2 times initial latency depending on latency (default) |

Datasheet
22 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 23 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Register space

Table 9
Configuration register 0 (CR0) bit assignments (continued)

| CR0 bit | Function | Settings (Binary) |
|---|---|---|
| [2] Hybrid | 0: Wrapped burst sequence 1: Wrapped burst sequence (default) burst enable This bit setting is effective command/address register it is ignored. | to follow hybrid burst sequencing in legacy wrapped burst manner only when the "Burst type" bit in the is set to '0', i.e. CA[45] = '0'; otherwise, |
| [1:0] Burst | 00 - 128 bytes 01 - 64 bytes length 10- 16 bytes 11 - 32 bytes (default) |  |

Wrapped burst
A wrapped burst transaction accesses memory within a group of words aligned on a word boundary matching
the length of the configured group. Wrapped access groups can be configured as 16, 32, 64, or 128 bytes
alignment and length. During wrapped transactions, access starts at the CA selected location within the group,
continues to the end of the configured word group aligned boundary, then wraps around to the beginning
location in the group, then continues back to the starting location. Wrapped bursts are generally used for critical
word first instruction or data cache line fill read accesses.
Hybrid burst
The beginning of a hybrid burst will wrap within the target address wrapped burst group length before continuing
to the next half-page of data beyond the end of the wrap group. Continued access is in linear burst order until the
transfer is ended by returning CS# HIGH. This hybrid of a wrapped burst followed by a linear burst starting at the
beginning of the next burst group, allows multiple sequential address cache lines to be filled in a single access.
The first cache line is filled starting at the critical word. Then the next sequential line in memory can be read in
to the cache while the first line is being processed.

Table 10
CR0[2] control of wrapped burst sequence

| Bit | Default value | Name |
|---|---|---|
| 2 | Hybrid burst enable 1 CR0[2] = 0: Wrapped burst sequence CR0[2] = 1: Wrapped burst sequence | to follow hybrid burst sequencing in legacy wrapped burst manner |

Datasheet
23 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 24 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Register space

Table 11
Example wrapped burst sequences (HYPERBUS™ addressing)

| Burst type | Wrap boundary (bytes) | Start address (Hex) |  | Sequence of word addresses (Hex) of data words |
|---|---|---|---|---|
| Hybrid 128 | 128 wrap once then linear | XXXXXX03 | 03, 04, 05, 17, 18, 19, 2B, 2C, 2D, 3F, 00, 01, (Wrap complete, wrap group) 40, 41, 42, | 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, 1A, 1B, 1C, 1D, 1E, 1F, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 2A, 2E, 2F, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 02 now linear beyond the end of the initial 128 byte 43, 44, 45, 46, 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| Hybrid 64 | 64 wrap once then linear | XXXXXX03 | 03, 04, 05, 17, 18, 19, (wrap complete, group) 20, 21, 22, | 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, 1A, 1B, 1C, 1D, 1E, 1F, 00, 01, 02 now linear beyond the end of the initial 64 byte wrap 23, 24, 25, 26, 27, 28, 29, 2A, 2B, 2C, 2D, 2E, 2F, 30, 31, ... |
| Hybrid 64 | 64 wrap once then linear | XXXXXX2E | 2E, 2F, 30, 22, 23, 24, (wrap complete, group) 40, 41, 42, | 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 21, 25, 26, 27, 28, 29, 2A, 2B, 2C, 2D now linear beyond the end of the initial 64 byte wrap 43, 44, 45, 46, 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| Hybrid 16 | 16 wrap once then linear | XXXXXX02 | 02, 03, 04, (wrap complete, group) 08, 09, 0A, | 05, 06, 07, 00, 01 now linear beyond the end of the initial 16 byte wrap 0B, 0C, 0D, 0E, 0F, 10, 11, 12, ... |
| Hybrid 16 | 16 wrap once then linear | XXXXXX0C | 0C, 0D, 0E, (wrap complete, group) 10, 11, 12, | 0F, 08, 09, 0A, 0B now linear beyond the end of the initial 16 byte wrap 13, 14, 15, 16, 17, 18, 19, 1A, ... |
| Hybrid 32 | 32 wrap once then linear | XXXXXX0A | 0A, 0B, 0C, (wrap complete, group) 10, 11, 12, | 0D, 0E, 0F, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09 now linear beyond the end of the initial 32 byte wrap 13, 14, 15, 16, 17, 18, 19, 1A, ... |
| Wrap 64 | 64 | XXXXXX03 | 03, 04, 05, 17, 18, 19, | 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, 1A, 1B, 1C, 1D, 1E, 1F, 00, 01, 02, ... |
| Wrap 64 | 64 | XXXXXX2E | 2E, 2F, 30, 22, 23, 24, | 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 21, 25, 26, 27, 28, 29, 2A, 2B, 2C, 2D, ... |
| Wrap 16 | 16 | XXXXXX02 | 02, 03, 04, | 05, 06, 07, 00, 01, ... |
| Wrap 16 | 16 | XXXXXX0C | 0C, 0D, 0E, | 0F, 08, 09, 0A, 0B, ... |
| Wrap 32 | 32 | XXXXXX0A | 0A, 0B, 0C, | 0D, 0E, 0F, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, ... |
| Linear | Linear burst | XXXXXX03 | 03, 04, 05, 17, 18, ... | 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, |

Datasheet
24 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 25 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Register space

Initial latency
Memory space read and write transactions or register space read transactions require some initial latency to
open the row selected by the CA. This initial latency is tACC. The number of latency clocks needed to satisfy tACC
depends on the HYPERBUS™ frequency can vary from 3 to 7 clocks. The value in CR0[7:4] selects the number of
clocks for initial latency. The default value is 7 clocks, allowing for operation up to a maximum frequency of 200
MHz prior to the host system setting a lower initial latency value that may be more optimal for the system.
In the event a distributed refresh is required at the time a memory space read or write transaction or register
space read transaction begins, the RWDS signal goes HIGH during the CA to indicate that an additional initial
latency is being inserted to allow a refresh operation to complete before opening the selected row.
Register space write transactions always have zero initial latency. RWDS may be HIGH or LOW during the CA
period. The level of RWDS during the CA period does not affect the placement of register data immediately after
the CA, as there is no initial latency needed to capture the register data. A refresh operation may be performed
in the memory array in parallel with the capture of register data.
Fixed latency
A configuration register option bit CR0[3] is provided to make all memory space read and write transactions or
register space read transactions require the same initial latency by always driving RWDS HIGH during the CA to
indicate that two initial latency periods are required. This fixed initial latency is independent of any need for a
distributed refresh, it simply provides a fixed (deterministic) initial latency for all of these transaction types. The
fixed latency option may simplify the design of some HYPERBUS™ memory controllers or ensure deterministic
transaction performance. Fixed latency is the default POR or reset configuration. The system may clear this
configuration bit to disable fixed latency and allow variable initial latency with RWDS driven HIGH only when
additional latency for a refresh is required.
Drive strength
DQ and RWDS signal line loading, length, and impedance vary depending on each system design. Configuration
register bits CR0[14:12] provide a means to adjust the DQ[7:0] and RWDS signal output impedance to customize
the DQ and RWDS signal impedance to the system conditions to minimize high speed signal behaviors such as
overshoot, undershoot, and ringing. The default POR or reset configuration value is 000b to select the mid point
of the available output impedance options.
The impedance values shown are typical for both pull-up and pull-down drivers at typical silicon process condi-
tions, nominal operating voltage (1.8 V) and 50°C. The impedance values may vary from the typical values
depending on the process, voltage, and temperature (PVT) conditions. Impedance will increase with slower
process, lower voltage, or higher temperature. Impedance will decrease with faster process, higher voltage, or
lower temperature.
Each system design should evaluate the data signal integrity across the operating voltage and temperature
ranges to select the best drive strength settings for the operating conditions.
Deep power down
When the HYPERRAM™ device is not needed for system operation, it may be placed in a very low power consuming
state called deep power down (DPD), by writing 0 to CR0[15]. When CR0[15] is cleared to 0, the device enters the
DPD state within tDPDIN time and all refresh operations stop. The data in RAM is lost, (becomes invalid without
refresh) during DPD state. Exiting DPD requires driving CS# LOW then HIGH, POR, or a reset. Only CS# and RESET#
signals are monitored during DPD mode. For additional details, see “Deep power down” on page 30.

Datasheet
25 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 26 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Register space

## 6.3.2 Configuration register 1

Configuration register 1 (CR1) is used to define the refresh array size, refresh rate and hybrid sleep for the
HYPERRAM™ device. Configurable characteristics include:

• Partial array refresh

• Hybrid sleep state

• Refresh rate

Table 12
Configuration register 1 (CR1) bit assignments

| CR1 bit | Function |  | Setting (binary) |
|---|---|---|---|
| [15:8] | Reserved | 11111111 - reserved (default) When writing this register, compatibility | these bits should keep 0xFFh for future |
| [7] | Reserved | 1 - reserved (default) |  |
| [6] Master | clock type | 1 - single-ended - CK (default) 0 - differential - CK#, CK |  |
| [5] Hybrid | sleep | 1 - causes the device to enter 0 - normal operation (default) | hybrid sleep state |
| Partial [4:2] | array refresh | 000 - full array (default) 001 - bottom 1/2 Array 010 - bottom 1/4 Array 011 - bottom 1/8 Array 100 - none 101 - top 1/2 Array 110 - top 1/4 Array 111 - top 1/8 Array |  |
| Distributed [1:0] interval | refresh (read only) | 10 - 1μs tCSM (Industrial 11 - reserved 00 - reserved 01 - 4μs tCSM (Industrial | plus temperature range devices) temperature range devices) |
| Master clock type |  |  |  |

Master clock type
Two clock types, namely single ended and differential, are supported. CR1[6] selects which type to use.

• In the single ended clock mode (by default), CK# input is not enabled; hence it may be left either floating or
biased to HIGH or LOW.

• In the differential clock mode (when enabled), the CK# input can't be left floating. It must be either driven by
the host, or biased to HIGH or LOW.
Partial array refresh
The partial array refresh configuration restricts the refresh operation in HYPERRAM™ to a portion of the memory
array specified by CR1[5:3]. This reduces the standby current. The default configuration refreshes the whole
array.
Hybrid sleep (HS)
When the HYPERRAM™ is not needed for system operation but data in the device needs to be retained, it may be
placed in hybrid sleep state to save more power. Enter hybrid sleep state by writing 1 to CR1[5]. Bringing CS# LOW
will cause the device to exit HS state and set CR1[5] to 0. Also, POR, or a hardware reset will cause the device to
exit hybrid sleep state. Note that a POR or a hardware reset disables refresh where the memory core data can
potentially get lost.

Datasheet
26 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 27 -->

Datasheet
27 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Register space
Distributed refresh interval 
The HYPERRAM™ device is built with volatile DRAM array which requires periodic refresh of all bits in it. The refresh 
operation can be done by an internal self-refresh logic that will evenly refresh the memory array automatically. 
The automatic refresh operation can only be done when the memory array is not actively read or written by the 
host system. The refresh logic waits for the end of any active read or write before doing a refresh, if a refresh is 
needed at that time. If a new read or write begins before the refresh is completed, the memory will drive RWDS 
high during the CA period to indicate that an additional initial latency time is required at the start of the new 
access in order to allow the refresh operation to complete before starting the new access. The evenly distributed 
refresh operations require a maximum refresh interval between two adjacent refresh operations. The maximum 
distributed refresh interval varies with temperature as shown in Table 13.
The distributed refresh operation requires that the host does not perform burst transactions longer than the 
distributed refresh interval to prevent the memory from unable doing the distributed refreshes operation when 
it is needed. This sets an upper limit on the length of read and write transactions so that the automatic distributed 
refresh operation can be done between transactions. This limit is called the CS# low maximum time (tCSM) and 
the tCSM will be equal to the maximum distributed refresh interval. The host system is required to respect the tCSM 
value by terminating each transaction before violating tCSM. This can be done by host memory controller splitting 
long transactions when reaching the tCSM limit, or by host system hardware or software not performing a single 
burst read or write transaction that would be longer than tCSM. 
As noted in Table 13, the maximum refresh interval is longer at lower temperatures such that tCSM could be 
increased to allow longer transactions. The host may determine the operating temperature from a temperature 
sensor in the system and use the tCSM value from the table accordingly, or it may determine dynamically by 
reading the read only CR1[1:0] bits in order to set the distributed refresh interval prior to the HYPERRAM™ access.
Table 13
Array refresh interval per temperature
Operating temperature (°C)
Refresh interval tCSM (µs)
CR1[1:0]
TA ≤ 85 °C
4
01b
85 °C < TA ≤ 125 °C
1
10b

<!-- page 28 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Interface states

## 7 Interface states

Table 14 describes the required value of each signal for each interface state.

Table 14
Interface states

| Interface state |  | VCC / VCCQ | CS# |  | CK, |  | CK# |  | DQ7-DQ0 |  |  |  | RWDS |  | RESET# |  |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Power-off |  | < VLKO |  | X |  |  | X |  |  | HIGH-Z |  |  | HIGH-Z |  |  | X |
| Power-on (cold) reset | ≥ VCC | / VCCQ min |  | X |  |  | X |  |  | HIGH-Z |  |  | HIGH-Z |  |  | X |
| Hardware (warm) reset | ≥ VCC | / VCCQ min |  | X |  |  | X |  |  | HIGH-Z |  |  | HIGH-Z |  |  | L |
| Interface standby | ≥ VCC | / VCCQ min |  | H |  |  | X |  |  | HIGH-Z |  |  | HIGH-Z |  |  | H |
| CA | ≥ VCC | / VCCQ min |  | L |  |  | T | Master |  |  | output valid |  |  | Y |  | H |
| Read initial access latency (data bus turn around period) | ≥ VCC | / VCCQ min |  | L |  |  | T |  |  | HIGH-Z |  |  |  | L |  | H |
| Write initial access latency (RWDS turn around period) | ≥ VCC | / VCCQ min |  | L |  |  | T |  |  | HIGH-Z |  |  | HIGH-Z |  |  | H |
| Read data transfer | ≥ VCC | / VCCQ min |  | L |  |  | T | Slave |  |  | output valid | Slave valid |  | output Z or T |  | H |
| Write data transfer with initial latency | ≥ VCC | / VCCQ min |  | L |  |  | T | Master |  |  | output valid | Master valid |  | output X or T |  | H |
| Write data transfer without initial latency[42] | ≥ VCC | / VCCQ min |  | L |  |  | T | Master |  |  | output valid | Slave L | or HIGH-Z | output |  | H |
| stop[43] Active clock | ≥ VCC | / VCCQ min |  | L |  | Idle |  | Master output |  | HIGH-Z | or slave valid or |  |  | Y |  | H |
| Deep power down | ≥ VCC | / VCCQ min |  | H |  | X | or T |  |  | HIGH-Z |  |  | HIGH-Z |  |  | H |
| Hybrid sleep | ≥ VCC | / VCCQ min |  | H |  | X | or T |  |  | HIGH-Z |  |  | HIGH-Z |  |  | H |
| Notes 42. Writes without initial latency HYPERRAM™ device will always required. Since master write to drive RWDS LOW or may latency. Writes with zero latency (full word writes). 43. Active clock stop is described on page 30. | (with data take | zero initial latency), drive RWDS during immediately RWDS to HIGH-Z. do not use RWDS in “Active clock | follows stop” | the The as a on | CA the master data | do page | not have period CA period must mask 29. | to function. DPD | not | a indicate the | turn around whether HYPERRAM™ drive RWDS All bytes is described | period during of in | extended device write “Deep | for RWDS. latency may Writes data are power | The continue with written down” | is zero |

Legend
L = VIL; H = VIH; X = Either VIL or VIH; Y = either VIL or VIH or VOL or VOH; Z = Either VOL or VOH; L/H = Rising edge;
H/L = Falling edge; T = Toggling during information transfer; Idle = CK is LOW and CK# is HIGH;
Valid = All bus signals have stable L or H level

Datasheet
28 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 29 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Power conservation modes

## 8 Power conservation modes

## 8.1 Interface standby

STANDBY is the default, low power, state for the interface while the device is not selected by the host for data
transfer (CS# = HIGH). All inputs, and outputs other than CS# and RESET# are ignored in this state.

## 8.2 Active clock stop

Design note: Active clock stop feature is pending device characterization to determine if it will be supported.
The Active clock stop state reduces device interface energy consumption to the ICC6 level during the data transfer
portion of a read or write operation. The device automatically enables this state when clock remains stable for
tACC + 30 ns. While in active clock stop state, read data is latched and always driven onto the data bus. ICC6 shown
in “DC characteristics” on page 33.
Active clock stop state helps reduce current consumption when the host system clock has stopped to pause the
data transfer. Even though CS# may be LOW throughout these extended data transfer cycles, the memory device
host interface will go into the active clock stop current level at tACC + 30 ns. This allows the device to transition
into a lower current state if the data transfer is stalled. Active read or write current will resume once the data
transfer is restarted with a toggling clock. The active clock stop state must not be used in violation of the tCSM
limit. CS# must go HIGH before tCSM is violated. Clock can be stopped during any portion of the active transaction
as long as it is in the LOW state. Note that it is recommended to avoid stopping the clock during register access.

| CS# CK#, CK RWDS DQ[7:0] | High: 2X Latency Count Low: 1X Latency Count CMD CMD ADR ADR ADR ADR [7:0] [7:0] [31:24] [23:16] [15:8] [7:0] Command - Address (Host drives DQ[7:0] and Memory drives RWDS) | Latency Count (1X) | Clock Stopped RWDS & Data are edge aligned DoutA DoutB Output Driven [7:0] [7:0] Read Data | DoutA+1 [7:0] | DoutB+1 [7:0] |
|---|---|---|---|---|---|
| Figure 14 Active 8.3 Hybrid In the hybrid sleep CR1[5]. The device during HS state. Bringing hardware reset will refresh where the Following the exit | clock stop during read transaction sleep (HS) state, the current consumption reduces power within tHSIN time. CS# LOW will cause the device cause the device to exit hybrid sleep memory core data can potentially from HS due to any of these events, | (DDR)[44] is reduced (iHS). HS state The data in memory space to exit HS state and set state. Note that a POR get lost. Returning to STANDBY the device is in the same | is entered by writing and register space CR1[5] to 1. Also, POR, or a hardware reset state requires state as entering hybrid | a is retained or disables tEXITHS | 0 to a time. sleep. |
| CS# C K#, C K RW D S DQ [7:0] | H igh: 2X Latency Count Low: 1X Latency Count CM D CM D ADR ADR [7:0] [7:0] [31:24] [23:16] Com m and - Address (Host drives DQ[7:0], M em ory drives | ADR ADR RG RG [15:8] [7:0] [15:8] [7:0] W rite Data Enter CR0 Value RW DS) | tHSIN Hybrid Sleep HS tHSIN |  |  |

Figure 15
Enter HS transaction

Note

44. RWDS is LOW during the CA cycles. In this read transaction, there is a single initial latency count for read data
access because, this read transaction does not begin at a time when additional latency is required by the

Datasheet
29 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 30 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Power conservation modes

|  |  | CS# | tCSHS | tEXTHS |  |  |  |  |  |
|---|---|---|---|---|---|---|---|---|---|
| Figure 16 Exit Table 15 Hybrid | HS transaction sleep timing | parameters |  |  |  |  |  |  |  |
| Parameter |  | Description |  |  | Min |  | Max | Unit |  |
| tHSIN | Hybrid sleep CR1[5] | = 0 register | write | to DPD power level |  | - | 3 |  | µs |
| tCSHS | CS# pulse width | to exit HS |  |  | 60 |  | 3000 |  | ns |
| tEXTHS | CS# exit hybrid | sleep to standby | wakeup | time |  | - | 100 |  | µs |
| 8.4 Deep In the deep power down is entered by writing The data in memory will cause the device Returning to STANDBY time, as with any other state as following POR. | power down (DPD) state, a 0 to CR0[15]. space is lost, (becomes to exit DPD state. state requires POR. Following | current consumption The device invalid Also, POR, tEXTDPD time. the exit | reduces power without or a hardware Returning from DPD | is driven to the lowest possible within tDPDIN time and refresh) during DPD state. reset will cause the to STANDBY state following due to any of these events, | device | level all refresh Driving CS# to a POR the device | (IDPD). DPD operations LOW then exit DPD state. requires is in the | tVCS same | state stop. HIGH |
| CS# CK#, CK RW DS DQ[7:0] | High: 2X Low: 1X CM D CM [7:0] (Host | Latency Count Latency Count D ADR ADR [7:0] [31:24] [23:16] Com mand - Address drives DQ[7:0], M em ory | ADR ADR [15:8] drives RW DS) | tDPDIN RG RG [7:0] [15:8] [7:0] W rite Data Enter Deep Power CR0 Value tDPDIN |  | Down | DPD |  |  |
| Figure 17 Enter | DPD transaction |  |  |  |  |  |  |  |  |
|  | CS# | tCSDPD | tEXTDPD |  |  |  |  |  |  |
| Figure 18 Exit Table 16 Deep | DPD transaction power down | timing parameters |  |  |  |  |  |  |  |
| Parameter |  | Description |  |  | Min |  | Max | Unit |  |

tDPDIN
Deep power down CR0[15] = 0 register write to DPD power
level
-
3
µs

tCSDPD
CS# pulse width to exit DPD
200
3000
ns

tEXTDPD
CS# exit deep power down to standby wakeup time
-
150
µs

Datasheet
30 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 31 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Electrical specifications

## 9 Electrical specifications

## 9.1 Absolute maximum ratings[47]

Storage temperature plastic packages
-65 °C to +150 °C

Ambient temperature with power applied
-65 °C to +135 °C

Voltage with respect to ground all signals[45]
-0.5 V to + (VCC + 0.5 V)

Output short circuit current[46]
100 mA

Voltage on VCC, VCCQ pins relative to VSS
-0.5 V to +2.5 V

Electrostatic discharge voltage:
Human body model (JEDEC Std JESD22-A114-B)
Charged device model (JEDEC Std JESD22-C101-A)

2000 V
500 V

## 9.2 Input signal overshoot

During DC conditions, input or I/O signals should remain equal to or between VSS and VCC. During voltage transi-
tions, inputs or I/Os may negative overshoot VSS to -1.0 V or positive overshoot to VCC +1.0 V, for periods up to 20
ns.

|  | VSSQ to VCCQ - 1.0V | ≤ 20 ns |
|---|---|---|
| Figure 19 Maximum | negative overshoot waveform |  |
|  | ≤ VCCQ + 1.0V VSSQ to VCCQ | 20 ns |
| Figure 20 Maximum | positive overshoot waveform |  |

Notes

45. Minimum DC voltage on input or I/O signal is -1.0 V. During voltage transitions, input or I/O signals may
undershoot VSS to -1.0 V for periods of up to 20 ns. See Figure 19. Maximum DC voltage on input or I/O signals
is VCC +1.0 V. During voltage transitions, input or I/O signals may overshoot to VCC +1.0 V for periods up to 20
ns. See Figure 20.
46. No more than one output may be shorted to ground at a time. Duration of the short circuit should not be
greater than one second.
47. Stresses above those listed under “Absolute maximum ratings[47]” on page 31 may cause permanent
damage to the device. This is a stress rating only; functional operation of the device at these or any other
conditions above those indicated in the operational sections of this data sheet is not implied. Exposure of
the device to absolute maximum rating conditions for extended periods may affect device reliability.

Datasheet
31 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 32 -->

Datasheet
32 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Electrical specifications
9.3
Latch-up characteristics
9.3.1
Latch-up specification
9.4
Operating ranges
Operating ranges define those limits between which the functionality of the device is guaranteed.
9.4.1
Temperature ranges
Table 18
Temperature ranges
9.4.2
Power supply voltages
Table 17
Latch-up specification[48]
Description
Min
Max
Unit
Input voltage with respect to VSSQ on all input only connections
-1.0
VCCQ + 1.0
V
Input voltage with respect to VSSQ on all I/O connections
-1.0
VCCQ + 1.0
V
VCCQ current
-100
+100
mA
Note
48. Excludes power supplies VCC/VCCQ. Test conditions: VCC = VCCQ, one connection at a time tested, connections 
not being tested are at VSS.
Parameter
Symbol
Device
Spec
Unit
Min
Max
Ambient temperature
TA
Industrial (I)
-40
85
°C
Industrial plus (V)
-40
105
Automotive, AEC-Q100 grade 3 (A)
-40
85
Automotive, AEC-Q100 grade 2 (B)
-40
105
Automotive, AEC-Q100 grade 1 (M)
-40
125
Table 19
Power supply voltages
Description
Min
Max
Unit
VCC power supply
1.7
2.0
V

<!-- page 33 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Electrical specifications

## 9.5 DC characteristics

Table 20
DC characteristics (CMOS compatible)

| Parameter | Description | Test conditions | Min |  | Value Typ[49] | Max | Unit |
|---|---|---|---|---|---|---|---|
| Input leakage ILI2 device reset Input leakage ILI4 device reset | current VIN = signal high only VCC = current VIN = only[50] signal low VCC = | VSS to VCC, VCC max VSS to VCC, VCC max |  | - - | - - | 2 15 | µA |
| VCC active ICC1 operating VCC active ICC2 operating | read current temperature range CS# = VCC write current temperature range | VSS, CK@200 MHz, = VCC max |  | - - | 14 16 | 20 22 | mA |
|  | CS# = full array | VCC, VCC = VCC max; |  | - | 470 | 1200 |  |

| CS# = VCC, VCC = VCC max; bottom 1/2 array | - | - | 850 |
|---|---|---|---|
| CS# = VCC, VCC = VCC max; bottom 1/4 array | - | - | 700 |
| CS# = VCC, VCC = VCC max; bottom 1/8 array | - | - | 600 |
| CS# = VCC, VCC = VCC max; top 1/2 array | - | - | 850 |
| CS# = VCC, VCC = VCC max; top 1/4 array | - | - | 700 |
| CS# = VCC, VCC = VCC max; top 1/8 array CS# = VCC, VCC = VCC max; full array | - - 470 | - | 600 1550 |
| CS# = VCC, VCC = VCC max; bottom 1/2 array |  |  | 1150 |
| CS# = VCC, VCC = VCC max; bottom 1/4 array | - | - | 950 |
| CS# = VCC, VCC = VCC max; bottom 1/8 array | - | - | 850 |
| CS# = VCC, VCC = VCC max; top 1/2 array | - | - | 1150 |
| CS# = VCC, VCC = VCC max; top 1/4 array | - | - | 950 |
| CS# = VCC, VCC = VCC max; top 1/8 array | - | - | 850 |

VCC standby current
(-40 °C to +85 °C)

ICC4

µA

VCC standby current
(-40 °C to +105 °C)

ICC4
VCC standby current
(-40 °C to +125 °C)

CS# = VCC, VCC = VCC max;
full array
-
470
2000

Notes

49. Not 100% tested.
50. RESET# LOW initiates exits from DPD and hybrid state and initiates the draw of ICC5 reset current, making ILI
during RESET# LOW insignificant.

Datasheet
33 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 34 -->

Datasheet
34 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Electrical specifications
ICC4
VCC standby current 
(-40 °C to +125 °C)
CS# = VCC, VCC = VCC max; 
bottom 1/2 array 
-
-
1550
µA
CS# = VCC, VCC = VCC max; 
bottom 1/4 array
-
-
1250
CS# = VCC, VCC = VCC max; 
bottom 1/8 array
-
-
1100
CS# = VCC, VCC = VCC max; 
top 1/2 array
-
-
1550
CS# = VCC, VCC = VCC max; 
top 1/4 array
-
-
1250
CS# = VCC, VCC = VCC max; 
top 1/8 array
-
-
1100
ICC5
Reset current (-40°C to +85°C)
CS# = VCC, RESET# = VSS, 
VCC = VCCmax
-
-
0.55
mA
Reset current (-40°C to +105°C)
-
-
0.75
Reset current (-40°C to +125°C)
-
-
1
ICC6
Active clock stop current 
(-40 °C to +85 °C)
CS# = VSS, RESET# = VCC, 
VCC = VCC max
-
17
25
Active clock stop current 
(-40 °C to +105 °C)
-
17
30
Active clock stop current 
(-40 °C to +125 °C)
-
17
40
ICC7
VCC current during power up[49] CS# = VCC, VCC = VCC max, 
VCCQ = VCC 
-
-
35
mA
IDPD
[50]
Deep power down current 
(-40 °C to +85 °C)
CS# = VCC, VCC = VCC max
-
-
12
µA
IDPD
[50]
Deep power down current 
(-40 °C to +105 °C)
CS# = VCC, VCC = VCC max
-
-
15
IDPD
[50]
Deep power down current 
(-40 °C to +125 °C)
CS# = VCC, VCC = VCC max
-
-
20
IHS
[50]
Hybrid sleep current 
(-40 °C to +85 °C)
CS# = VCC, VCC = VCC max; 
full array
-
140
1100
CS# = VCC, VCC = VCC max; 
bottom 1/2 array
-
-
800
CS# = VCC, VCC = VCC max; 
bottom 1/4 array
-
-
600
CS# = VCC, VCC = VCC max; 
bottom 1/8 array
-
-
500
CS# = VCC, VCC = VCC max; 
top 1/2 array
-
-
800
Table 20
DC characteristics (CMOS compatible) (continued)
Parameter
Description
Test conditions
Value
Unit
Min
Typ[49]
Max
Notes
49. Not 100% tested.
50. RESET# LOW initiates exits from DPD and hybrid state and initiates the draw of ICC5 reset current, making ILI 
during RESET# LOW insignificant.

<!-- page 35 -->

Datasheet
35 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Electrical specifications
IHS
[50]
Hybrid sleep current 
(-40 °C to +85 °C)
CS# = VCC, VCC = VCC max; 
top 1/4 array
-
-
600
µA
CS# = VCC, VCC = VCC max; 
top 1/8 array
-
-
500
Hybrid sleep current 
(-40 °C to +105 °C)
CS# = VCC, VCC = VCC max; 
full array
-
140
1250
CS# = VCC, VCC = VCC max; 
bottom 1/2 array
-
-
850
CS# = VCC, VCC = VCC max; 
bottom 1/4 array
-
-
650
CS# = VCC, VCC = VCC max; 
bottom 1/8 array
-
-
550
CS# = VCC, VCC = VCC max; 
top 1/2 array
-
-
850
CS# = VCC, VCC = VCC max; 
top 1/4 array
-
-
650
CS# = VCC, VCC = VCC max; 
top 1/8 array
-
-
550
Hybrid sleep current 
(-40 °C to +125 °C)
CS# = VCC, VCC = VCC max; 
full array
-
140
1500
CS# = VCC, VCC = VCC max; 
bottom 1/2 array
-
-
1150
CS# = VCC, VCC = VCC max; 
bottom 1/4 array
-
-
900
CS# = VCC, VCC = VCC max; 
bottom 1/8 array
-
-
750
CS# = VCC, VCC = VCC max; 
top 1/2 array
-
-
1150
CS# = VCC, VCC = VCC max; 
top 1/4 array
-
-
900
CS# = VCC, VCC = VCC max; 
top 1/8 array
-
-
750
VIL
Input low voltage
-
-0.15 x 
VCCQ
-
0.30 x 
VCCQ
V
VIH
Input high voltage
-
0.70 x 
VCCQ
-
1.15 x 
VCCQ
VOL
Output low voltage
IOL = 100 µA for DQ[7:0]
-
-
0.20
VOH
Output high voltage
VCCQ-0.20
-
-
Table 20
DC characteristics (CMOS compatible) (continued)
Parameter
Description
Test conditions
Value
Unit
Min
Typ[49]
Max
Notes
49. Not 100% tested.
50. RESET# LOW initiates exits from DPD and hybrid state and initiates the draw of ICC5 reset current, making ILI 
during RESET# LOW insignificant.

<!-- page 36 -->

Datasheet
36 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Electrical specifications
9.5.1
Capacitance characteristics
Table 21
Capacitive characteristics[51-53]
Description
Parameter
256 Mb
Unit
Max
Input capacitance (CK, CK#, CS#)
CI
3.0
pF
Delta input capacitance (CK, CK#)
CID
0.25
Output capacitance (RWDS)
CO
3.0
IO capacitance (DQx)
CIO
3.0
IO capacitance delta (DQx)
CIOD
0.25
Notes
51. These values are guaranteed by design and are tested on a sample basis only.
52. Contact capacitance is measured according to JEP147 procedure for measuring capacitance using a vector 
network analyzer. VCC, VCCQ are applied and all other signals (except the signal under test) floating. DQs 
should be in the high impedance state.
53. Note that the capacitance values for the CK, CK#, RWDS and DQx signals must have similar capacitance 
values to allow for signal propagation time matching in the system. The capacitance value for CS# is not as 
critical because there are no critical timings between CS# going active (LOW) and data being presented on 
the DQ’s bus.
Table 22
Thermal resistance
Parameter[54]
Description
Test conditions
24-ball FBGA 
package
Unit
θJA
Thermal resistance
(junction to ambient)
Test conditions follow standard test 
methods and procedures for 
measuring thermal impedance, per 
EIA/JESD51.
40.8
°C/W
θJC
Thermal resistance
(junction to case)
8
Note
54. This parameter is guaranteed by characterization; not tested in production.

<!-- page 37 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Electrical specifications

## 9.6 Power-up initialization

HYPERRAM™ products include an on-chip voltage sensor used to launch the power-up initialization process. VCC
and VCCQ must be applied simultaneously. When the power supply reaches a stable level at or above VCC(min),
the device will require tVCS time to complete its self-initialization process.
The device must not be selected during power-up. CS# must follow the voltage applied on VCCQ until VCC (min) is
reached during power-up, and then CS# must remain HIGH for a further delay of tVCS. A simple pull-up resistor
from VCCQ to chip select (CS#) can be used to insure safe and proper power-up.
If RESET# is LOW during power up, the device delays start of the tVCS period until RESET# is HIGH. The tVCS period
is used primarily to perform refresh operations on the DRAM array to initialize it.
When initialization is complete, the device is ready for normal operation.

|  | Vcc_VccQ CS# RESET# | VCC Minimum | tVCS |  | Device Access Allowed |  |
|---|---|---|---|---|---|---|
| Figure 21 Power-up | with RESET# HIGH |  |  |  |  |  |
| Vcc_VccQ CS# RESET# | VCC | Minimum | tVCS |  | Device Access Allowed |  |
| Figure 22 Power-up Table 23 Power | with RESET# LOW up and reset parameters[55, | 56, 57] |  |  |  |  |
| Parameter | Description |  |  | Min | Max Unit |  |
| VCC | VCC power supply |  |  | 1.7 | 2.0 | V |
| tVCS | VCC and VCCQ ≥ minimum first access | and RESET# | HIGH to | - | 150 | µs |
| Notes 55. Bus transactions 56. VCCQ must be the 57. VCC ramp rate may | (read and write) are not same voltage as VCC. be non-linear. | allowed during | the power-up | reset | time (tVCS). |  |

Datasheet
37 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 38 -->

Datasheet
38 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Electrical specifications
9.7
Power down
HYPERRAM™ devices are considered to be powered-off when the array power supply (VCC) drops below the VCC 
lock-out voltage (VLKO). During a power supply transition down to the VSS level, VCCQ should remain less than or 
equal to VCC. At the VLKO level, the HYPERRAM™ device will have lost configuration or array data.
VCC must always be greater than or equal to VCCQ (VCC ≥ VCCQ). 
During power-down or voltage drops below VLKO, the array power supply voltages must also drop below VCC 
Reset (VRST) for a power down period (tPD) for the part to initialize correctly when the power supply again rises to 
VCC minimum. See Figure 23. 
If during a voltage drop the VCC stays above VLKO the part will stay initialized and will work correctly when VCC is 
again above VCC minimum. If VCC does not go below and remain below VRST for greater than tPD, then there is no 
assurance that the POR process will be performed. In this case, a hardware reset will be required ensure the 
HYPERBUS™ device is properly initialized.
Figure 23
Power down or voltage drop
The following section describes the HYPERRAM™ device-dependent aspects of power down specifications.
Table 24
Power-down voltage and timing[57]
Symbol
Parameter
Min
Max
Unit
VCC
VCC power supply
1.7
2.0
V
VLKO
VCC lock-out below which re-initialization is required
1.5
-
VRST
VCC low voltage needed to ensure initialization will occur
0.7
-
tPD
Duration of VCC ≤ VRST
50
-
µs
VCC (Max)
VCC (Min)
VLKO
VRST
tVCS
Device Access 
Allowed
No Device Access Allowed
t
Time
VCC
PD

<!-- page 39 -->

Datasheet
39 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Electrical specifications
9.8
Hardware reset
The RESET# input provides a hardware method of returning the device to the STANDBY state.
During tRPH the device will draw ICC5 current. If RESET# continues to be held LOW beyond tRPH, the device draws 
CMOS standby current (ICC4). While RESET# is LOW (during tRP), and during tRPH, bus transactions are not allowed.
A hardware reset will do the following:
• Cause the configuration registers to return to their default values
• Halt self-refresh operation while RESET# is LOW - memory array data is considered as invalid
• Force the device to exit the hybrid sleep state
• Force the device to exit the deep power down state
After RESET# returns HIGH, the self-refresh operation will resume. Because self-refresh operation is stopped 
during RESET# LOW, and the self-refresh row counter is reset to its default value, some rows may not be refreshed 
within the required array refresh interval per Table 13. This may result in the loss of DRAM array data during or 
immediately following a hardware reset. The host system should assume DRAM array data is lost after a hardware 
reset and reload any required data.
Figure 24
Hardware reset timing diagram
Table 25
Power up and reset parameters
Parameter
Description
Min
Max
Unit
tRP
RESET# pulse width
200
-
ns
tRH
Time between RESET# (HIGH) and CS# (LOW)
200
-
tRPH
RESET# LOW to CS# LOW
400
-
RESET#
CS#
tRP
tRH
tRPH

<!-- page 40 -->

Datasheet
40 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Timing specifications
10
Timing specifications
The following section describes HYPERRAM™ device dependent aspects of timing specifications.
10.1
Key to switching waveforms
Figure 25
Key to switching waveforms
10.2
AC test conditions
Figure 26
Test setup
Table 26
Test specification[59]
Parameter
All speeds
Unit
Output load capacitance, CL
15
pF
Minimum input rise and fall slew rates (1.8 V)[58]
1.13
V/ns
Input pulse levels
0.0-VCCQ
V
Input timing measurement reference levels
VCCQ/2
Output timing measurement reference levels
VCCQ/2
Notes
58. All AC timings assume this input slew rate.
59. Input and output timing is referenced to VCCQ/2 or to the crossing of CK/CK#.
Valid_High_or_Low
High_to_Low_Transition
Low_to_High_Transition
Invalid
High_Impedance
Device 
Under 
Test
CL

<!-- page 41 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Timing specifications

| VccQ Vss |  | Input VccQ / 2 |  | Measurement | Level | VccQ | / 2 Output |
|---|---|---|---|---|---|---|---|
| Figure 27 10.3 | Input CLK | waveforms and measurement characteristics |  | levels[60] |  |  |  |
| CK# CK |  | tCKHP |  | tCK tCKHP |  |  | VIX (Max) VCCQ / 2 VIX (Min) |
| Figure 28 Table 27 | Clock Clock | characteristics timings[61-63] |  |  |  |  |  |
| Parameter |  | Symbol |  |  | 200 MHZ Min |  | Unit Max |
| CK period |  |  | tCK |  | 5 |  | – ns |
| CK half period | - duty | cycle | tCKHP |  | 0.45 |  | 0.55 tCK |
| CK half period Min = 0.45 tCK Min Max = 0.55 tCK | at Min | frequency | tCKHP |  | 2.25 |  | 2.75 ns |

Notes

60. Input timings for the differential CK/CK# pair are measured from clock crossings.
61. Clock jitter of ±5% is permitted.
62. Minimum frequency (Maximum tCK) is dependent upon maximum CS# LOW time (tCSM), initial latency and
burst length.
63. CK and CK# input slew rate must be ≥ 1 V/ns (2 V/ns if measured differentially).

Datasheet
41 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 42 -->

Datasheet
42 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Timing specifications
Figure 29
Differential clock (CK/CK#) input swing
Table 28
Clock AC/DC electrical characteristics[64, 65]
Parameter
Symbol
Min
Max 
Unit 
DC input voltage
VIN
–0.3
VCCQ+ 0.3
V
DC input differential voltage
VID(DC)
VCCQ x 0.4
VCCQ+ 0.6
AC input differential voltage
VID(AC)
VCCQ x 0.6
VCCQ + 0.6
AC differential crossing voltage
VIX
VCCQ x 0.4
VCCQ x 0.6
Notes
64. VID is the magnitude of the difference between the input level on CK and the input level on CK#.
65. The value of VIX is expected to equal VCCQ/2 of the transmitting device and must track variations in the DC 
level of VCCQ.
half cycle
 VID (AC) (min) 
 VID (DC) (min) 
 -VID (DC) (min) 
 -VID (AC) (min) 
time
Differential Input Voltage (CK-CK#)
0

<!-- page 43 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Timing specifications

## 10.4 AC characteristics

## 10.4.1 Read transactions

Table 29
HYPERRAM™ specific read timing parameters

| Parameter | Symbol | 200 MHz Min Max | Unit |
|---|---|---|---|
| Chip select high between transactions | tCSHI | 6 – |  |

| HYPERRAM™ read-write recovery time |  | tRWR |  | 35 |  | – |
|---|---|---|---|---|---|---|
| Chip select setup to next CK rising edge |  | tCSS |  | 4.0 |  | – |
| Data strobe valid |  | tDSV |  | – | 5.0 |  |
| Input setup |  | tIS |  | 0.5 |  | – |
| Input hold |  | tIH |  | 0.5 |  | – |
| HYPERRAM™ read initial access time |  | tACC |  | 35 |  | – |
| Clock to DQs low Z CK transition to DQ valid |  | tDQLZ tCKD |  | 0 1 | 5.0 | – |
| CK transition to DQ invalid |  | tCKDI |  | 0 | 4.2 |  |
| Data valid (tDV min = the lesser of: tCKHP min - tCKD max + tCKDI max) or tCKHP min tDV - tCKD min + tCKDI min) |  | [66, 67] | 1.45 |  |  | – |
| CK transition to RWDS valid |  | tCKDS |  | 1.0 | 5.0 |  |
| RWDS transition to DQ valid |  | tDSS | –0.4 |  | +0.4 |  |
| RWDS transition to DQ invalid |  | tDSH | –0.4 |  | +0.4 |  |
| Chip select hold after CK falling edge |  | tCSH |  | 0 |  | – |
| Chip select inactive to RWDS High-Z |  | tDSZ |  | – | 5.0 |  |
| Chip select inactive to DQ High-Z |  | tOZ |  | – | 5.0 |  |
| Refresh time |  | tRFH |  | 35 |  | – |
| CK transition to RWDS Low @CA phase @Read | tCKDSR |  |  | 1.0 | 5.5 |  |

ns

Notes

66. Refer to Figure 32 for data valid timing.
67. The tDV timing calculation is provided for reference only, not to determine the spec limit. The spec limit is
guaranteed by testing

Datasheet
43 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 44 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Timing specifications

| CS# CK , CK# RWDS DQ[7:0] | tCSHI tCSM tCSS tRWR =Read Write Recovery tACC = Access tDSV 4 cycle latency High = 2x Latency Count Low = 1x Latency Count tIS tIH 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives RWDS | tCSH tCSS tCKDS tDSS tOZ tDQLZ tCKD tDSH Dn Dn Dn+1 Dn+1 A B A B RWDS and Data Memory drives DQ[7:0] are edge aligned and RWDS | tDSZ |
|---|---|---|---|
| Figure 30 Read | timing diagram — No additional latency required |  |  |
| CS# tRWR CK , CK# RWDS DQ[7:0] | =Read Write Recovery Additional Latency tACC 4 cycle latency 1 4 cycle tDSV tCKDS High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[7:0] and Memory drives RWDS | = Access latency 2 tCKDS tCKD Dn Dn A B Memory drives and RWDS | Dn+1 Dn+1 A B DQ[7:0] |
| Figure 31 Read | timing diagram — with additional latency required |  |  |
| CS# CK CK# RWDS DQ[7:0] | tCKHP tCKDS tCKD tDQLZ tCKD Dn A | tCSHS tCSS tOZ tDSS tCKDI tDSH tDV Dn Dn+1 Dn+1 B A | tDSZ B |
| Figure 32 Data | timing[68-70] valid |  |  |

Notes

68. tCKD and tCKDI parameters define the beginning and end position of data valid period.
69. tDSS and tDSH define how early or late DQ may transition relative to RWDS. This is a potential skew between
the CK to DQ delay tCKD and CK to RWDS delay tCKDS.
70. Since DQ and RWDS are the same output types, the tCKD, and tCKDS values track together (vary by the same
ratio).

Datasheet
44 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 45 -->

Datasheet
45 of 54
002-31337 Rev. *C
2021-09-27
 
256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™ 
interface
1.8 V 
Timing specifications
10.4.2
Write transactions
Figure 33
Write timing diagram — No additional latency
Table 30
Write timing parameters
Parameter
Symbol
200 MHz
Unit 
Min
Max
Read-write recovery time
tRWR
35
-
ns
Access time
tACC
35
-
Refresh time
tRFH
35
-
Chip select maximum low time (85 °C)
tCSM
-
4
µs
Chip select maximum low time (105 °C and 125 °C)
tCSM
-
1
RWDS data mask valid
tDMV
0
-
CS#
CK#
,
CK
RWDS
DQ[7:0]
tRWR =Read Write Recovery
tACC = Access
4 cycle latency
Command-Address
tCSHI
tCSM
tCSS
tCSS
tDSV
tDSZ
tIS
tIS
tIS
tIH
tIH
tIH
tCSH
tDMV
47:40
39:32
31:24
23:16
15:8
7:0
High = 2x Latency Count
Low =  1x Latency Count
Dn
 A
Dn
 B
Dn+1
   A
Dn+1
   B
Host drives DQ[7:0] and Memory drives RWDS
Host drives DQ[7:0] 
and RWDS
CK and Data
are center aligned

<!-- page 46 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Timing specifications

## 10.5 Timing reference levels

tCK

VCCQ

CK, CK#

VT

VSSQ

tIS
tIH
tIS
tIH
VCCQ

VIH(min)

VIL(max)
RWDS
VT

VSSQ

tIS
tIH
tIS
tIH
VCCQ

VIH(min)

VT

DQ[7:0]

VIL(max)

VSSQ

| Figure 34 | DDR input timing reference levels |
|---|---|
|  | tSCK VCCQ RWDS VT VSSQ tDSS tDSH VCCQ VOH(min) VT DQ[7:0] VOL(max) VSSQ |
| Figure 35 | DDR output timing reference levels |

Datasheet
46 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 47 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Physical interface

## 11 Physical interface

## 11.1 FBGA 24-ball 5 x 5 array footprint

HYPERRAM™ devices are provided in fortified ball grid array (FBGA), 1-mm pitch, 24-ball, 5 x 5 ball array footprint,
with 6 mm x 8 mm body.

| A B C D E | 1 CK# VssQ VccQ DQ7 | 2 RFU CK RFU DQ1 DQ6 | 3 CS# Vss RWDS DQ0 DQ5 | 4 RESET# Vcc DQ2 DQ3 VccQ | 5 RFU RFU RFU DQ4 VssQ |
|---|---|---|---|---|---|
| Figure 36 24-ball FBGA, 6 x 8 mm, 5 x | 5 ball | footprint, |  | top view |  |

Datasheet
47 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 48 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Physical interface

## 11.2 Package diagrams

NOTES:

DIMENSIONS
SYMBOL
MIN.
NOM.
MAX.

1.

DIMENSIONING AND TOLERANCING METHODS PER ASME Y14.5M-1994.

A

-
1.00

-

2.

ALL DIMENSIONS ARE IN MILLIMETERS.

-

A1
0.20

-

3.

BALL POSITION DESIGNATION PER JEP95, SECTION 3, SPP-020.

8.00 BSC

D

4.

"e"   REPRESENTS THE SOLDER BALL GRID PITCH.

E

6.00 BSC

5.

SYMBOL "MD" IS THE BALL MATRIX SIZE IN THE "D" DIRECTION.

4.00 BSC

D1

SYMBOL "ME" IS THE BALL MATRIX SIZE IN THE "E" DIRECTION.

E1

4.00 BSC

N IS THE NUMBER OF POPULATED SOLDER BALL POSITIONS FOR MATRIX SIZE MD X ME.

MD

5

6

DIMENSION "b" IS MEASURED AT THE MAXIMUM BALL DIAMETER IN A PLANE PARALLEL TO DATUM C.

ME

5

N

24

7

"SD" AND "SE" ARE MEASURED WITH RESPECT TO DATUMS A AND B AND DEFINE THE

0.40

0.35

0.45

b

POSITION OF THE CENTER SOLDER BALL IN THE OUTER ROW.

eE

1.00 BSC

WHEN THERE IS AN ODD NUMBER OF SOLDER BALLS IN THE OUTER ROW "SD" OR "SE" = 0.

eD

1.00 BSC

WHEN THERE IS AN EVEN NUMBER OF SOLDER BALLS IN THE OUTER ROW, "SD" = eD/2 AND "SE" = eE/2.

0.00 BSC

SD

"+" INDICATES THE THEORETICAL CENTER OF DEPOPULATED BALLS.

8.

SE
0.00 BSC

A1 CORNER TO BE IDENTIFIED BY CHAMFER, LASER OR INK MARK, METALLIZED MARK INDENTATION
9.

JEDEC SPECIFICATION NO. REF: N/A
10.
002-15550 *A

OR OTHER MEANS.

Figure 37
Fortified ball grid array 24-ball 6 x 8 x 1.0 mm (VAA024)

Datasheet
48 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 49 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Ordering information

## 12 Ordering information

## 12.1 Ordering part number

The ordering part number is formed by a valid combination of the following:

S80KS
256
2
GA
B
H
I
02
0

Packing type
0 = Tray
3 = 13” Tape and Reel

Model number (additional ordering options)
02 = Standard 6 x 8 x 1.0 mm package (VAA024)

Temperature range / grade
I = Industrial (–40 °C to + 85 °C)
V= Industrial Plus (–40 °C to + 105 °C)
A = Automotive, AEC-Q100 Grade3 (–40 °C to + 85 °C)
B = Automotive, AEC-Q100 Grade2 (–40 °C to + 105 °C)
M =Automotive, AEC-Q100 Grade1 (–40 °C to + 125 °C)

Package materials

H = Low-Halogen, Pb-free

Package type
B = 24-ball FBGA, 1.00 mm pitch (5x5 ball footprint)

Speed
GA = 200 MHz

Device technology
2 = HYPERBUS™
3 = Octal xSPI
4 = HYPERBUS™ Extended-IO

Density
256 = 256 Mb

Device family
S80KS - Infineon Memory 1.8 V-only, HYPERRAM™ Self-refresh DRAM

Datasheet
49 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 50 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Ordering information

## 12.2 Valid combinations

The recommended combinations table lists configurations planned to be available in volume. Table 31 will be
updated as new combinations are released. Contact your local sales representative to confirm availability of
specific combinations and to check on newly released combinations.

Table 31
Valid combinations - standard

| Device Density family |  | Technology |  | Speed |  | Package, Model material, and number temperature | Packing type |  | Ordering part number | Package marking |
|---|---|---|---|---|---|---|---|---|---|---|
| S80KS | 256 |  | 2 |  | GA | BHI | 02 | 0 | S80KS2562GABHI020 | 8KS2562GAHI02 |
| S80KS | 256 |  | 2 |  | GA | BHI | 02 | 3 | S80KS2562GABHI023 | 8KS2562GAHI02 |
| S80KS | 256 |  | 2 |  | GA | BHV | 02 | 0 | S80KS2562GABHV020 | 8KS2562GAHV02 |
| S80KS | 256 |  | 2 |  | GA | BHV | 02 | 0 | S80KS2562GABHV023 | 8KS2562GAHV02 |
| 12.3 Table 32 list volume. The confirm availability Production Products to products in compliance AEC-Q100 ISO/TS-16949 Table 32 | grade | Valid configurations table will of part approval be used in combination with ISO/TS-16949 products compliance. Valid combinations | combinations be specific end-use | that updated combinations process applications with PPAP. requirements. are also | are | - Automotive Automotive grade / as new combinations and to check (PPAP) support is only that require Non-AEC-Q100 grade offered without PPAP - Automotive grade | grade AEC-Q100 are released. on newly provided ISO/TS-16949 products support / AEC-Q100 | / AEC-Q100 qualified Contact released for AEC-Q100 are for end-use | and are planned to your local sales combinations. grade products. compliance must be AEC-Q100 not manufactured or documented applications that | be available in representative to grade in full do not require |
| Device Density family |  | Technology |  | Speed |  | Package, Model material, and number temperature | Packing type | Ordering | part number | Package marking |
| S80KS |  | 256 |  | 2 |  | GA BHA | 02 | 0 | S80KS2562GABHA020 | 8KS2562GAHA02 |
| S80KS |  | 256 |  | 2 |  | GA BHA | 02 | 3 | S80KS2562GABHA023 | 8KS2562GAHA02 |
| S80KS |  | 256 |  | 2 |  | GA BHB | 02 | 0 | S80KS2562GABHB020 | 8KS2562GAHB02 |
| S80KS |  | 256 |  | 2 |  | GA BHB | 02 | 3 | S80KS2562GABHB023 | 8KS2562GAHB02 |
| S80KS |  | 256 |  | 2 |  | GA BHM | 02 | 0 | S80KS2562GABHM020 | 8KS2562GAHM02 |
| S80KS |  | 256 |  | 2 |  | GA BHM | 02 | 3 | S80KS2562GABHM023 | 8KS2562GAHM02 |

Datasheet
50 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 51 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Acronyms

## 13 Acronyms

Table 33
Acronyms used in this document

| Acronym |  | Description |
|---|---|---|
| CMOS | complementary metal oxide semiconductor |  |
| DDR | double data rate |  |
| DPD | deep power down |  |
| DRAM | dynamic RAM |  |
| HS | hybrid sleep |  |
| MSb | most significant bit |  |
| POR | power-on reset |  |
| PSRAM | pseudo static RAM |  |
| PVT | process, voltage, and temperature |  |
| RWDS | read-write data strobe |  |
| SPI | serial peripheral interface |  |
| xSPI | expanded serial peripheral interface |  |

Datasheet
51 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 52 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Document conventions

## 14 Document conventions

## 14.1 Units of measure

Table 34
Units of measure

| Symbol |  | Unit of measure |
|---|---|---|
| °C | degree Celsius |  |
| MHz | megahertz |  |
| µA | microampere |  |
| µs | microsecond |  |
| mA | milliampere |  |
| mm | millimeter |  |
| ns | nanosecond |  |
| Ω | ohm |  |
| % | percent |  |
| pF | picofarad |  |
| V | volt |  |
| W | watt |  |

Datasheet
52 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 53 -->

256 Mb: HYPERRAM™ self-refresh dynamic RAM (DRAM) with HYPERBUS™
interface
1.8 V

Revision history

## Revision history

| Document version | Date of release | Description of changes |
|---|---|---|
| *C | 2021-09-27 Publish to web. |  |

Datasheet
53 of 54
002-31337 Rev. *C
2021-09-27

<!-- page 54 -->

Trademarks
All referenced product or service names and trademarks are the property of their respective owners.

IMPORTANT NOTICE
The information given in this document shall in no
event be regarded as a guarantee of conditions or
characteristics (“Beschaffenheitsgarantie”).

For further information on the product, technology,
delivery terms and conditions and prices please
contact your nearest Infineon Technologies office
(www.infineon.com).

Edition 2021-09-27

Published by

Infineon Technologies AG

With respect to any examples, hints or any typical
values stated herein and/or any information
regarding the application of the product, Infineon
Technologies
hereby
disclaims
any
and
all
warranties and liabilities of any kind, including
without limitation warranties of non-infringement of
intellectual property rights of any third party.

81726 Munich, Germany

WARNINGS
Due to technical requirements products may contain
dangerous substances. For information on the types
in question please contact your nearest Infineon
Technologies office.

© 2021 Infineon Technologies AG.
All Rights Reserved.

Except as otherwise explicitly approved by Infineon
Technologies in a written document signed by
authorized
representatives
of
Infineon
Technologies, Infineon Technologies’ products may
not be used in any applications where a failure of the
product or any consequences of the use thereof can
reasonably be expected to result in personal injury.

In addition, any information given in this document
is subject to customer’s compliance with its
obligations stated in this document and any
applicable legal requirements, norms and standards
concerning customer’s products and any use of the
product of Infineon Technologies in customer’s
applications.

Do you have a question about this
document?

Go to www.cypress.com/support

Document reference

002-31337 Rev. *C

The data contained in this document is exclusively
intended for technically trained staff. It is the
responsibility of customer’s technical departments
to evaluate the suitability of the product for the
intended application and the completeness of the
product information given in this document with
respect to such application.

<!-- END VERBATIM SOURCE -->
