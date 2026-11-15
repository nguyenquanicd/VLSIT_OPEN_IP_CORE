---
protocol: "Infineon S80KS2564 HyperRAM Extended-I/O datasheet"
revision: "002-31341 Rev C"
source: "https://www.infineon.com/assets/row/public/documents/10/49/infineon-data-sheet-hyperram-datasheet-en.pdf"
license: "Infineon Technologies AG copyright; all rights reserved"
redistribution: "forbidden"
retrieved: 2026-10-27
source_sha256: "e8de950a327546c2eb79c2637e6473add3deb4b466a00795f6b0eda0422103f2"
converter: "vlsit_pdf_to_md.py (PyMuPDF)"
---

# Infineon S80KS2564 HyperRAM Extended-I/O datasheet - revision 002-31341 Rev C

> **Key notes (written by the converter operator, not part of the source):**
> - none recorded

> The text between the markers below is the source text, converted without rewording.

<!-- BEGIN VERBATIM SOURCE -->

<!-- page 1 -->

# S80KS2564

# 256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)

## HYPERBUS™ Extended-IO (x16) interface, 1.8 V

## Features

• Interface
- HYPERBUS™ extended-IO
- 1.7 to 2.0 V (1.8 typ.) interface support

• Single-ended clock (CK) - 20 bus signals
• Optional differential clock (CK, CK#) - 21 bus signals
- Chip Select (CS#)
- 16-bit data bus (DQ[15:0])
- Hardware reset (RESET#)
- Bidirectional read-write data strobe (RWDS [1:0])

• Output at the start of all transactions to indicate refresh latency
• Output during read transactions as read data strobe
• Input during write transactions as write data mask

• Performance, power, and packages
- 200 MHz maximum clock rate
- DDR - transfers data on both edges of the clock
- Data throughput up to 800 MBps (6,400 Mbps)
- Configurable burst characteristics

• Linear burst
• Wrapped burst lengths:
16 words (8 clocks)
32 words (16 clocks)
64 words (32 clocks)
128 words (64 clocks)
• Hybrid option - one wrapped burst followed by linear burst
- Configurable output drive strength
- Power modes

• Hybrid Sleep mode
• Deep Power Down
- Memory array refresh

• Partial array (1/8, 1/4, 1/2, and so on)
• Full array
- Package

• 49-ball FBGA
- Operating temperature range

• Industrial (I): –40°C to +85°C
• Industrial Plus (V): –40°C to +105°C

• Technology
- 25 nm DRAM

Datasheet
Please read the Important Notice and Warnings at the end of this document
002-31341 Rev. *C
www.infineon.com
page 1 of 48
2022-04-18

<!-- page 2 -->

## 256Mb HYPERRAM™ self-refresh DRAM (PSRAM) HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Performance summary

## Performance summary

| Read transaction timings | Unit |
|---|---|
| Maximum clock rate at 1.8 V VCC/VCCQ 200 | MHz |
| Maximum access time (tACC) | 35 ns |
| Maximum current consumption | Unit |
| Burst read or write (linear burst at 200 MHz) 20 mA/22 | mA |
| Standby 1.55 | μA |
| Deep power down | 15 μA |
| Logic block diagram |  |

X Decoders

CS#

Memory

CK/CK#

RWDS [1:0]

Control

Y Decoders

I/O

Logic

DQ[15:0]

Data Latch

RESET#

Data Path

Datasheet
2 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 3 -->

## 256 Mb HYPERRAM™ self-refresh DRAM (PSRAM) HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Table of contents

## Table of contents

Features ...........................................................................................................................................1
Performance summary ......................................................................................................................2
Logic block diagram ..........................................................................................................................2
Table of contents...............................................................................................................................3
1 General description.........................................................................................................................5
1.1 HYPERBUS™ extended-IO interface .......................................................................................................................5
2 Product overview ...........................................................................................................................8
2.1 HYPERBUS™ extended-IO interface .......................................................................................................................8
3 Signal description...........................................................................................................................9
3.1 Input/output summary...........................................................................................................................................9
4 HYPERBUS™ extended-IO transaction details..................................................................................10
4.1 Command/address bit assignments....................................................................................................................10
4.2 Read transactions (Memory array and registers) ................................................................................................13
4.3 Write transactions (memory array write) ............................................................................................................14
4.4 Write transactions without initial latency (register write)..................................................................................16
5 Memory space ..............................................................................................................................17
5.1 HYPERBUS™ extended-IO interface .....................................................................................................................17
6 Register space ..............................................................................................................................18
6.1 HYPERBUS™ extended-IO interface .....................................................................................................................18
6.2 Device Identification registers..............................................................................................................................18
6.2.1 Density and row boundaries .............................................................................................................................19
6.3 Register space access ...........................................................................................................................................19
6.3.1 Configuration register 0.....................................................................................................................................19
6.3.2 Configuration Register 1....................................................................................................................................23
7 Interface states ............................................................................................................................25
8 Power conservation modes............................................................................................................26
8.1 Interface standby..................................................................................................................................................26
8.2 Active clock stop ...................................................................................................................................................26
8.3 Hybrid sleep ..........................................................................................................................................................27
8.4 Deep power down.................................................................................................................................................28
9 Electrical specifications.................................................................................................................29
9.1 Absolute maximum ratings ..................................................................................................................................29
9.2 Input signal overshoot..........................................................................................................................................29
9.3 Latch-up characteristics.......................................................................................................................................30
9.3.1 Latch-up specification.......................................................................................................................................30
9.4 Operating ranges ..................................................................................................................................................30
9.4.1 Temperature ranges ..........................................................................................................................................30
9.4.2 Power supply voltages.......................................................................................................................................30
9.5 DC characteristics .................................................................................................................................................31
9.5.1 Capacitance characteristics ..............................................................................................................................33
9.6 Power-up initialization .........................................................................................................................................34
9.7 Power down ..........................................................................................................................................................35
9.8 Hardware reset......................................................................................................................................................36
10 Timing specifications ..................................................................................................................37
10.1 Key to switching waveforms...............................................................................................................................37
10.2 AC test conditions...............................................................................................................................................37
10.3 CLK characteristics .............................................................................................................................................38
10.4 AC characteristics................................................................................................................................................39
10.4.1 Read transactions ............................................................................................................................................39
10.4.2 Write transactions............................................................................................................................................41
10.5 Timing reference levels.......................................................................................................................................42

Datasheet
3 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 4 -->

## 256 Mb HYPERRAM™ self-refresh DRAM (PSRAM) HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Table of contents

11 Packaging ..................................................................................................................................43
11.1 FBGA 49-ball 7 × 7 array footprint ......................................................................................................................43
11.2 Package diagram ................................................................................................................................................44
12 Ordering information ..................................................................................................................45
12.1 Ordering part number.........................................................................................................................................45
12.2 Valid combinations.............................................................................................................................................46
Revision history ..............................................................................................................................47

Datasheet
4 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 5 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

General description

## 1 General description

The 256 Mb HYPERRAM™ device is a high-speed CMOS, self-refresh DRAM, with HYPERBUS™ extended-IO. The
DRAM array uses dynamic cells that require periodic refresh. Refresh control logic within the device manages the
refresh operations on the DRAM array when the memory is not being actively read or written by the HYPERBUS™
extended-IO interface master (host). Since the host is not required to manage any refresh operations, the DRAM
array appears to the host as though the memory uses static cells that retain data without refresh. Hence, the
memory is more accurately described as pseudo static RAM (PSRAM).
Since the DRAM cells cannot be refreshed during a read or write transaction, there is a requirement that the host
limit read or write burst transfers lengths to allow internal logic refresh operations when they are needed. The
host must confine the duration of transactions and allow additional initial access latency, at the beginning of a
new transaction, if the memory indicates a refresh operation is needed.

## 1.1 HYPERBUS™ extended-IO interface

HYPERBUS™ extended-IO is a low signal count, DDR interface, that achieves high-speed read and write
throughput. The DDR protocol transfers two 32-bit data word per clock cycle on the DQ[15:0] input/output
signals. A read or write transaction on HYPERBUS™ extended-IO consists of a series of 16-bit wide, one clock cycle
data transfers at the internal HYPERRAM™ array with two corresponding 16-bit wide, one-half-clock-cycle data
transfers on the DQ signals. All inputs and outputs are LV-CMOS compatible. S80KS2564 or S80KS2564 devices
are available as 1.8 V VCC/(VCCQ (nominal) for array (VCC) and I/O buffer (VCCQ) supplies, through different ordering
part numbers (OPN).
Command, address, and data information is transferred over the 16 HYPERBUS™ extended-IO DQ[15:0] signals.
The clock (CK#, CK) is used for information capture by a HYPERBUS™ extended-IO slave device when receiving
command, address, or data on the DQ signals. Command or address values are center-aligned with clock transi-
tions.
Every transaction begins with the assertion of CS# and command-address (CA) signals, followed by the start of
clock transitions to transfer six CA bytes, followed by initial access latency and either read or write data transfers,
until CS# is deasserted.

| CS# CK# , CK RWDS[1:0] DQ[15:0] | tRWR=Read Write Recovery t = Access ACC Latency Count High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[15:0] and Memory drives RWDS[1:0] | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[15:0] and RWDS[1:0] |
|---|---|---|
| Figure 1 Read | transaction, single initial latency count |  |

Datasheet
5 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 6 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

General description

The RWDS is a bidirectional signal that indicates:

• when data will start to transfer from a HYPERRAM™ device to the master device in read transactions (initial read
latency)

• when data is being transferred from a HYPERRAM™ device to the master device during read transactions (as a
source synchronous read data strobe)

• when data may start to transfer from the master device to a HYPERRAM™ device in write transactions (initial
write latency)

• data masking during write data transfers

During the CA transfer portion of a read or write transaction, RWDS acts as an output from a HYPERRAM™ device
to indicate whether additional initial access latency is needed in the transaction.
During read data transfers, RWDS is a read data strobe with data values edge-aligned with the transitions of
RWDS.

| CS# C K # , C K RWDS[1:0] DQ[15:0] | tRWR=Read Write Recovery Additional Latency Latency Count 1 High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[15:0] and Memory drives RWDS[1:0] | tACC = Access Latency Count 2 | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[15:0] and RWDS[1:0] |
|---|---|---|---|
| Figure 2 Read During write data transfers, and prevented from memory). Data masking merging of multiple center-aligned with | transaction, additional latency count RWDS indicates whether each data word changing the data word in a memory) or not masked may be used by the host to 16-bit word align non-word aligned writes in a single burst write. clock transitions. | transfer is masked with RWDS LOW write data within During write transactions, | with RWDS HIGH (invalid (valid and written to a a memory or to enable data is |
| CS# C K # , C K RWDS[1:0] DQ[15:0] | tRWR =Read Write Recovery tACC = Access Latency Count High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[15:0] and Memory drives RWDS[1:0] | CK and are center Dn Dn A B Host drives and RWDS[1:0] | Data aligned Dn+1 Dn+1 A B DQ[15:0] |
| Figure 3 Write | transaction, single initial latency count |  |  |

Datasheet
6 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 7 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

General description

Read and write transactions are burst oriented, transferring the next sequential word during each clock cycle.
Each individual read or write transaction can use either a wrapped or linear burst sequence.

| 16 word group alignment boundaries Linear Burst 4h 5h 6h 7h 8h 9h Ah Bh Ch Dh Eh Fh 10h 11h 12h 13h Initial address = 4h Wrapped Burst 0h 1h 2h 3h 4h 5h 6h 7h 8h 9h Ah Bh Ch Dh Eh Fh |
|---|
| Figure 4 Linear versus wrapped burst sequence |

During wrapped transactions, accesses start at a selected location and continue to the end of a configured word
group aligned boundary, then wrap to the beginning location in the group, then continue back to the starting
location. Wrapped bursts are generally used for critical word first cache line fill read transactions. During linear
transactions, accesses start at a selected location and continue in a sequential manner until the transaction is
terminated when CS# returns HIGH. Linear transactions are generally used for large contiguous data transfers
such as graphic images. Since each transaction command selects the type of burst sequence for that transaction,
wrapped and linear bursts transactions can be dynamically intermixed as needed.

Datasheet
7 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 8 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Product overview

## 2 Product overview

The 256 Mb HYPERRAM™ device is 1.8 V array and I/O, synchronous self-refresh DRAM. The HYPERRAM™ device
provides a HYPERBUS™ extended-IO slave interface to the host system. The HYPERBUS™ extended-IO interface
has an 16-bit wide DDR data bus and use only 32-bit double word address boundaries. Read transactions provide
16 bits of data during each clock cycle (8 bits on both clock edges). Write transactions take 32 bits of data from
each clock cycle (16 bits on each clock edge).

| RESET# CS# CK CK# | VCC VCCQ DQ[15:0] RWDS[1:0] VSS VSSQ |
|---|---|
| interface[1] Figure 5 HYPERRAM™ |  |

## 2.1 HYPERBUS™ extended-IO interface

Read and write transactions require two clock cycles to define the target row address and burst type, then an
initial access latency of tACC. During the CA part of a transaction, the memory will indicate whether an additional
latency for a required refresh time (tRFH) is added to the initial latency; by driving the RWDS signal to the HIGH
state. During the CA period, the third clock cycle will specify the target word address within the target row. During
a read (or write) transaction, after the initial data value has been output (or input), additional data can be read
from (or written to) the row on subsequent clock cycles in either a wrapped or linear sequence. When configured
in Linear Burst mode, the device will automatically fetch the next sequential row from the memory array to
support a continuous linear burst. Simultaneously accessing the next row in the array while the read or write data
transfer is in progress, allows for a linear sequential burst operation that can provide a sustained data rate of
800 MBps [1 word (16 bit data bus) * 2 (data clock edges) * 200 MHz = 800 MBps].

Note

1. CK# is used in Differential Clock mode, but optional.

Datasheet
8 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 9 -->

Datasheet
9 of 48
002-31341 Rev. *C
2022-04-18
 
256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V
Signal description
3
Signal description
3.1
Input/output summary
HYPERRAM™ signals are shown in Table 1. Active Low signal names have a hash symbol (#) suffix.
Table 1
I/O summary
Symbol
Type
Description
CS#
Input
Chip Select. Bus transactions are initiated with a HIGH to LOW transition. Bus 
transactions are terminated with a LOW to HIGH transition. The master device 
has a separate CS# for each slave.
CK, CK#[2]
Differential Clock. Command, address, and data information is output with 
respect to the crossing of the CK and CK# signals. Use of differential clock is 
optional.
Single ended clock. CK# is not used, only a single ended CK is used. The clock is 
not required to be free-running.
DQ[15:0]
Input/output
Data Input/Output. DQ[7:0] to transmit command and address during 
command/address (CA) period and lower byte of 16-bit data word during read 
and write transactions. 
DQ[15:8] to transmit upper byte of 16-bit data word during read and write 
transactions. Host has to drive DQ[15:8] all to “H” or “L” during the CA period. 
Floating is not allowed.
RWDS[1:0]
Read-Write Data Strobe. During the command/address portion of all bus 
transactions RWDS is a slave output and indicates whether additional initial 
latency is required. 
Slave output during read data transfer, data is edge aligned with RWDS. 
Slave input during data transfer in write transactions to function as a data mask.
RWDS[0] corresponds to the data on DQ[7:0]
RWDS[1] corresponds to the data on DQ[15:8]
(High = Additional latency, Low = No additional latency).
RESET#
Input, internal 
pull-up
Hardware RESET. When LOW, the slave device will self initialize and return to 
the STANDBY state. RWDS[1:0] and DQ[15:0] are placed into the HIGH-Z state 
when RESET# is LOW. The slave RESET# input includes a weak pull-up, if RESET# 
is left unconnected it will be pulled up to the HIGH state.
VCC
Power supply
Array Power.
VCCQ
Input/Output Power.
VSS
Array Ground.
VSSQ
Input/Output Ground.
RFU
No connect
Reserved for Future Use. May or may not be connected internally, the 
signal/ball location should be left unconnected and unused by PCB routing 
channel for future compatibility. The signal/ball may be used by a signal in the 
future. 
Note
2. CK# is used in differential clock mode, but optional connection. Tie the CK# input pin to either VccQ or VssQ 
if not connected to the host controller, but do not leave it floating.

<!-- page 10 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

HYPERBUS™ extended-IO transaction details

## 4 HYPERBUS™ extended-IO transaction details

## 4.1 Command/address bit assignments

All HYPERRAM™ bus transactions can be classified as either read or write. A bus transaction is started with CS#
going LOW with clock in idle state (CK = LOW and CK# = HIGH). The first three clock cycles transfer three words of
command/address (CA0, CA1, CA2) information to define the transaction characteristics. The command/address
words are presented with DDR timing, using the first six clock edges.
The following characteristics are defined by the Command/Address information:

• Read or write transaction

• Address space: memory array space or register space
- Register space is used to access Device Identification (ID) registers and Configuration Registers (CR) that

identify the device characteristics and determine the slave specific behavior of read and write transfers on
the HYPERBUS™ extended-IO interface.

• Whether a transaction will use a linear or wrapped burst sequence.

• The target row (and half-page) address (upper order address)

• The target column (word within half-page) address (lower order address)

| CS# CK , CK# DQ[7:0] | CA0[47:40] | CA0[39:32] CA1[31:24] | CA1[23:16] | CA2[15:8] |  | CA2[7:0] |  |
|---|---|---|---|---|---|---|---|
| Figure 6 Command-address Table 2 CA bit assignment | (CA) to | sequence[3–7] DQ signals |  |  |  |  |  |
| Signal CA0[47:40] | CA0[39:32] | CA1[31:24] | CA1[23:16] | CA2[15:8] |  | CA2[7:0] |  |
| DQ[7] CA[47] |  | CA[39] | CA[31] | CA[23] | CA[15] |  | CA[7] |
| DQ[6] CA[46] |  | CA[38] | CA[30] | CA[22] | CA[14] |  | CA[6] |
| DQ[5] CA[45] |  | CA[37] | CA[29] | CA[21] | CA[13] |  | CA[5] |
| DQ[4] CA[44] |  | CA[36] | CA[28] | CA[20] | CA[12] |  | CA[4] |
| DQ[3] CA[43] |  | CA[35] | CA[27] | CA[19] | CA[11] |  | CA[3] |
| DQ[2] CA[42] |  | CA[34] | CA[26] | CA[18] | CA[10] |  | CA[2] |
| DQ[1] CA[41] |  | CA[33] | CA[25] | CA[17] |  | CA[9] | CA[1] |
| DQ[0] CA[40] |  | CA[32] | CA[24] | CA[16] |  | CA[8] | CA[0] |

Notes

3. Figure 6 shows the initial three clock cycles of all transactions on the HYPERBUS™ extended-IO.
4. CK# of differential clock is shown as dashed line waveform.
5. CA information is “center-aligned” with the clock during both read and write transactions.
6. Data bits in each byte are always in high to low order with bit 7 on DQ7 and bit 0 on DQ0.
7. DQ[15:8] should be Ignored during command/address phase but host has to drive them to “H” or “L”.

Datasheet
10 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 11 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

HYPERBUS™ extended-IO transaction details

Table 3
Command/address bit assignments[8–11]

| CA bit# | Bit name |  | Bit function |
|---|---|---|---|
| 47 | R/W# | Identifies the transaction as a read R/W# = 1 indicates a read transaction R/W# = 0 indicates a write transaction | or write. |
| 46 Address | space (AS) | Indicates whether the read or write space. AS = 0 indicates memory space AS = 1 indicates the register space The register space is used to access | transaction accesses the memory or register device ID and configuration registers. |
| 45 | Burst type | Indicates whether the burst will be Burst type = 0 indicates wrapped burst Burst type = 1 indicates linear burst | linear or wrapped. |
| Row 44–16 column | and upper address | Row & Upper Column component A31–A3 Any upper row address bits not used to ‘0’ by the host controller master address bit boundary between row dependent. | of the target address: System word address bits by a particular device density should be set interface. The size of rows and therefore the and column address is slave device |
| 15–3 | Reserved | Reserved for future column address Reserved bits are don’t care in current should be set to ‘0’ by the host controller | expansion. HYPERBUS™ extended-IO devices but master interface for future compatibility. |
| Lower 2–0 | column address | Lower column component of the target selecting the starting word within | address: System word address bits A2–A0 a half-page. |

Notes

8. A row is a group of words relevant to the internal memory array structure. The number of rows is also used
in the calculation of a distributed refresh interval for HYPERRAM™ memory.
9. The column address selects the burst transaction starting word location within a row. The column address
is split into an upper and lower portion. The upper portion selects an 8-word (32-byte) half-page and the
lower portion selects the 32-bit double word within a half-page where a read or write transaction burst starts.
10.The initial read access time starts when the row and upper column (half-page) address bits are captured by
a slave interface. Continuous linear read burst is enabled by memory devices internally interleaving access
to 32 byte half-pages.
11.HYPERBUS™ extended-IO protocol address space limit, assuming:
29 row and upper column address bits
3 lower column address bits
Each address selects a 32-bit wide data value
29 + 3 = 32 address bits = 4G addresses supporting 8 GB (64 Gb) maximum address space
Future expansion of the column address can allow for 29 row and upper column + 16 lower column address
bits = 35 Tera-word = 70 Tera-byte address space.

Datasheet
11 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 12 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

HYPERBUS™ extended-IO transaction details

| CK RWDS[1:0] DQ[15:0] | CS# , CK# | Dn A | Dn B | Dn+1 A | Dn+1 B | Dn+2 A |
|---|---|---|---|---|---|---|
| Figure 7 Data placement was written in (write). | Data placement during during memory read/write | a read transaction[12–16] is dependent | upon | the host. The | device will | output data (read) as it |
| CK RWDS[1:0] DQ[15:0] | CS# , CK# Dn | A Dn | B Dn+1 | A Dn+1 | B Dn+2 | A |
| Figure 8 | Data placement during | transaction[12–20] a write |  |  |  |  |

Notes

12.Figure 7 shows a portion of a read transaction on the HYPERBUS™ extended-IO. CK# of differential clock is
shown as dashed line waveform.
13.Data is “edge-aligned” with the RWDS serving as a read data strobe during read transactions.
14.Data is always transferred in full word increments (word granularity transfers).
15.Word address increments in each clock cycle. Byte A is between RWDS rising and falling edges and is followed
by byte B between RWDS falling and rising edges, of each word.
16.Data bits in each 16-bit are always in high to low order with bit 15 on DQ15 and bit 0 on DQ0.
17.Figure 8 shows a portion of a write transaction on the HYPERBUS™ extended-IO.
18.Data is “center-aligned” with the clock during a write transaction.
19.RWDS[1:0] functions as a data mask during write data transfers with initial latency.
- RWDS[0] as a input data mask for the data on DQ0–7.
- RWDS[1] as a input data mask for the data on DQ8–15.
20.RWDS is not driven by the master during write data transfers with zero initial latency. Full data words are
always written in this case. RWDS may be driven LOW or left HIGH-Z by the slave in this case.

Datasheet
12 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 13 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

HYPERBUS™ extended-IO transaction details

## 4.2 Read transactions (Memory array and registers)

The HYPERBUS™ extended-IO master begins a transaction by driving CS# LOW while clock is idle. The clock then
begins toggling while CA words are transferred.
In CA0, CA[47] = 1 indicates that a read transaction is to be performed. CA[46] = 0 indicates the memory space is
being read or CA[46] = 1 indicates the register space is being read. CA[45] indicates the burst type (wrapped or
linear). Read transactions can begin the internal array access as soon as the row and upper column address has
been presented in CA0 and CA1 (CA[47:16]). CA2 (CA(15:0]) identifies the target word address within the chosen
row.
The HYPERBUS™ extended-IO master then continues clocking for a number of cycles defined by the latency count
setting in configuration register 0. The initial latency count required for a particular clock frequency is based on
RWDS. If RWDS is LOW during the CA cycles, one latency count is inserted. If RWDS is HIGH during the CA cycles,
an additional latency count is inserted. Once these latency clocks have been completed the memory starts to
simultaneously transition the RWDS and output the target data.
New data is output edge-aligned with every transition of RWDS. Data will continue to be output as long as the
host continues to transition the clock while CS# is LOW. Note that burst transactions should not be so long as to
prevent the memory from doing distributed refreshes.
Wrapped bursts will continue to wrap within the burst length and linear burst will output data in a sequential
manner across row boundaries. When a linear burst read reaches the last address in the array, continuing the
burst beyond the last address will provide data from the beginning of the address range. Read transfers can be
ended at any time by bringing CS# HIGH when the clock is idle.
The clock is not required to be free-running. The clock may remain idle while CS# is HIGH.

| CS# Additional Latency tRWR= Read Write Recovery CK# , CK RWDS[1:0] High = 2x Latency Count Low = 1x Latency Count Latency Count 1 DQ[15:0] 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[15:0] and Memory drives RWDS[1:0] | tACC = Access Latency Count 2 | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[15:0] and RWDS[1:0] |
|---|---|---|
| latency[21–30] Figure 9 Read transaction with additional initial |  |  |

Notes

21.Transactions are initiated with CS# falling while CK = LOW and CK# = HIGH.
22.CS# must return HIGH before a new transaction is initiated.
23.CK# is the complement of the CK signal.CK# of a differential clock is shown as a dashed line waveform.
24.Read access array starts once CA[23:16] is captured.
25.The read latency is defined by the initial latency value in a configuration register.
26.In this read transaction example the initial latency count was set to four clocks.
27.In this read transaction a RWDS HIGH indication during CA delays output of target data by an additional four
clocks.
28.The memory device drives RWDS during read transactions.
29.For register read, the output data Dn A[7:0] is RG[15:8], Dn B[7:0] is RG[7:0], Dn+1 A[7:0] is RG[15:8], Dn+1
B[7:0] is RG[7:0].
30.DQ[15:8] is Ignored during Command/Address phase but host has to drive them to “H” or “L”.

Datasheet
13 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 14 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

HYPERBUS™ extended-IO transaction details

| CS# CK , CK# RWDS[1:0] DQ[15:0] | t =Read Write Recovery t = Initial Acces RWR ACC High = 2x Latency Count Low = 1x Latency Count 4 cycle latency 47:40 39:32 31:24 23:16 15:8 7:0 Command-Addres Host drives DQ[15:0] and Memory drives RWDS[1:0] | RWDS and Data are edge aligned Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[15:0] and RWDS[1:0] |
|---|---|---|
| Figure 10 Read transaction | latency[31-32] without additional initial |  |

## 4.3 Write transactions (memory array write)

The HYPERBUS™ extended-IO master begins a transaction by driving CS# LOW while clock is idle. Then the clock
begins toggling while CA words are transferred.
In CA0, CA[47] = 0 indicates that a write transaction is to be performed. CA[46] = 0 indicates the memory space is
being written. CA[45] indicates the burst type (wrapped or linear). Write transactions can begin the internal array
access as soon as the row and upper column address has been presented in CA0 and CA1 (CA[47:16]). CA2
(CA(15:0]) identifies the target word address within the chosen row.
The HYPERBUS™ extended-IO master then continues clocking for a number of cycles defined by the latency count
setting in Configuration Register 0. The initial latency count required for a particular clock frequency is based on
RWDS. If RWDS is LOW during the CA cycles, one latency count is inserted. If RWDS is HIGH during the CA cycles,
an additional latency count is inserted.
Once these latency clocks have been completed, the HYPERBUS™ extended-IO master starts to output the target
data. Write data is center-aligned with the clock edges. The first 16-bit data is captured by the memory on the
rising edge of CK and the second 16-bit data is captured on the falling edge of CK.
During the CA clock cycles, RWDS is driven by the memory.
During the write data transfers, RWDS is driven by the host master interface as a data mask. When data is being
written and RWDS is HIGH, the 16-bit will be masked and the array will not be altered. When data is being written
and RWDS is LOW, the data will be placed into the array. Because the master is driving RWDS during write data
transfers, neither the master nor the HYPERRAM™ device are able to indicate a need for latency within the data
transfer portion of a write transaction. The acceptable write data burst length setting is also shown in
Configuration Register 0.
Data will continue to be transferred as long as the HYPERBUS™ extended-IO master continues to transition the
clock while CS# is LOW. Note that burst transactions should not be so long as to prevent the memory from doing
distributed refreshes. Legacy format wrapped bursts will continue to wrap within the burst length. Hybrid wrap
will wrap once then switch to linear burst starting at the next wrap boundary. Linear burst accepts data in a
sequential manner across page boundaries. Write transfers can be ended at any time by bringing CS# HIGH when
the clock is idle.
When a linear burst write reaches the last address in the memory array space, continuing the burst will write to
the beginning of the address range.
The clock is not required to be free-running. The clock may remain idle while CS# is HIGH.

Notes

31.RWDS is LOW during the CA cycles. In this Read Transaction, there is a single initial latency count for read data
access because, this read transaction does not begin at a time when additional latency is required by the
slave.
32.DQ[15:8] should be Ignored during Command/Address phase but host has to drive them to “H” or “L”.

Datasheet
14 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 15 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

HYPERBUS™ extended-IO transaction details

| CS# Additional Latency tRWR = Read Write Recovery tACC = Initial Access CK , CK# RWDS[1:0] High = 2x Latency Count Low = 1x Latency Count Latency Count 1 Latency Count 2 DQ[15:0] 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[15:0] and Memory drives RWDS[1:0] | CK and Data are center aligned Dn Dn Dn+1 Dn+1 A B A B Host drives DQ[15:0] and RWDS[1:0] |
|---|---|
| latency[33–36] Figure 11 Write transaction with additional initial |  |
| CS# tRWR=Read Write Recovery tACC = Access CK# , CK High = 2x Latency Count Low = 1x Latency Count RWDS[1:0] CK Latency Count are 47:40 39:32 31:24 23:16 15:8 7:0 Dn DQ[15:0] A Command-Address Host and RWDS[1:0] Host drives DQ[15:0] and Memory drives RWDS[1:0] | and Data center aligned Dn Dn+1 Dn+1 B A B drives DQ[15:0] |
| latency[37–40] Figure 12 Write transaction without additional initial |  |

Notes

33.Transactions must be initiated with CK = LOW and CK# = HIGH.
34.CS# must return HIGH before a new transaction is initiated.
35.During CA, RWDS is driven by the memory and indicates whether additional latency cycles are required.
36.In this example, RWDS indicates that additional initial latency cycles are required.
37.At the end of CA cycles the memory stops driving RWDS to allow the host HYPERBUS™ extended-IO master
to begin driving RWDS. The master must drive RWDS to a valid LOW before the end of the initial latency to
provide a data mask preamble period to the slave.
38.During data transfer, RWDS is driven by the host to indicate which 16-bit data should be either masked or
loaded into the array.
39.The figure shows RWDS masking 16-bit word Dn A and 16-bit Dn+1 B.
40.DQ[15:8] should be Ignored during command/address phase but host has to drive them to “H” or “L”.

Datasheet
15 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 16 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

HYPERBUS™ extended-IO transaction details

## 4.4 Write transactions without initial latency (register write)

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
use RWDS as a data mask function.
The first 16-bit data is presented on the rising edge of CK and the second 16-bit is presented on the falling edge
of CK. DQ[7:0] transmits RG[15:8] on the rising edge of the CK while DQ[7:0] transmits RG[7:0] on the falling edge
of the CK. DQ[15:8] should be ignored during CA cycle but host has to drive them to either “H” or “L”. Write data
is center-aligned with the clock inputs. Write transfers can be ended at any time by bringing CS# HIGH when clock
is idle. The clock is not required to be free-running.

| CS# CK#, CK RWDS DQ[7:0] | High: 2X Latency Low: 1X Latency CA CA [47:40] [39:32] (Host drives | Count* Count* CA CA CA CA [31:24] [23:16] [15:8] [7:0] Command - Address DQ[7:0], Memory drives RWDS) | RG RG [15:8] [7:0] Write Data |
|---|---|---|---|
| operations[41–42] Figure 13 Register write |  |  |  |

Notes

41.Latency is not applicable during the Register Write. The RWDS driven LOW or HIGH after the CS# LOW should
be ignored by the host. The register write data byte immediately follows the last CA byte (zero clock latency).
42.RWDS is not driven by the host during register write. The HYPERRAM™ ignores the RWDS status and always
writes full data. RWDS may be driven Low or left High-Z by the slave during write data transfer.

Datasheet
16 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 17 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Memory space

## 5 Memory space

## 5.1 HYPERBUS™ extended-IO interface

Table 4
Memory space address map (double word based - 32 bits)

| Unit type | Count | System address | word bits | CA | bits |  | Notes |
|---|---|---|---|---|---|---|---|
| Rows within 256 Mb 32768 device | (Rows) |  | A22–A8 |  | 35–21 | – |  |
| Row (Half-pages) | 32 |  | A7–A3 |  | 20–16 | Each row has 32 Half-pages. eight 32-bit words. Therefore, 256 double words (32-bit) | Each Half-page has each row has or 1 KB. |
| Half-page double | 8 (32-bit, word) |  | A2–A0 |  | 2–0 | Half-Page (HP) address upper column address. Half-Page address is column address. | is also referenced as A word within a also referred to as lower |

Datasheet
17 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 18 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Register space

## 6 Register space

## 6.1 HYPERBUS™ extended-IO interface

When CA[46] is ‘1’, a read or write transaction accesses the register space.

Table 5
Register space address map

| Register |  |  | System address CA bits |  | — 47 | — 46 | — 45[43] | 31–27 44–40 | 26–19 39–32 | 18–11 31–24 | 23–16 | 10–3 | — 15–8 | 2–0 7–0 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Identification Register | 0 |  |  |  |  | C0h or | E0h |  |  | 00h | 00h | 00h | 00h | 00h |
| Identification Register | 1 |  |  |  |  | C0h or | E0h |  |  | 00h | 00h | 00h | 00h | 01h |
| Configuration | Register 0 | Read |  |  |  | C0h or | E0h |  |  | 00h | 01h | 00h | 00h | 00h |
| Configuration | Register 0 | Write |  |  |  | 60h |  |  |  | 00h | 01h | 00h | 00h | 00h |
| Configuration | Register 1 | Read |  |  |  | C0h or | E0h |  |  | 00h | 01h | 00h | 00h | 01h |
| Configuration | Register 1 | Write |  |  |  | 60h |  |  |  | 00h | 01h | 00h | 00h | 01h |
| 6.2 There are two read is LOW. The device information • Manufacturer • Type • Density • Row address • Column address Table 6 | Device only, fields bit count bit count Identification | Identification non-volatile identify: Register | registers word registers, 0 (ID0) |  | that bit assignments | provide | information |  |  | on the | device | selected | when | CS# |
| Bits |  | Function |  |  |  |  |  |  | Settings | (binary) |  |  |  |  |
| [15:14] | MCP | die address |  | 00 | - Default |  |  |  |  |  |  |  |  |  |
| [13] |  | Reserved |  | 0 | - Default |  |  |  |  |  |  |  |  |  |
| [12:8] | Row address | bit | count | 01110b |  | - 256 Mb; | fifteen |  | row address | bits | (256 | Mb) |  |  |
| [7:4] | Column | address | bit count | 0111b | - | Eight column |  | address |  | bits (default) |  |  |  |  |
| [3:0] | Manufacturer |  |  | 0110b |  |  |  |  |  |  |  |  |  |  |
| Table 7 | Identification | Register | 1 (ID1) |  | bit assignments |  |  |  |  |  |  |  |  |  |
| Bits |  | Function |  |  |  |  |  |  | Settings | (binary) |  |  |  |  |
| [15:4] |  | Reserved |  | 0000_0000_0000b |  |  | (default) |  |  |  |  |  |  |  |
| [3:0] | Device | type |  | 1001 | - HYPERRAM™ |  | extended-IO |  |  |  |  |  |  |  |

Notes

43.CA45 may be either 0 or 1 for either wrapped or linear read. CA45 must be 1 as only linear single word register
writes are supported.
44.The burst type (wrapped/linear) definition is not supported in register reads. Hence C0h/E0h have the same
effect.

Datasheet
18 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 19 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Register space

## 6.2.1 Density and row boundaries

The DRAM array size (density) of the device can be determined from the total number of system address bits used
for the row and column addresses as indicated by the row address bit count and column address bit count fields
in the ID0 register. For example: a 256 Mb HYPERRAM™ device has 8 column address bits and 15 row address bits
for a total of 23 word address bits = 223 = 8M  32-bit or 256 Mb. The 8 column address bits indicate that each row
holds 28 = 256  32-bit or 8192 bits. The row address bit count indicates there are 32,784 rows to be refreshed
within each array refresh interval. The row count is used in calculating the refresh interval.
ID0 value for the 256 Mb HYPERRAM™ is 0xE76.
6.3
Register space access

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
latency counts, based on the state of RWDS during the CA period. The latency count is defined in the
Configuration Register 0 read latency field (CR0[7:4]).

## 6.3.1 Configuration register 0

Configuration Register 0 (CR0) is used to define the power state and access protocol operating conditions for the
HYPERRAM™ device. Configurable characteristics include:

• Wrapped burst length (16, 32, 64 or 128 16-bit word aligned and length data group)

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

Datasheet
19 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 20 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Register space

Table 8
Configuration Register 0 (CR0) bit assignments

| CR0 bit |  | Function |  | Settings (binary) |
|---|---|---|---|---|
| [15] | Deep down | power enable | 1 - Normal operation (default). ‘1’ after DPD exit 0 - Writing 0 causes the device | HYPERRAM™ will automatically set this value to to enter deep power down |
| [14:12] | Drive | strength | 000 - 34 (default) 001 - 115  010 - 67  011 - 46  100 - 34  101 - 27  110 - 22  111 - 19  |  |
| [11:8] |  | Reserved | 1 - Reserved (default) Reserved for future use. When ‘1’ for future compatibility. | writing this register, these bits should be set to |
| [7:4] | Initial | latency | 0000 - 5 clock latency @ 133 MHz 0001 - 6 clock latency @ 166 MHz 0010 - 7 clock latency @ 200 MHz 0011 - Reserved 0100 - Reserved ... 1101 - Reserved 1110 - 3 clock latency @ 85 MHz 1111 - 4 clock latency @ 104 MHz | Max frequency Max frequency Max frequency (default) Max frequency Max frequency |
| [3] | Fixed | latency enable | 0 - Variable latency - 1 or 2 times cycles. 1 - Fixed 2 times initial latency | initial latency depending on RWDS during CA (default) |
| [2] | Hybrid | burst enable | 0: Wrapped burst sequence to 1: Wrapped burst sequence in This bit setting is effective only command/address register is set | follow hybrid burst sequencing legacy wrapped burst manner (default) when the “Burst Type” bit in the to ‘0’, i.e. CA[45] = 0; otherwise, it is ignored. |
| [1:0] | Burst | length | 00 - 128 words 01 - 64 words 10- 16 words 11 - 32 words (default) |  |
| Wrapped burst |  |  |  |  |

Wrapped burst
A wrapped burst transaction accesses memory within a group of words aligned on a word boundary matching
the length of the configured group. Wrapped access groups can be configured as 16, 32, 64, or 128 16-bit word
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

Datasheet
20 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 21 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Register space

Table 9
CR0[2] control of wrapped burst sequence

| Bit | Default | value |  | Name |
|---|---|---|---|---|
| 2 |  | Hybrid 1 CR0[2] CR0[2] | burst enable = 0: Wrapped burst sequence = 1: Wrapped burst sequence | to follow hybrid burst sequencing in legacy wrapped burst manner |
| Table 10 | Example | wrapped | burst sequences (HYPERBUS™ extended-IO | addressing) |
| Burst type | Wrap boundary (16-bit) |  | Start address Sequence of word (Hex) | addresses (Hex) of data words |
| Hybrid 128 | 128 wrap then | once linear | 03, 04, 05, 06, 07, 08, 09, 16, 17, 18, 19, 1A, 1B, 1C, 29, 2A, 2B, 2C, 2D, 2E, 2F, XXXXXX03 3C, 3D, 3E, 3F, 00, 01, 02 (wrap complete, now linear group) 40, 41, 42, 43, 44, 45, 46, | 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 1D, 1E, 1F, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, beyond the end of the initial 128 wrap 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| Hybrid 64 | 64 wrap then | once linear | 03, 04, 05, 06, 07, 08, 09, 16, 17, 18, 19, 1A, 1B, 1C, XXXXXX03 (wrap complete, now group) 20, 21, 22, 23, 24, 25, 26, | 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 1D, 1E, 1F, 00, 01, 02 linear beyond the end of the initial 64 wrap 27, 28, 29, 2A, 2B, 2C, 2D, 2E, 2F, 30, 31, ... |
| Hybrid 64 | 64 wrap then | once linear | 2E, 2F, 30, 31, 32, 33, 34, 21, 22, 23, 24, 25, 26, 27, XXXXXX2E (wrap complete, now group) 40, 41, 42, 43, 44, 45, 46, | 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 28, 29, 2A, 2B, 2C, 2D linear beyond the end of the initial 64 wrap 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| Hybrid 16 | 16 wrap then | once linear | 02, 03, 04, 05, 06, 07, 00, (wrap complete, now XXXXXX02 group) 08, 09, 0A, 0B, 0C, 0D, | 01 linear beyond the end of the initial 16 wrap 0E, 0F, 10, 11, 12, ... |
| Hybrid 16 | 16 wrap then | once linear | 0C, 0D, 0E, 0F, 08, 09, 0A, (wrap complete, now XXXXXX0C group) 10, 11, 12, 13, 14, 15, 16, | 0B linear beyond the end of the initial 16 wrap 17, 18, 19, 1A, ... |
| Hybrid 32 | 32 wrap then | once linear | 0A, 0B, 0C, 0D, 0E, 0F, 00, (wrap complete, now XXXXXX0A group) 10, 11, 12, 13, 14, 15, 16, | 01, 02, 03, 04, 05, 06, 07, 08, 09 linear beyond the end of the initial 32 wrap 17, 18, 19, 1A, ... |
| Wrap 64 |  | 64 | 03, 04, 05, 06, 07, 08, 09, XXXXXX03 16, 17, 18, 19, 1A, 1B, 1C, | 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 1D, 1E, 1F, 00, 01, 02, ... |
| Wrap 64 |  | 64 | 2E, 2F, 30, 31, 32, 33, 34, XXXXXX2E 21, 22, 23, 24, 25, 26, 27, | 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 28, 29, 2A, 2B, 2C, 2D, ... |
| Wrap 16 |  | 16 | XXXXXX02 02, 03, 04, 05, 06, 07, 00, | 01, ... |
| Wrap 16 |  | 16 | XXXXXX0C 0C, 0D, 0E, 0F, 08, 09, 0A, | 0B, ... |

Wrap 32
32
XXXXXX0A
0A, 0B, 0C, 0D, 0E, 0F, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, ...

Linear
Linear burst
XXXXXX03
03, 04, 05, 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15,
16, 17, 18, ...

Datasheet
21 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 22 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Register space

Initial latency
Memory space read and write transactions or register space read transactions require some initial latency to
open the row selected by the CA. This initial latency is tACC. The number of latency clocks needed to satisfy tACC
depends on the HYPERBUS™ extended-IO frequency can vary from 3 to 7 clocks. The value in CR0[7:4] selects the
number of clocks for initial latency. The default value is 7 clocks, allowing for operation up to a maximum
frequency of 200 MHz prior to the host system setting a lower initial latency value that may be more optimal for
the system.
In the event a distributed refresh is required at the time a memory space read or write transaction or register
space read transaction begins, the RWDS signal goes HIGH during the CA to indicate that an additional initial
latency is being inserted to allow a refresh operation to complete before opening the selected row.
Register space write transactions always have zero initial latency. RWDS may be HIGH or LOW during the CA
period. The level of RWDS during the CA period does not affect the placement of register data immediately after
the CA, as there is no initial latency needed to capture the register data. A refresh operation may be performed
in the memory array in parallel with the capture of register data.
Fixed latency
A Configuration Register Option bit CR0[3] is provided to make all memory space read and write transactions or
register space read transactions require the same initial latency by always driving RWDS HIGH during the CA to
indicate that two initial latency periods are required. This fixed initial latency is independent of any need for a
distributed refresh, it simply provides a fixed (deterministic) initial latency for all of these transaction types. The
fixed latency option may simplify the design of some HYPERBUS™ extended-IO memory controllers or ensure
deterministic transaction performance. Fixed latency is the default POR or reset configuration. The system may
clear this configuration bit to disable fixed latency and allow variable initial latency with RWDS driven HIGH only
when additional latency for a refresh is required.
Drive strength
DQ and RWDS signal line loading, length, and impedance vary depending on each system design. Configuration
Register bits CR0[14:12] provide a means to adjust the DQ[15:0] and RWDS[1:0] signal output impedance to
customize the DQ and RWDS signal impedance to the system conditions to minimize high speed signal behaviors
such as overshoot, undershoot, and ringing. The default POR or reset configuration value is 000b to select the
mid point of the available output impedance options.
The impedance values shown are typical for both pull-up and pull-down drivers at typical silicon process condi-
tions, nominal operating voltage (1.8 V) and 50°C. The impedance values may vary from the typical values
depending on the process, voltage, and temperature (PVT) conditions. Impedance will increase with slower
process, lower voltage, or higher temperature. Impedance will decrease with faster process, higher voltage, or
lower temperature.
Each system design should evaluate the data signal integrity across the operating voltage and temperature
ranges to select the best drive strength settings for the operating conditions.
Deep power down
When the HYPERRAM™ device is not needed for system operation, it may be placed in a very low power consuming
state called deep power down (DPD), by writing ‘0’ to CR0[15]. When CR0[15] is cleared to ‘0’, the device enters
the DPD state within tDPDIN time and all refresh operations stop. The data in RAM is lost, (becomes invalid without
refresh) during DPD state. Exiting DPD requires driving CS# LOW then HIGH, POR, or a reset. Only CS# and RESET#
signals are monitored during DPD mode. For additional details, see “Deep power down” on page 28.

Datasheet
22 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 23 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Register space

## 6.3.2 Configuration Register 1

Configuration Register 1 (CR1) is used to define the refresh array size, refresh rate and hybrid sleep for the
HYPERRAM™ device. Configurable characteristics include:

• Partial array refresh

• Hybrid sleep state

• Refresh rate

Table 11
Configuration Register 1 (CR1) bit assignments

| CR1 bit | Function | Setting (binary) |
|---|---|---|
| [15:7] | 111111111 - Reserved (default) When writing this register, these Reserved compatibility. | bits should keep 111111111 for future |
| [6] Master | 1 - Single-ended - CK (default) clock type 0 - Differential - CK#, CK |  |
| [5] Hybrid | 1 - Causes the device to enter sleep 0 - Normal operation (default) | hybrid sleep state |
| [4:2] Partial | 000 - Full array (default) 001 - Bottom 1/2 array 010 - Bottom 1/4 array 011 - Bottom 1/8 array array refresh 100 - None 101 - Top 1/2 array 110 - Top 1/4 array 111 - Top 1/8 array |  |
| Distributed [1:0] interval | 10 - 1 μs tCSM (Industrial Plus refresh 11 - Reserved (read only) 00 - Reserved 01 - 4 μs tCSM (Industrial temperature | temperature range devices) range devices) |
| Master clock type |  |  |

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
will cause the device to exit HS state and reset CR1[5] to ‘0’. Also, POR or a hardware reset will cause the device
to exit hybrid sleep state. Note that a POR or a hardware reset disables refresh where the memory core data can
potentially get lost.

Datasheet
23 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 24 -->

Datasheet
24 of 48
002-31341 Rev. *C
2022-04-18
 
256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V
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
distributed refresh interval varies with temperature as shown in Table 12.
The distributed refresh operation requires that the host does not perform burst transactions longer than the 
distributed refresh interval to prevent the memory from unable doing the distributed refreshes operation when 
it is needed. This sets an upper limit on the length of read and write transactions so that the automatic distributed 
refresh operation can be done between transactions. This limit is called the CS# LOW maximum time (tCSM) and 
the tCSM will be equal to the maximum distributed refresh interval. The host system is required to respect the tCSM 
value by terminating each transaction before violating tCSM. This can be done by host memory controller splitting 
long transactions when reaching the tCSM limit, or by host system hardware or software not performing a single 
burst read or write transaction that would be longer than tCSM. 
As noted in Table 12, the maximum refresh interval is longer at lower temperatures such that tCSM could be 
increased to allow longer transactions. The host may determine the operating temperature from a temperature 
sensor in the system and use the tCSM value from the table accordingly, or it may determine dynamically by 
reading the read only CR1[1:0] bits in order to set the distributed refresh interval prior to the HYPERRAM™ access.
Table 12
Array refresh interval per temperature
Operating temperature
Refresh interval tCSM
CR1[1:0]
TA 85°C
4 µs
01b
85°C < TA  105°C
1 µs
10b

<!-- page 25 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Interface states

## 7 Interface states

Table 13 describes the required value of each signal for each interface state.

Table 13
Interface states

| Interface state | VCC / VCCQ | CS# | CK, CK# | DQ[15:0] | RWDS[1:0] | RESET# |
|---|---|---|---|---|---|---|
| Power-off Power-on (cold) reset Hardware (warm) reset | VLKO < | X | X | HIGH-Z | HIGH-Z | X L |

| Hardware (warm) reset |
|---|
| Interface standby |
| CA |
| Read initial access latency (data bus turn around period) |
| Write initial access latency (RWDS turn around period) |
| Read data transfer |
| Write data transfer with Initial latency |
| Write data transfer without latency[45] Initial |
| Active clock stop[46] |
| Deep power down |
| Hybrid sleep |

T
Master output

valid
Y

| T T | HIGH-Z | L HIGH-Z |
|---|---|---|
| Slave T | output Slave valid valid | output Z or T |
| T Master T | Master valid output valid Slave L | output X or T output or HIGH-Z |

###  VCC / VCCQ min

L

H

Master or slave
output valid or

Y

HIGH-Z

Legend
L = VIL
H = VIH
X = Either VIL or VIH
Y= Either VIL or VIH or VOL or VOH
Z = Either VOL or VOH
L/H = Rising edge
H/L = Falling edge
T = Toggling during information transfer
Idle = CK is LOW and CK# is HIGH.
Valid = All bus signals have stable L or H level

Notes

45.Writes without initial latency (with zero initial latency), do not have a turn around period for RWDS[1:0]. The
HYPERRAM™ device will always drive RWDS[1:0] during the CA period to indicate whether extended latency
is required. Since master write data immediately follows the CA period the HYPERRAM™ device may continue
to drive RWDS[1:0] LOW or may take RWDS[1:0] to HIGH-Z. The master must not drive RWDS[1:0] during Writes
with zero latency. Writes with zero latency do not use RWDS[1:0] as a data mask function. All write data are
written.
46.Active Clock Stop is described in “Active clock stop” on page 26. DPD is described in “Deep power down”
on page 28.

Datasheet
25 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 26 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Power conservation modes

## 8 Power conservation modes

## 8.1 Interface standby

STANDBY is the default, low power, state for the interface while the device is not selected by the host for data
transfer (CS# = HIGH). All inputs, and outputs other than CS# and RESET# are ignored in this state.

## 8.2 Active clock stop

The active clock stop state reduces device interface energy consumption to the ICC6 level during the data transfer
portion of a read or write operation. The device automatically enables this state when clock remains stable for
tACC + 30 ns. While in active clock stop state, read data is latched and always driven onto the data bus. ICC6 shown
in “DC characteristics” on page 31.
Active clock stop state helps reduce current consumption when the host system clock has stopped to pause the
data transfer. Even though CS# may be LOW throughout these extended data transfer cycles, the memory device
host interface will go into the active clock stop current level at tACC + 30 ns. This allows the device to transition
into a lower current state if the data transfer is stalled. Active read or write current will resume once the data
transfer is restarted with a toggling clock. The active clock stop state must not be used in violation of the tCSM
limit. CS# must go HIGH before tCSM is violated. Clock can be stopped during any portion of the active transaction
as long as it is in the LOW state. Note that it is recommended to avoid stopping the clock during register access.

| CS# CK#, CK RWDS[1:0] DQ[15:0] | High: 2X Latency Count Low: 1X Latency Count CMD CMD ADR ADR ADR ADR [7:0] [7:0] [31:24] [23:16] [15:8] [7:0] Command - Address (Hoﬆ drives DQ[15:0] and Memory drives RWDS[1:0]) | Latency Count (1X) | Clock Stopped RWDS & Data are edge aligned DoutA DoutB [15:0] [15:0] Output Driven Read Data | DoutA+1 DoutB+1 [15:0] [15:0] |
|---|---|---|---|---|
| Figure 14 Active | clock stop during read transaction | (DDR)[47, 48] |  |  |

Notes

47.DQ[15:8] should be ignored during command/address phase but host has to drive them to “H” or “L”.
48.RWDS is LOW during the CA cycles. In this read transaction, there is a single initial latency count for read data
access because, this read transaction does not begin at a time when additional latency is required by the
slave.

Datasheet
26 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 27 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Power conservation modes

## 8.3 Hybrid sleep

In the hybrid sleep (HS) state, the current consumption is reduced (iHS). HS state is entered by writing a ‘1’ to
CR1[5]. The device reduces power within tHSIN time. The data in memory space and register space is retained
during HS state. Bringing CS# LOW will cause the device to exit HS state and reset CR1[5] to ‘0’. Also, POR or a
hardware reset will cause the device to exit hybrid sleep state. Note that a POR or a hardware reset disables
refresh where the memory core data can potentially get lost. Returning to STANDBY state requires tEXITHS time.
Following the exit from HS due to any of these events, the device is in the same state as entering hybrid sleep.

| CS# C K#, C RW DS DQ [7:0] | K | High: 2X Latency Count Low: 1X Latency C ount CM D CM D ADR ADR ADR ADR [7:0] [7:0] [31:24] [23:16] [15:8] [7:0] Com m and - Address (Host drives DQ[7:0], M em ory drives R W DS) | RG RG [15:8] [7:0] W rite Data C R0 Value | tH SIN Enter H ybrid Sleep tH SIN |  |  | HS |  |
|---|---|---|---|---|---|---|---|---|
| Figure 15 | Enter HS transaction |  |  |  |  |  |  |  |
|  | CS# | tCSHS tEXTHS |  |  |  |  |  |  |
| Figure 16 Table 14 | Exit HS transaction Hybrid sleep | timing parameters |  |  |  |  |  |  |
| Parameter |  | Description |  | Min |  | Max | Unit |  |
| tHSIN | Hybrid sleep CR1[5] | = 0 register write to DPD power | level |  | – |  | 3 | µs |
| tCSHS | CS# pulse width | to exit HS |  |  | 60 | 3000 |  | ns |
| tEXTHS | CS# exit hybrid | sleep to standby wakeup time |  |  | – | 100 |  | µs |

Datasheet
27 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 28 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Power conservation modes

## 8.4 Deep power down

In the deep power down (DPD) state, current consumption is driven to the lowest possible level (IDPD). DPD state
is entered by writing a ‘0’ to CR0[15]. The device reduces power within tDPDIN time and all refresh operations stop.
The data in memory space is lost, (becomes invalid without refresh) during DPD state. Driving CS# LOW then HIGH
will cause the device to exit DPD state. Also, POR or a hardware reset will cause the device to exit DPD state.
Returning to STANDBY state requires tEXTDPD time. Returning to STANDBY state following a POR requires tVCS
time, as with any other POR. Following the exit from DPD due to any of these events, the device is in the same
state as following POR.

| CS# CK#, CK RW DS DQ[7:0] |  | High: 2X Latency Count Low: 1X Latency Count CM D CM D ADR ADR ADR ADR [7:0] [7:0] [31:24] [23:16] [15:8] [7:0] Comm and - Address (Host drives DQ[7:0], Memory drives RW DS) | RG RG [15:8] [7:0] W rite Data CR0 Value | tDPDIN Enter Deep Power tDPDIN |  | Down |  | DPD |  |
|---|---|---|---|---|---|---|---|---|---|
| Figure 17 | transaction[49] Enter DPD |  |  |  |  |  |  |  |  |
|  | CS# | tCSDPD tEXTDPD |  |  |  |  |  |  |  |
| Figure 18 Table 15 | Exit DPD transaction Deep power down | timing parameters |  |  |  |  |  |  |  |
| Parameter |  | Description |  |  | Min |  | Max | Unit |  |
| tDPDIN | Deep power down | CR0[15] = 0 register write to | DPD power level |  |  | – |  | 3 | µs |
| tCSDPD | CS# pulse width | to exit DPD |  |  | 200 |  | 3000 |  | ns |
| tEXTDPD | CS# exit deep power | down to standby wakeup | time |  |  | – | 150 |  | µs |

Note

49.DQ[15:8] should be ignored during command/address phase but host has to drive them to “H” or “L”.

Datasheet
28 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 29 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Electrical specifications

## 9 Electrical specifications

## 9.1 Absolute maximum ratings[50]

|  | Parameter | Description |
|---|---|---|
| Storage temperature plastic | packages -65°C to +150°C |  |
| Ambient temperature with | power applied -65°C to +135°C |  |
| Voltage with respect to ground All signals[51] | -0.5 V to +(VCC + 0.5 | V) |
| Output short circuit | 100 mA |  |
| Voltage on VCC, VCCQ pins | relative to VSS -0.5 V to +2.5 V |  |
| Electrostatic discharge voltage: Human body model (JEDEC | Std JESD22-A114-B) 2000 V |  |
| Charged device model (JEDEC | Std JESD22-C101-A) 500 V |  |
| 9.2 Input signal During DC conditions, input transitions, inputs or I/Os up to 20 ns. | overshoot or I/O signals should remain equal to or between VSS may negative overshoot VSS to –1.0 V or positive overshoot | and VCC. During voltage to VCC + 1.0 V, for periods |
|  | VSSQ to VCCQ - 1.0V ≤ 20 ns |  |
| Figure 19 Maximum | negative overshoot waveform |  |
|  | ≤ 20 ns VCCQ + 1.0V VSSQ to VCCQ |  |
| Figure 20 Maximum | positive overshoot waveform |  |

Notes

50.Stresses above those listed under “Absolute maximum ratings[50]” on page 29 may cause permanent
damage to the device. This is a stress rating only; functional operation of the device at these or any other
conditions above those indicated in the operational sections of this data sheet is not implied. Exposure of
the device to absolute maximum rating conditions for extended periods may affect device reliability.
51.Minimum DC voltage on input or I/O signal is –1.0 V. During voltage transitions, input or I/O signals may
undershoot VSS to –1.0 V for periods of up to 20 ns. See Figure 19. Maximum DC voltage on input or I/O signals
is VCC +1.0 V. During voltage transitions, input or I/O signals may overshoot to VCC + 1.0 V for periods up to
20 ns. See Figure 20.
52.No more than one output may be shorted to ground at a time. Duration of the short circuit should not be
greater than one second.

Datasheet
29 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 30 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Electrical specifications

## 9.3 Latch-up characteristics

## 9.3.1 Latch-up specification

Table 16
Latch-up specification[53]

|  | Description | Min | Max |  | Unit |  |
|---|---|---|---|---|---|---|
| Input voltage with respect to Input voltage with respect to | VSSQ on all input only connections VSSQ on all I/O connections | –1.0 VCCQ |  | + 1.0 |  | V |
| VCCQ current |  | –100 | +100 |  | mA |  |
| 9.4 Operating Operating ranges define those 9.4.1 Temperature Table 17 Temperature | ranges limits between which the functionality of the ranges ranges | device is guaranteed. |  |  |  |  |
| Parameter Symbol | Device | Spec Min |  | Max | Unit |  |
| Ambient temperature TA | Industrial (I) Industrial Plus (V) | –40 |  | 85 105 | °C |  |
| 9.4.2 Power supply Table 18 Power supply | voltages voltages |  |  |  |  |  |
|  | Description | Min | Max |  | Unit |  |
| 1.8 V VCC power supply |  | 1.7 | 2.0 |  |  | V |

Note

53.Excludes power supplies VCC/VCCQ. Test conditions: VCC = VCCQ, one connection at a time tested, connec-
tions not being tested are at VSS.

Datasheet
30 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 31 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Electrical specifications

## 9.5 DC characteristics

Table 19
DC characteristics (CMOS compatible)

| Parameter | Description | Test Conditions | Min | Value Typ[54] | Max | Unit |
|---|---|---|---|---|---|---|
| Input leakage ILI2 device reset Input leakage ILI4 device reset | current VIN = signal HIGH VCC = current VIN = LOW[55] signal VCC = | VSS to VCC, VCC max VSS to VCC, VCC max |  | – | 2 15 | µA |

| ILI4 | Input leakage current LOW[55] device reset signal | VIN = VSS to VCC, VCC = VCC max |
|---|---|---|
| ICC1 | VCC active read current operating temperature range | CS# = VSS, CK@200 MHz, VCC = VCC max |
| ICC2 | VCC active write current operating temperature range | CS# = VSS, CK@200 MHz, VCC = VCC max |

mA

| 16 470 | 22 1200 |
|---|---|
| – | 850 700 600 850 700 600 |
| 470 | 1550 |

| CS# = VCC, VCC = VCC max; bottom 1/2 array |
|---|
| CS# = VCC, VCC = VCC max; bottom 1/4 array |
| CS# = VCC, VCC = VCC max; bottom 1/8 array |
| CS# = VCC, VCC = VCC max; top 1/2 array |
| CS# = VCC, VCC = VCC max; top 1/4 array |
| CS# = VCC, VCC = VCC max; top 1/8 array CS# = VCC, VCC = VCC max; full array |
| CS# = VCC, VCC = VCC max; bottom 1/2 array |
| CS# = VCC, VCC = VCC max; bottom 1/4 array |
| CS# = VCC, VCC = VCC max; bottom 1/8 array |
| CS# = VCC, VCC = VCC max; top 1/2 array |
| CS# = VCC, VCC = VCC max; top 1/4 array |

VCC standby current
(-40°C to +85°C)

–

ICC4

µA

1150

VCC standby current
(-40°C to +105°C)

–

CS# = VCC, VCC = VCC max;
top 1/8 array
850

Reset current (-40°C to +85°C)
CS# = VCC, RESET# = VSS,
VCC = VCC max

0.55
mA
Reset current (-40°C to +105°C)
0.75

ICC5

Notes

54. Not 100% tested.
55. RESET# LOW initiates exits from hybrid sleep state and initiates the draw of ICC5 reset current, making ILI during RESET#
LOW insignificant.

Datasheet
31 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 32 -->

Datasheet
32 of 48
002-31341 Rev. *C
2022-04-18
 
256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V
Electrical specifications
ICC6
Active clock stop current 
(-40°C to +85°C)
CS# = VSS, RESET# = VCC,
VCC = VCC max
–
17
25
mA
Active clock stop current 
(-40°C to +105°C)
30
ICC7
VCC current during power up
CS# = VCC, VCC = VCC max, 
VCCQ = VCC
–
35
IDPD
Deep power down current 
(-40°C to +85°C)
CS# = VCC, VCC = VCC max
12
µA
Deep power down current 
(-40°C to +105°C)
15
IHS[55]
Hybrid sleep current 
(-40°C to +85°C)
CS# = VCC, VCC = VCC max; 
full array 
140
1100
CS# = VCC, VCC = VCC max; 
bottom 1/2 array 
–
800
CS# = VCC, VCC = VCC max; 
bottom 1/4 array 
600
CS# = VCC, VCC = VCC max; 
bottom 1/8 array
500
CS# = VCC, VCC = VCC max; 
top 1/2 array
800
CS# = VCC, VCC = VCC max; 
top 1/4 array
600
CS# = VCC, VCC = VCC max; 
top 1/8 array
500
Hybrid sleep current 
(-40°C to +105°C)
CS# = VCC, VCC = VCC max; 
full array 
140
1250
CS# = VCC, VCC = VCC max; 
bottom 1/2 array 
–
850
CS# = VCC, VCC = VCC max; 
bottom 1/4 array 
650
CS# = VCC, VCC = VCC max; 
bottom 1/8 array
550
CS# = VCC, VCC = VCC max; 
top 1/2 array
850
CS# = VCC, VCC = VCC max; 
top 1/4 array
650
CS# = VCC, VCC = VCC max; 
top 1/8 array
550
VIL
Input low voltage
–
-0.15  VCCQ
0.30  VCCQ
V
VIH
Input high voltage
0.70  VCCQ
1.15  VCCQ
VOL
Output low voltage
IOL = 100 μA for DQ[7:0]
–
0.2
VOH
Output high voltage
IOL = 100 μA for DQ[7:0]
VCCQ - 0.20
–
Table 19
DC characteristics (CMOS compatible) (Continued)
Parameter
Description
Test Conditions
Value
Unit
Min
Typ[54]
Max
Notes
54. Not 100% tested.
55. RESET# LOW initiates exits from hybrid sleep state and initiates the draw of ICC5 reset current, making ILI during RESET# 
LOW insignificant.

<!-- page 33 -->

Datasheet
33 of 48
002-31341 Rev. *C
2022-04-18
 
256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V
Electrical specifications
9.5.1
Capacitance characteristics
Table 20
1.8 V capacitive characteristics[56–58]
Description
Parameter
256-Mb
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
Table 21
Thermal resistance
Parameter[59]
Description
Test conditions
49-ball FBGA 
package
Unit
JA
Thermal resistance 
(junction to ambient)
Test conditions follow standard test 
methods and procedures for measuring 
thermal impedance, per EIA/JESD51.
56.6
°C/W
JC
Thermal resistance 
(junction to case)
20.4
Notes
56.These values are guaranteed by design and are tested on a sample basis only.
57.Contact capacitance is measured according to JEP147 procedure for measuring capacitance using a vector 
network analyzer. VCC, VCCQ are applied and all other signals (except the signal under test) floating. 
DQ’s should be in the high impedance state.
58.Note that the capacitance values for the CK, CK#, RWDS and DQx signals must have similar capacitance 
values to allow for signal propagation time matching in the system. The capacitance value for CS# is not as 
critical because there are no critical timings between CS# going active (LOW) and data being presented on 
the DQs bus.
59.This parameter is guaranteed by characterization; not tested in production.

<!-- page 34 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Electrical specifications

## 9.6 Power-up initialization

HYPERRAM™ products include an on-chip voltage sensor used to launch the power-up initialization process. VCC
and VCCQ must be applied simultaneously. When the power supply reaches a stable level at or above VCC(min),
the device will require tVCS time to complete its self-initialization process.
The device must not be selected during power-up. CS# must follow the voltage applied on VCCQ until VCC (min) is
reached during power-up, and then CS# must remain HIGH for a further delay of tVCS. A simple pull-up resistor
from VCCQ to Chip Select (CS#) can be used to insure safe and proper power-up.
If RESET# is LOW during power up, the device delays start of the tVCS period until RESET# is HIGH. The tVCS period
is used primarily to perform refresh operations on the DRAM array to initialize it.
When initialization is complete, the device is ready for normal operation.

| Vcc_VccQ | RESET# | CS# | VCC Minimum | tVCS | Device Access | Allowed |  |
|---|---|---|---|---|---|---|---|
| Figure 21 | Power-up | with RESET# HIGH |  |  |  |  |  |
| Vcc_VccQ | RESET# | CS# | VCC Minimum | tVCS | Device Access | Allowed |  |
| Figure 22 Table 22 | Power-up Power-up | with RESET# LOW parameters[60–62] and reset |  |  |  |  |  |
| Parameter |  |  | Description |  |  | Min Max Unit |  |
| VCC |  | 1.8 V VCC power supply |  |  |  | 1.7 2.0 | V |
| tVCS |  |  VCC and VCCQ minimum | and RESET# HIGH | to first access |  | – 150 | µs |

Notes

60.Bus transactions (read and write) are not allowed during the power-up reset time (tVCS).
61.VCCQ must be the same voltage as VCC.
62.VCC ramp rate may be non-linear.

Datasheet
34 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 35 -->

Datasheet
35 of 48
002-31341 Rev. *C
2022-04-18
 
256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V
Electrical specifications
9.7
Power down
HYPERRAM™ devices are considered to be powered-off when the array power supply (VCC) drops below the VCC 
lock-out voltage (VLKO). During a power supply transition down to the VSS level, VCCQ should remain less than or 
equal to VCC. At the VLKO level, the HYPERRAM™ device will have lost configuration or array data.
VCC must always be greater than or equal to VCCQ (VCC  VCCQ). 
During power-down or voltage drops below VLKO, the array power supply voltages must also drop below VCC 
Reset (VRST) for a power down period (tPD) for the part to initialize correctly when the power supply again rises to 
VCC minimum. See Figure 23. 
If during a voltage drop the VCC stays above VLKO the part will stay initialized and will work correctly when VCC is 
again above VCC minimum. If VCC does not go below and remain below VRST for greater than tPD, then there is no 
assurance that the POR process will be performed. In this case, a hardware reset will be required ensure the 
HYPERBUS™ extended-IO device is properly initialized.
Figure 23
Power down or voltage drop
Table 23 describes the HYPERRAM™ device-dependent aspects of power down specifications.
Table 23
1.8 V power-down voltage and timing[63]
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
–
VRST
VCC low Voltage needed to ensure initialization will occur
0.7
tPD
Duration of VCC  VRST
50
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
Note
63.VCC ramp rate may be non-linear.

<!-- page 36 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Electrical specifications

## 9.8 Hardware reset

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
within the required array refresh interval per Table 12. This may result in the loss of DRAM array data during or
immediately following a hardware reset. The host system should assume DRAM array data is lost after a hardware
reset and reload any required data.

| RESET# CS# | tRP | tRPH | tRH |  |
|---|---|---|---|---|
| Figure 24 Hardware reset timing Table 24 Power-up and reset parameters | diagram |  |  |  |
| Parameter | Description |  |  | Min Max Unit |
| tRP RESET# pulse width tRH Time between RESET# tRPH RESET# LOW to CS# LOW | (HIGH) and CS# | (LOW) |  | 200 – ns 400 |

Datasheet
36 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 37 -->

Datasheet
37 of 48
002-31341 Rev. *C
2022-04-18
 
256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V
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
Figure 27
Input waveforms and measurement levels[66]
Table 25
Test specification[64]
Parameter
All speeds
Unit
Output load capacitance, CL
15
pF
Minimum input rise and fall slew rates (1.8 V)[65]
1.13
V/ns
Input pulse levels
0.0–VCCQ
V
Input timing measurement reference levels
VCCQ/2
Output timing measurement reference levels
VCCQ/2
Valid_High_or_Low
High_to_Low_Transition
Low_to_High_Transition
Invalid
High_Impedance
Device 
Under 
Test
CL
VccQ
Vss
Input VccQ / 2
Measurement Level
VccQ / 2 Output
Notes
64.Input and output timing is referenced to VCCQ/2 or to the crossing of CK/CK#.
65.All AC timings assume this input slew rate.
66.Input timings for the differential CK/CK# pair are measured from clock crossings.

<!-- page 38 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Timing specifications

## 10.3 CLK characteristics

| CK# CK | tCKHP | tCK | tCKHP |  | VIX VCCQ VIX | (Max) / 2 (Min) |  |
|---|---|---|---|---|---|---|---|
| Figure 28 Clock characteristics timings[67–69] Table 26 Clock |  |  |  |  |  |  |  |
| Parameter |  |  | Symbol |  |  | 200 MHz Min | Max |
| CK period |  |  |  | tCK |  | 5 | – |
| CK half period - duty cycle |  |  |  | tCKHP |  | 0.45 | 0.55 |
| CK half period at frequency Min = 0.45 tCK Min Max = 0.55 tCK Min |  |  |  | tCKHP |  | 2.25 | 2.75 |

VID (AC) (min)

VID (DC) (min)

Differential Input Voltage (CK-CK#)

0

half cycle

-VID (DC) (min)

-VID (AC) (min)

time

Figure 29
Differential clock (CK/CK#) input swing

Notes

67.Clock jitter of ±5% is permitted.
68.Minimum frequency (maximum tCK) is dependent upon maximum CS# LOW time (tCSM), initial latency and
burst length.
69.CK and CK# input slew rate must be 1 V/ns (2 V/ns if measured differentially).

Datasheet
38 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 39 -->

Datasheet
39 of 48
002-31341 Rev. *C
2022-04-18
 
256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V
Timing specifications
10.4
AC characteristics
10.4.1
Read transactions
Table 27
Clock AC/DC electrical characteristics[70, 71]
Parameter
Symbol
Min
Max
Unit
DC input voltage
VIN
–0.3
VCCQ + 0.3
V
DC input differential voltage
VID(DC)
VCCQ × 0.4
VCCQ + 0.6
AC input differential voltage
VID(AC)
VCCQ × 0.6
VCCQ + 0.6
AC differential crossing voltage
VIX
VCCQ × 0.4
VCCQ × 0.6
Table 28
HYPERRAM™ specific read timing parameters
Parameter
Symbol
200 MHz
Unit
Min
Max
Chip select high between transactions 
tCSHI
6
–
ns
HYPERRAM™ read-write recovery time 
tRWR
35
Chip select setup to next CK rising edge
tCSS
4
Data strobe valid 
tDSV
–
5
Input setup 
tIS
0.5
–
Input hold 
tIH
0.5
HYPERRAM™ read initial access time
tACC
35
Clock to DQs low Z
tDQLZ
0
CK transition to DQ valid
tCKD
1
5
CK transition to DQ invalid 
tCKDI
0
4.2
Data valid (tDV min = the lesser of: (tCKHP min – tCKD max + tCKDI max) 
or (tCKHP min – tCKD min + tCKDI min)
tDV
[72 , 73]
1.45
–
CK transition to RWDS valid
tCKDS
1
5
RWDS transition to DQ valid 
tDSS
–0.4
+0.4
RWDS transition to DQ invalid 
tDSH
Chip select hold after CK falling edge
tCSH
0
–
Chip select inactive to RWDS High-Z 
tDSZ
–
5
Chip select inactive to DQ High-Z
tOZ
Refresh time
tRFH
35
–
CK transition to RWDS low @ CA phase @ read 
tCKDSR
1
5.5
Notes
70.VID is the magnitude of the difference between the input level on CK and the input level on CK#.
71.The value of VIX is expected to equal VCCQ/2 of the transmitting device and must track variations in the DC 
level of VCCQ.
72.Refer to Figure 32 for data valid timing.
73.The tDV timing calculation is provided for reference only, not to determine the spec limit. The spec limit is 
guaranteed by testing.

<!-- page 40 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Timing specifications

.

| CS# CK , CK# RWDS[1:0] DQ[15:0] | tCSHI tCSM tCSS tRWR =Read Write Recovery tACC = Access tDSV 4 cycle latency High = 2x Latency Count Low = 1x Latency Count tIS tIH 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[15:0] and Memory drives RWDS[1:0] | tCSH tCSS tCKDS tDSZ tDSS tOZ tDQLZ tCKD tDSH Dn Dn Dn+1 Dn+1 A B A B RWDS and Data Memory drives DQ[15:0] are edge aligned and RWDS[1:0] |
|---|---|---|
| Figure 30 Read | timing diagram — no additional latency required |  |
| CS# tRWR =Read CK , CK# RWDS[1:0] DQ[15:0] | Write Recovery Additional Latency 4 cycle latency 1 4 tDSV tCKDS High = 2x Latency Count Low = 1x Latency Count 47:40 39:32 31:24 23:16 15:8 7:0 Command-Address Host drives DQ[15:0] and Memory drives RWDS | tACC = Access cycle latency 2 tCKDS tCKD Dn Dn Dn+1 Dn+1 A B A B Memory drives DQ[15:0] and RWDS[1:0] |
| Figure 31 Read | timing diagram — with additional latency required |  |
| CS# CK CK# RWDS[1:0] DQ[15:0] | tCKHP tCKDS tCKD tDQLZ tCKD Dn A | tCSHS tCSS tDSZ tOZ tDSS tCKDI tDSH tDV Dn Dn+1 Dn+1 B A B |
| Figure 32 Data | timing[74–76] valid |  |

Notes

74.tCKD and tCKDI parameters define the beginning and end position of data valid period.
75.tDSS and tDSH define how early or late DQ may transition relative to RWDS. This is a potential skew between
the CK to DQ delay tCKD and CK to RWDS delay tCKDS.
76.Since DQ and RWDS are the same output types, the tCKD, tCKDI and tCKDS values track together (vary by the
same ratio).

Datasheet
40 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 41 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Timing specifications

## 10.4.2 Write transactions

Table 29
Write timing parameters

| Parameter | Symbol |  | Min | 200 MHz Max |  | Unit |
|---|---|---|---|---|---|---|
| Read-write recovery time Access time Refresh time |  | tRWR tACC tRFH |  | 35 35 35 | – | ns |
| Chip select maximum low time (85°C) Chip select maximum low time (105°C) RWDS data mask valid |  | tCSM tCSM tDMV |  | – 0 | 4 1 – | µs |
| tCSHI tCSM |  |  |  |  |  |  |

| Access time | tACC | 35 |
|---|---|---|
| Refresh time | tRFH | 35 |

CS#

tCSS

tCSH

tRWR =Read Write Recovery
tACC = Access

tCSS

CK#
,
CK

4 cycle latency

tDSV

tIS

tDSZ

tIH

tDMV

High = 2x Latency Count
Low =  1x Latency Count

RWDS[1:0]

tIS

tIS

tIH

tIH

Dn
A

Dn
B

Dn+1
A

Dn+1
B

47:40
39:32
31:24
23:16
15:8
7:0

DQ[15:0]

Command-Address

CK and Data
are center aligned

Host drives DQ[15:0]
and RWDS[1:0]

Host drives DQ[15:0] and Memory drives RWDS[1:0]

Figure 33
Write timing diagram — no additional latency

Datasheet
41 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 42 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

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

DQ[15:0]

VIL(max)

VSSQ

| Figure 34 | DDR input timing reference levels |
|---|---|
|  | tSCK VCCQ RWDS VT VSSQ tDSS tDSH VCCQ VOH(min) DQ[15:0] VT VOL(max) VSSQ |
| Figure 35 | DDR output timing reference levels |

Datasheet
42 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 43 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Packaging

## 11 Packaging

## 11.1 FBGA 49-ball 7 × 7 array footprint

HYPERBUS™ extended-IO HYPERRAM™ devices are provided in fortified ball grid array (FBGA), 1 mm pitch,
49-ball, 7 × 7 ball array footprint, with 8 mm × 8 mm body.

1
2
3
4
5
6
7

A

RFU
RFU

CS#

RESET#

RFU

VSS

RFU

B

VSSQ

RFU

CK#

CK

RFU

VSS

VCC

C

RFU

VCC

VSSQ
RWDS0

DQ2

RFU

VCCQ

RFU

VSSQ
VCCQ
DQ0
DQ1
DQ3

DQ4

D

E

RFU

DQ7
DQ5
DQ6
VCCQ

VSSQ

VCCQ

F

RWDS1

DQ8

DQ9

DQ10

DQ11

VCCQ
VCCQ

G

RFU

DQ12

DQ13

VSSQ

DQ14

DQ15

VSSQ

Figure 36
49-ball FBGA, 8  8 mm, 7  7 ball footprint, top view

Datasheet
43 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 44 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Packaging

## 11.2 Package diagram

NOTES:

DIMENSIONS
SYMBOL

1.    ALL DIMENSIONS ARE IN MILLIMETERS.

MIN.
NOM.
MAX.

BALL POSITION DESIGNATION PER JEP95, SECTION 3, SPP-020.

2.

A

-
1.00

-

-

A1
0.20

-

3.

"e"   REPRESENTS THE SOLDER BALL GRID PITCH.

8.00 BSC

D

4.

SYMBOL "MD" IS THE BALL MATRIX SIZE IN THE "D" DIRECTION.

E

8.00 BSC

SYMBOL "ME" IS THE BALL MATRIX SIZE IN THE "E" DIRECTION.

6.00 BSC

D1

N IS THE NUMBER OF POPULATED SOLDER BALL POSITIONS FOR MATRIX SIZE MD X ME.

6.00 BSC

E1

5.

DIMENSION "b" IS MEASURED AT THE MAXIMUM BALL DIAMETER IN A PLANE PARALLEL TO DATUM C.

MD

7

6.

"SD" AND "SE" ARE MEASURED WITH RESPECT TO DATUMS A AND B AND DEFINE THE

ME

7

POSITION OF THE CENTER SOLDER BALL IN THE OUTER ROW.

N

49

0.40

0.35

0.45

b

WHEN THERE IS AN ODD NUMBER OF SOLDER BALLS IN THE OUTER ROW "SD" OR "SE" = 0.

eE

1.00 BSC

WHEN THERE IS AN EVEN NUMBER OF SOLDER BALLS IN THE OUTER ROW, "SD" = eD/2 AND "SE" = eE/2.

eD

1.00 BSC

"+" INDICATES THE THEORETICAL CENTER OF DEPOPULATED BALLS.

7.

0.00 BSC

SD

A1 CORNER TO BE IDENTIFIED BY CHAMFER, LASER OR INK MARK, METALLIZED MARK INDENTATION
8.

SE
0.00 BSC

OR OTHER MEANS.

JEDEC SPECIFICATION NO. REF: N/A
9.
002-32552 **

Figure 37
Package outline, 49-ball BGA 8.0 mm  8.0 mm  1.0 mm VAD049

Datasheet
44 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 45 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Ordering information

## 12 Ordering information

## 12.1 Ordering part number

The ordering part number is formed by a valid combination of the following:

S80KS
256
4
GA
C
H
I
02
0

Packing type
0 = Tray
3 = 13” Tape and reel

Model number (Additional ordering options)
04 = 49-ball FBGA (JEDEC Std.)

Temperature range / Grade
I = Industrial (–40°C to + 85°C)
V = Industrial Plus (–40°C to + 105°C)

Package materials

H = Low-Halogen, Pb-free

Package type
C = 49-ball FBGA, 1.00 mm pitch (7  7 ball footprint)

Speed
GA = 200 MHz

Device technology
2 = HYPERBUS™
3 = Octal xSPI
4 = HYPERBUS™ extended-IO

Density
256 = 256 Mb

Device family
S80KS - 1.8 V-only, HYPERRAM™ self-refresh DRAM

Datasheet
45 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 46 -->

256 Mb HYPERRAM™ self-refresh DRAM (PSRAM)
HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Ordering information

## 12.2 Valid combinations

The recommended combinations table lists configurations planned to be available in volume. Table 30 will be
updated as new combinations are released. Contact your local sales representative to confirm availability of
specific combinations and to check on newly released combinations.

Table 30
Valid combinations - standard

| Package, Device Model Packing Density Technology Speed material, and family number type temperature | Ordering part number | Package marking |
|---|---|---|
| CHI S80KS2564GACHI040 S80KS 256 4 GA 04 0 CHV S80KS2564GACHV040 |  | 8KS2564GAHI04 8KS2564GAHV04 |

Datasheet
46 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 47 -->

## 256 Mb HYPERRAM™ self-refresh DRAM (PSRAM) HYPERBUS™ Extended-IO (x16) interface, 1.8 V

Revision history

## Revision history

| Document version | Date of release | Description of changes |
|---|---|---|
| *C | 2022-04-18 Publish to web. |  |

Datasheet
47 of 48
002-31341 Rev. *C
2022-04-18

<!-- page 48 -->

Please read the Important Notice and Warnings at the end of this document

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

Edition 2022-04-18

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

© 2022 Infineon Technologies AG.
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

Go to www.infineon.com/support

Document reference

002-31341 Rev. *C

The data contained in this document is exclusively
intended for technically trained staff. It is the
responsibility of customer’s technical departments
to evaluate the suitability of the product for the
intended application and the completeness of the
product information given in this document with
respect to such application.

<!-- END VERBATIM SOURCE -->
