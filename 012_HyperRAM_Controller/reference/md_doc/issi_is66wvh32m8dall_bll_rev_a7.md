---
protocol: "ISSI IS66WVH32M8DALL/BLL HyperRAM x8 datasheet"
revision: "Rev A7 (2024-11-21)"
source: "https://www.issi.com/WW/pdf/66-67WVH32M8DALL-BLL.pdf"
license: "ISSI copyright; all rights reserved"
redistribution: "forbidden"
retrieved: 2026-10-27
source_sha256: "5f4273cf4a537266ad108c873b28138e705727861de9b2788e4d3e9d3b7c70aa"
converter: "vlsit_pdf_to_md.py (PyMuPDF)"
---

# ISSI IS66WVH32M8DALL/BLL HyperRAM x8 datasheet - revision Rev A7 (2024-11-21)

> **Key notes (written by the converter operator, not part of the source):**
> - none recorded

> The text between the markers below is the source text, converted without rewording.

<!-- BEGIN VERBATIM SOURCE -->

<!-- page 1 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 32M x 8 HyperRAM™

### NOVEMBER 2024

Overview
The IS66/67WVH32M8DALL/BLL are integrated memory device containing 256Mbit Pseudo Static
Random Access Memory using a self-refresh DRAM array organized as 32M words by 8 bits. The device
supports a HyperBus interface, Very Low Signal Count (Address, Command and data through 8 DQ
pins), Hidden Refresh  Operation, and Automotive Temperature Operation, designed specially for Mobile
and Automotive applications.

# Distinctive Characteristics

### High Performance

### HyperBusTM Low Signal Count Interface

Up to 400MB/s
Double-Data Rate (DDR) - two data transfers per clock

3.0V I/O, 11 bus signals

– Single ended clock (CK)
1.8V I/O, 12 bus signals


105°C
200-MHz clock rate (400 MB/s) at

– Differential clock (CK, CK#)
Chip Select (CS#)
8-bit data bus (DQ[7:0])
Read-Write Data Strobe (RWDS)

Sequential burst transactions
Configurable Burst Characteristics

– Wrapped burst lengths:

– 16 bytes (8 clocks)
– 32 bytes (16 clocks)
– 64 bytes (32 clocks)
– 128 bytes (64 clocks)
– Linear burst
– Hybrid option - one wrapped burst followed by linear burst
– Wrapped or linear burst type selected in each transaction
– Configurable output drive strength

– Bidirectional Data Strobe / Mask
– Output at the start of all transactions to indicate refresh

latency
– Output during read transactions as Read Data Strobe
– Input during write transactions as Write Data Mask

RWDS DCARS Timing

– During read transactions RWDS is offset by a second

clock, phase shifted from CK
– The Phase Shifted Clock is used to move the RWDS

Temperature Grade

transition edge within the read data eye

–
–
–

Industrial: -40°C to +85°C
Auto (A1) Grade: -40°C to +85°C
Auto (A2) Grade: -40°C to +105°C

Green Package (RoHS Compliant, Halogen-Free)

and TSCA Compliant
– 24-ball FBGA

# Performance Summary

| Read Transaction Timings |  |
|---|---|
| Maximum Clock Rate at 1.8V VCC/VCCQ | 200 MHz |
| Maximum Clock Rate at 3.0V VCC/VCCQ | 200 MHz |
| Maximum Access Time, (tACC at 200 MHz) | 35 ns |

| Maximum Current Consumption |  |
|---|---|
| Burst Read | 30mA |
| Burst Write | 25 mA |
| Standby (CS# = High, 3V, 105 °C) | 1200 µA |
| Deep Power Down (CS# = High, 3V, 105 °C) | 50 µA |
| Standby (CS# = High, 1.8V, 105 °C) | 1200 µA |
| Deep Power Down (CS# = High, 1.8V, 105 °C) | 30 µA |

Copyright © 2024 Integrated Silicon Solution, Inc. All rights reserved. ISSI reserves the right to make changes to this specification and its products at any time without notice.
ISSI assumes no liability arising out of the application or use of any information, products or services described herein. Customers are advised to obtain the latest version of this
device specification before relying on any published information and before placing orders for products.

Integrated Silicon Solution, Inc. does not recommend the use of any of its products in life support applications where the failure or malfunction of the product can reasonably be
expected to cause failure of the life support system or to significantly affect its safety or effectiveness. Products are not authorized for use in such applications unless Integrated
Silicon Solution, Inc. receives written assurance to its satisfaction, that:
a.) the risk of injury or damage has been minimized;
b.) the user assume all such risks; and
c.) potential liability of Integrated Silicon Solution, Inc is adequately protected under the circumstances

1

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 2 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# Logic Block Diagram

### CS#

### X Decoders

### Memory

### CK/CK#

### (PSC/PSC#)

### Control

### Y Decoders

### RWDS

### I/O

### Logic

### Data Latch

### DQ[7:0]

### RESET#

### Data Path

2

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 3 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# Contents

1.
General Description..................................................... 4

9.7
Hardware Reset............................................................ 36

10.
Timing Specifications................................................. 37
10.1 Key to Switching Waveforms ........................................ 37
10.2 AC Test Conditions....................................................... 37
10.3 AC Characteristics ........................................................ 38

2.
HyperRAM Product Overview..................................... 7

3.
HyperRAM Signal Descriptions.................................. 8
3.1
Input/Output Summary................................................... 8
3.2
Command/Address Bit Assignments ............................. 9
3.3
Read Transactions....................................................... 13
3.4
Write Transactions with Initial Latency
(Memory Core Write) ................................................... 14
3.5
Write Transactions without Initial Latency
(Register Write)............................................................ 16

11.
Physical Interface ....................................................... 41
11.1 FBGA 24-Ball 5 x 5 Array Footprint .............................. 41

12.
DDR Center Aligned
Read Strobe Functionality ......................................... 42
12.1 HyperRAM Products with DCARS
Signal Descriptions ....................................................... 42
12.2 HyperRAM Products with DCARS
— FBGA 24-ball, 5x5 Array Footprint ........................... 43
12.3 HyperRAM Memory with DCARS Timing...................... 43

4.
Memory Space............................................................ 17

5.
Register Space ........................................................... 17
5.1
Device Identification Registers..................................... 17
5.2
Register Space Access................................................ 18

### HyperRAM Device Hardware Interface

13.
Ordering Rule Information............ ............................ 44
13.1 Ordering Part Number................................................... 45
14.
PACKAGE INFORMATION.............................. ............ 47

6.
Interface States .......................................................... 25
6.1
Power Conservation Modes......................................... 25

7.
HyperRAM Connection Descriptions....................... 27
7.1
Other Connectors Summary ........................................ 27
7.2
HyperRAM Block Diagram........................................... 28

8.
Interface States .......................................................... 29

9.
Electrical Specifications............................................ 30
9.1
Absolute Maximum Ratings ......................................... 30
9.2 Latchup Characteristics ............................................... 30
9.3
Operating Ranges........................................................ 31
9.4
DC Characteristics....................................................... 32
9.5
Power-Up Initialization ................................................. 33
9.6
Power Down................................................................. 35

3

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 4 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 1. General Description

The ISSI 256-Mbit HyperRAMTM device is a high-speed CMOS, self-refresh Dynamic RAM (DRAM), with a HyperBus interface.

The Random Access Memory (RAM) array uses dynamic cells that require periodic refresh. Refresh control logic within the device
manages the refresh operations on the RAM array when the memory is not being actively read or written by the HyperBus interface
master (host). Since the host is not required to manage any refresh operations, the DRAM array appears to the host as though the
memory uses static cells that retain data without refresh. Hence, the memory can also be described as Pseudo Static RAM
(PSRAM).

Because the DRAM cells cannot be refreshed during a read or write transaction, there is a requirement that the host not perform
read or write burst transfers that are long enough to block the necessary internal logic refresh operations when they are needed. The
host is required to limit the duration of transactions and allow additional initial access latency, at the beginning of a new transaction,
if the memory indicates a refresh operation is needed.

HyperBus is a low signal count, Double Data Rate (DDR) interface, that achieves high speed read and write throughput. The DDR
protocol transfers two data bytes per clock cycle on the DQ input/output signals. A read or write transaction on HyperBus consists of
a series of 16-bit wide, one clock cycle data transfers at the internal HyperRAM core with two corresponding 8-bit wide, one-half-
clock-cycle data transfers on the DQ signals. All inputs and outputs are LV-CMOS compatible. Ordering Part Number (OPN) device
versions are available for core (VCC) and IO buffer (VCCQ) supplies of either 1.8V or 3.0V (nominal).

Command, address, and data information is transferred over the eight HyperBus DQ[7:0] signals. The clock is used for information
capture by a HyperBus slave device when receiving command, address, or data on the DQ signals. Command or Address values
are center aligned with clock transitions.

Every transaction begins with the assertion of CS# and Command-Address (CA) signals, followed by the start of clock transitions to
transfer six CA bytes, followed by initial access latency and either read or write data transfers, until CS# is deasserted.

### Figure 1.1  Read Transaction, Single Initial Latency Count

CS#

tRWR=Read Write Recovery
t ACC = Access

CK#,CK

Latency Count

High = 2x Latency Count
Low =  1x Latency Count

RWDS

RWDS and Data
are edge aligned

Dn
A

Dn
B

Dn+1

Dn+1

DQ[7:0]

47:40
39:32
31:24
23:16
15:8
7:0

A

B

Command-Address

Memory drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

The Read/Write Data Strobe (RWDS) is a bidirectional signal that indicates:

–
when data will start to transfer from a HyperRAM device to the master device in read transactions (initial read latency)

–
when data is being transferred from a HyperRAM device to the master device during read transactions (as a source

synchronous read data strobe)

–
when data may start to transfer from the master device to a HyperRAM device in write transactions (initial write latency)

–
data masking during write data transfers

During the CA transfer portion of a read or write transaction, RWDS acts as an output from a HyperRAM device to indicate whether
additional initial access latency is needed in the transaction.

During read data transfers, RWDS is a read data strobe with data values edge aligned with the transitions of RWDS.

4

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 5 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Figure 1.2  Read Transaction, Additional Latency Count

CS#

tRWR=Read Write Recovery
tACC = Access
Additional Latency

K#
C
C
,
K

Latency Count 1
Latency Count 2

High = 2x Latency Count
Low =  1x Latency Count

RWDS

RWDS and Data
are edge aligned

Dn
A

Dn
B

Dn+1

Dn+1

DQ[7:0]

47:40 39:32 31:24 23:16 15:8
7:0

A

B

Command-Address

Memory drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

During write data transfers, RWDS indicates whether each data byte transfer is masked with RWDS High (invalid and prevented
from changing the byte location in a memory) or not masked with RWDS Low (valid and written to a memory). Data masking may be
used by the host to byte align write data within a memory or to enable merging of multiple non-word aligned writes in a single burst
write. During write transactions, data is center aligned with clock transitions.

### Figure 1.3  Write Transaction, Single Initial Latency Count

CS#

tRWR =Read Write Recovery
tACC = Access

K#
C
C
,
K

CK and Data
are center aligned

Latency Count

High = 2x Latency Count
Low =  1x Latency Count

RWDS

Dn
A

Dn
B

Dn+1
A

Dn+1
B

DQ[7:0]

47:40
39:32
31:24
23:16
15:8
7:0

Command-Address

Host drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

Read and write transactions are burst oriented, transferring the next sequential word during each clock cycle. Each individual read
or write transaction can use either a wrapped or linear burst sequence.

5

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 6 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Figure 1.4  Linear Versus Wrapped Burst Sequence

16 word group alignment boundaries

Linear Burst

4h
5h
6h
7h
8h
9h
Ah Bh Ch
Dh Eh Fh 10h 11h 12h 13h

Initial address = 4h

Wrapped Burst

4h
5h
6h
7h
8h
9h
Ah Bh Ch
Dh Eh Fh
0h
1h
2h
3h

During wrapped transactions, accesses start at a selected location and continue to the end of a configured word group aligned
boundary, then wrap to the beginning location in the group, then continue back to the starting location. Wrapped bursts are generally
used for critical word first cache line fill read transactions. During linear transactions, accesses start at a selected location and
continue in a sequential manner until the transaction is terminated when CS# returns High. Linear transactions are generally used
for large contiguous data transfers such as graphic images. Since each transaction command selects the type of burst sequence for
that transaction, wrapped and linear bursts transactions can be dynamically intermixed as needed.

6

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 7 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 2. HyperRAM Product Overview

The256-Mbit HyperRAM device is a 1.8V or 3.0V core and I/O, synchronous self-refresh Dynamic RAM (DRAM). The HyperRAM
device provides a HyperBus slave interface to the host system. HyperBus has an 8-bit (1 byte) wide DDR data bus and uses only
word-wide (16-bit data) address boundaries. Read transactions provide 16 bits of data during each clock cycle (8 bits on both clock
edges). Write transactions take 16 bits of data from each clock cycle (8 bits on each clock edge).

### Figure 2.1  HyperRAM Interface

VCC
VCCQ
RESET#

CS#

DQ[7:0]

CK#
CK

RWDS

VSS
VSSQ

Read and write transactions require two clock cycles to define the target row address and burst type, then an initial access latency of
tACC. During the Command-Address (CA) part of a transaction, the memory will indicate whether an additional latency for a required
refresh time (tRFH) is added to the initial latency; by driving the RWDS signal to the High state. During the CA period the third clock
cycle will specify the target word address within the target row. During a read (or write) transaction, after the initial data value has
been output (or input), additional data can be read from (or written to) the row on subsequent clock cycles in either a wrapped or
linear sequence. When configured in linear burst mode, the device will automatically fetch the next sequential row from the memory
array to support a continuous linear burst. Simultaneously accessing the next row in the array while the read or write data transfer is
in progress, allows for a linear sequential burst operation that can provide a sustained data rate of 400 MB/s (1 byte (8 bit data bus)
* 2 (data clock edges) * 200 MHz = 400 MB/s).

7

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 8 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 3. HyperRAM Signal Descriptions

## 3.1 Input/Output Summary

HyperRAM signals are shown in Table 3.1. Active Low signal names have a hash symbol (#) suffix.

### Table 3.1  I/O Summary

| Symbol |  | Type |  | Description |
|---|---|---|---|---|
| CS# | Master Output, | Slave Input | Chip Select. Bus transactions are initiated transactions are terminated with a Low separate CS# for each slave. | with a High to Low transition. Bus to High transition. The master device has a |
| CK, CK# | Master Output, | Slave Input | Differential Clock. Command, address, to the crossing of the CK and CK# signals. devices. Single Ended Clock. CK# is not used used. The clock is not required to be free-running. | and data information is output with respect Differential clock is used on 1.8V I/O on 3.0V devices, only a single ended CK is |
| DQ[7:0] | Input/Output |  | Data Input/Output. Command, Address, these signals during Read and Write | and Data information is transferred on transactions. |
| RWDS | Input/Output |  | Read Write Data Strobe. During the transactions RWDS is a slave output is required. Slave output during read Slave input during data transfer in write (High = additional latency, Low = no | Command/Address portion of all bus and indicates whether additional initial latency data transfer, data is edge aligned with RWDS. transactions to function as a data mask. additional latency). |
| RESET# | Master Output, Internal Pull-up | Slave Input, | Hardware RESET. When Low the slave Standby state. RWDS and DQ[7:0] are Low. The slave RESET# input includes unconnected it will be pulled up to the | device will self initialize and return to the placed into the High-Z state when RESET# is a weak pull-up, if RESET# is left High state. |
| VCC | Power Supply |  | Core Power. |  |
| VCCQ | Power Supply |  | Input/Output Power. |  |
| VSS | Power Supply |  | Core Ground. |  |
| VSSQ | Power Supply |  | Input/Output Ground. |  |

8

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 9 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 3.2 Command/Address Bit Assignments

All HyperRAM bus transactions can be classified as either read or write. A bus transaction is started with CS# going Low with clock
in idle state (CK=Low and CK#=High). The first three clock cycles transfer three words of Command/Address (CA0, CA1, CA2)
information to define the transaction characteristics. The Command/Address words are presented with DDR timing, using the first six
clock edges. The following characteristics are defined by the Command/Address information:


Read or Write transaction


Address Space: memory array space or register space

–
Register space is used to access Device Identification (ID) registers and Configuration Registers (CR) that identify the

device characteristics and determine the slave specific behavior of read and write transfers on the HyperBus interface.


Whether a transaction will use a linear or wrapped burst sequence.


The target row (and half-page) address (upper order address)


The target column (word within half-page) address (lower order address)

### Figure 3.1  Command-Address Sequence

### CS#

### CK ,  CK#

DQ[7:0]
CA0[47:40]
CA0[39:32]
CA1[31:24]
CA1[23:16]
CA2[15:8]
CA2[7:0]

Notes:
1. Figure shows the initial three clock cycles of all transactions on the HyperBus.

2. CK# of differential clock is shown as dashed line waveform.

3. Command-Address information is “center aligned” with the clock during both Read and Write transactions.

### Table 3.2  Command-Address Bit Assignment to DQ Signals

| Signal | CA0[47:40] |  | CA0[39:32] |  | CA1[31:24] |  | CA1[23:16] |  | CA2[15:8] |  | CA2[7:0] |  |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| DQ[7] |  | CA[47] |  | CA[39] |  | CA[31] |  | CA[23] |  | CA[15] |  | CA[7] |
| DQ[6] |  | CA[46] |  | CA[38] |  | CA[30] |  | CA[22] |  | CA[14] |  | CA[6] |
| DQ[5] |  | CA[45] |  | CA[37] |  | CA[29] |  | CA[21] |  | CA[13] |  | CA[5] |
| DQ[4] |  | CA[44] |  | CA[36] |  | CA[28] |  | CA[20] |  | CA[12] |  | CA[4] |
| DQ[3] |  | CA[43] |  | CA[35] |  | CA[27] |  | CA[19] |  | CA[11] |  | CA[3] |
| DQ[2] |  | CA[42] |  | CA[34] |  | CA[26] |  | CA[18] |  | CA[10] |  | CA[2] |
| DQ[1] |  | CA[41] |  | CA[33] |  | CA[25] |  | CA[17] |  | CA[9] |  | CA[1] |
| DQ[0] |  | CA[40] |  | CA[32] |  | CA[24] |  | CA[16] |  | CA[8] |  | CA[0] |

9

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 10 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Table 3.3  Command/Address Bit Assignments

| CA Bit# | Bit Name |  | Bit Function |
|---|---|---|---|
| 47 | R/W# | Identifies the transaction as a read or write. R/W#=1 indicates a Read transaction R/W#=0 indicates a Write transaction |  |
| Address 46 | Space (AS) | Indicates whether the read or write transaction AS=0 indicates memory space AS=1 indicates the register space The register space is used to access device | accesses the memory or register space. ID and Configuration registers. |
| 45 | Burst Type | Indicates whether the burst will be linear Burst Type=0 indicates wrapped burst Burst Type=1 indicates linear burst | or wrapped. |
| Row 44-16 Column | & Upper Address | Row & Upper Column component of the Any upper Row address bits not used by host controller master interface. The size between Row and Column address is slave | target address: System word address bits A31-A3 a particular device density should be set to 0 by the of Rows and therefore the address bit boundary device dependent. |
| 15-3 | Reserved | Reserved for future column address expansion. Reserved bits are don’t care in current HyperBus controller master interface for future compatibility. | devices but should be set to 0 by the host |
| Lower 2-0 | Column Address | Lower Column component of the target address: starting word within a half-page. | System word address bits A2-0 selecting the |
| Notes: 1. A Row is a group of words device dependent behavior, distributed refresh interval 2. A Page is a 16-word (32-byte) boundaries - this is device 3. The Column address selects selects an 8-word (16-byte) 4. The initial read access by memory devices internally 5. HyperBus protocol address 29 Row &Upper Column 3 Lower Column address Each address selects a 29 + 3 = 32 address bits Future expansion of the | relevant to the refer to each HyperBus for HyperRAM memory. length and dependent behavior, the burst transaction Half-page and time starts when the interleaving space limit, assuming: address bits bits word wide (16 bit = = 4G addresses supporting column address can | internal memory array structure and additional latency device data sheet for additional information. aligned unit of device internal read or write access and refer to each HyperBus device data sheet for additional starting word location within a Row. The Column the lower portion selects the word within a Half-page Row and Upper Column (Half-page) address bits are access to 16 byte half-pages. 2 byte) data value 8Gbyte (64Gbit) maximum address space allow for 29 Row &Upper Column + 16 Lower Column | may be inserted by RWDS when crossing Row boundaries - this is Also, the number of Rows may be used in the calculation of a additional latency may be inserted by RWDS when crossing Page information. address is split into an upper and lower portion. The upper portion where a read or write transaction burst starts. captured by a slave interface. Continuous linear read burst is enabled address bits = 35 Tera-word = 70 Tera-byte address space. |

### Figure 3.2  Data Placement During a Read Transaction

### CS#

### CK ,  CK#

DQ[7:0]
CA0[47:40]
CA0[39:32]
CA1[31:24]
CA1[23:16]
CA2[15:8]
CA2[7:0]

Notes:
1. Figure shows a portion of a Read transaction on the HyperBus. CK# of differential clock is shown as dashed line waveform.

2. Data is “edge aligned” with the RWDS serving as a read data strobe during read transactions.

3. Data is always transferred in full word increments (word granularity transfers).

4. Word address increments in each clock cycle. Byte A is between RWDS rising and falling edges and is followed by byte B between RWDS falling and rising edges, of
each word.

5. Data bits in each byte are always in high to low order with bit 7 on DQ7 and bit 0 on DQ0.

10

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 11 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Table 3.4  Data Bit Placement During Read or Write Transaction

| Address Space | Byte Order | Byte Position | Word Data Bit | DQ | Bit Order |
|---|---|---|---|---|---|
| Memory | Big- endian Little- endian | A B A B | 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0 15 14 13 12 11 10 9 8 | 7 6 5 4 3 2 1 0 7 6 5 4 3 2 When data is being accessed in memory space: 1 The first byte of each word read or written 0 The bits of the word within the A and B bytes lower address bits 7-0 are written in the A byte 7 position, or vice versa, they will be read back 6 So, memory space can be stored and read 5 4 3 2 1 0 7 6 5 4 3 2 1 0 | is the “A” byte and the second is the “B” byte. depend on how the data was written. If the word position and bits 15-8 are written into the B byte in the same order. in either little-endian or big-endian order. |

11

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 12 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Table 3.4  Data Bit Placement During Read or Write Transaction  (Continued)

| Address Space | Byte Order | Byte Position | Word Data Bit | DQ | Bit Order |
|---|---|---|---|---|---|
| Register | Big- endian | A B | 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0 | 7 6 5 4 3 When data is being accessed in register space: 2 During a Read transaction on the HyperBus 1 upper order byte A (Word[15:8]) is transferred (edge aligned). The lower order byte B (Word[7:0]) 0 edges of RWDS. 7 During a write, the upper order byte A (Word[15:8]) lower order byte B (Word[7:0]) is transferred 6 So, register space is always read and written 5 dependent fixed bit location and meaning definitions. 4 3 2 1 0 | two bytes are transferred on each clock cycle. The between the rising and falling edges of RWDS is transferred between the falling and rising is transferred on the CK rising edge and the on the CK falling edge. in Big-endian order because registers have device |

### Figure 3.3  Data Placement During a Write Transaction

### CS#

### CK , CK#

### RWDS

DQ[7:0]
Dn A
Dn B
Dn+1 A
Dn+1 B
Dn+2 A

Notes:
1. Figure shows a portion of a Write transaction on the HyperBus.

2. Data is “center aligned” with the clock during a Write transaction.

3. RWDS functions as a data mask during write data transfers with initial latency. Masking of the first and last byte is shown to illustrate an unaligned 3 byte write of data.

4. RWDS is not driven by the master during write data transfers with zero initial latency. Full data words are always written in this case. RWDS may be driven low or left
High-Z by the slave in this case.

12

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 13 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 3.3 Read Transactions

The HyperBus master begins a transaction by driving CS# Low while clock is idle. Then the clock begins toggling while Command-
Address CA words are transfered.

In CA0, CA[47] = 1 indicates that a Read transaction is to be performed. CA[46] = 0 indicates the memory space is being read or
CA[46] = 1 indicates the register space is being read. CA[45] indicates the burst type (wrapped or linear). Read transactions can
begin the internal array access as soon as the row and upper column address has been presented in CA0 and CA1 (CA[47:16]).
CA2 (CA(15:0]) identifies the target Word address within the chosen row. However, some HyperBus devices may require a minimum
time between the end of a prior transaction and the start of a new access. This time is referred to as Read-Write-Recovery time
(tRWR). The master interface must start driving CS# Low only at a time when the CA1 transfer will complete after tRWR is satisfied.

The HyperBus master then continues clocking for a number of cycles defined by the latency count setting in configuration register 0.
The initial latency count required for a particular clock frequency is based on RWDS. If RWDS is Low during the CA cycles, one
latency count is inserted. If RWDS is High during the CA cycles, an additional latency count is inserted. Once these latency clocks
have been completed the memory starts to simultaneously transition the Read-Write Data Strobe (RWDS) and output the target
data.

New data is output edge aligned with every transition of RWDS. Data will continue to be output as long as the host continues to
transition the clock while CS# is Low. However, the HyperRAM device may stop RWDS transitions with RWDS Low, between the
delivery of words, in order to insert latency between words when crossing memory array boundaries.

Wrapped bursts will continue to wrap within the burst length and linear burst will output data in a sequential manner across row
boundaries. When a linear burst read reaches the last address in the array, continuing the burst beyond the last address will provide
undefined data. Read transfers can be ended at any time by bringing CS# High when the clock is idle.

The clock is not required to be free-running. The clock may remain idle while CS# is high.

### Figure 3.4  Read Transaction with Additional Initial Latency

CS#

Additional Latency

tRWR= Read Write Recovery

tACC  = Access

CK#, CK

High = 2x Latency Count
Low =  1x Latency Count

RWDS

RWDS and Data
are edge aligned

Latency Count 1
Latency Count 2

Dn+1

Dn+1

Dn
A

Dn
B

DQ[7:0]

47:40 39:32 31:24 23:16
15:8
7:0

A

B

Memory drives DQ[7:0]
and RWDS

Command-Address

Host drives DQ[7:0] and Memory drives RWDS

Notes:
1. Transactions are initiated with CS# falling while CK=Low and CK#=High.

2. CS# must return High before a new transaction is initiated.

3. CK# is the complement of the CK signal. 3V devices use a single ended clock (CK only), CK# is used with CK on1.8V devices to provide a differential clock. CK# of a
differential clock is shown as a dashed line waveform.

4. Read access array starts once CA[23:16] is captured.

5. The read latency is defined by the initial latency value in a configuration register.

6. In this read transaction example the initial latency count was set to four clocks.

7. In this read transaction a RWDS High indication during CA delays output of target data by an additional four clocks.

8. The memory device drives RWDS during read transactions.

13

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 14 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Figure 3.5  Read Transaction Without Additional Initial Latency

CS#

t RWR  =Read Write Recovery
t ACC   = Initial Acces

CK,  CK#

High = 2x Latency Count
Low =  1x Latency Count

RWDS

RWDS and Data
are edge aligned

4 cycle latency

Dn
A

Dn
B

Dn+1

Dn+1

47:40
39:32
31:24
23:16
15:8
7:0

DQ[7:0]

A

B

Command-Addres

Memory drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

Notes:
1. RWDS is Low during the CA cycles. In this Read Transaction there is a single initial latency count for read data access because, this read transaction does not begin
at a time when additional latency is required by the slave.

## 3.4 Write Transactions with Initial Latency (Memory Core Write)

The HyperBus master begins a transaction by driving CS# Low while clock is idle. Then the clock begins toggling while Command-
Address CA words are transfered.

In CA0, CA[47] = 0 indicates that a Write transaction is to be performed. CA[46] = 0 indicates the memory space is being written.
CA[45] indicates the burst type (wrapped or linear). Write transactions can begin the internal array access as soon as the row and
upper column address has been presented in CA0 and CA1 (CA[47:16]). CA2 (CA(15:0]) identifies the target word address within
the chosen row. However, some HyperBus devices may require a minimum time between the end of a prior transaction and the start
of a new access. This time is referred to as Read-Write-Recovery time (tRWR). The master interface must start driving CS# Low only
at a time when the CA1 transfer will complete after tRWR is satisfied.

The HyperBus master then continues clocking for a number of cycles defined by the latency count setting in configuration register 0.
The initial latency count required for a particular clock frequency is based on RWDS. If RWDS is Low during the CA cycles, one
latency count is inserted. If RWDS is High during the CA cycles, an additional latency count is inserted.

Once these latency clocks have been completed the HyperBus master starts to output the target data. Write data is center aligned
with the clock edges. The first byte of data in each word is captured by the memory on the rising edge of CK and the second byte is
captured on the falling edge of CK.

During the CA clock cycles, RWDS is driven by the memory.

During the write data transfers, RWDS is driven by the host master interface as a data mask. When data is being written and RWDS
is High the byte will be masked and the array will not be altered. When data is being written and RWDS is Low the data will be
placed into the array. Because the master is driving RWDS during write data transfers, neither the master nor the HyperRAM device
are able to indicate a need for latency within the data transfer portion of a write transaction. The acceptable write data burst length
setting is also shown in configuration register 0.

Data will continue to be transferred as long as the HyperBus master continues to transition the clock while CS# is Low. Legacy
format wrapped bursts will continue to wrap within the burst length. Hybrid wrap will wrap once then switch to linear burst starting at
the next wrap boundary. Linear burst accepts data in a sequential manner across page boundaries. Write transfers can be ended at
any time by bringing CS# High when the clock is idle.

When a linear burst write reaches the last address in the memory array space, continuing the burst will write to the beginning of the
address range.

The clock is not required to be free-running. The clock may remain idle while CS# is high.

14

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 15 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Figure 3.6  Write Transaction with Additional Initial Latency

CS#

Additional Latency

tRWR = Read Write Recovery

tACC  = Initial Access

CK, CK#

High = 2x Latency Count
Low =  1x Latency Count

RWDS

CK and Data
are center aligned

Latency Count 1
Latency Count 2

Dn
A

Dn
B

Dn+1

Dn+1

DQ[7:0]

47:40 39:32 31:24 23:16 15:8
7:0

B

A

Host drives DQ[7:0]
and RWDS

Command-Address

Host drives DQ[7:0] and Memory drives RWDS

Notes:
1. Transactions must be initiated with CK=Low and CK#=High.

2. CS# must return High before a new transaction is initiated.

3. During Command-Address, RWDS is driven by the memory and indicates whether additional latency cycles are required.

4. In this example, RWDS indicates that additional initial latency cycles are required.

5. At the end of Command-Address cycles the memory stops driving RWDS to allow the host HyperBus master to begin driving RWDS. The master must drive RWDS to
a valid Low before the end of the initial latency to provide a data mask preamble period to the slave.

6. During data transfer, RWDS is driven by the host to indicate which bytes of data should be either masked or loaded into the array.

7. The figure shows RWDS masking byte A0 and byte B1 to perform an unaligned word write to bytes B0 and A1.

### Figure 3.7  Write Transaction Without Additional Initial Latency

CS#

tRWR=Read Write Recovery
tACC = Access

CK#, CK

High = 2x Latency
Low =  1x Latency Count

Count

RWDS

CK and Data
are center aligned

Latency Count

Dn
A

Dn
B

Dn+1

Dn+1

DQ[7:0]

47:40
39:32
31:24
23:16
15:8
7:0

A

B

Command-Address

Host drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

Notes:
1. During Command-Address, RWDS is driven by the memory and indicates whether additional latency cycles are required.

2. In this example, RWDS indicates that there is no additional latency required.

3. At the end of Command-Address cycles the memory stops driving RWDS to allow the host HyperBus master to begin driving RWDS. The master must drive RWDS to
a valid Low before the end of the initial latency to provide a data mask preamble period to the slave.

4. During data transfer, RWDS is driven by the host to indicate which bytes of data should be either masked or loaded into the array.

5. The figure shows RWDS masking byte A0 and byte B1 to perform an unaligned word write to bytes B0 and A1.

15

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 16 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 3.5 Write Transactions without Initial Latency (Register Write)

A Write transaction starts with the first three clock cycles providing the Command/Address information indicating the transaction
characteristics. CA0 may indicate that a Write transaction is to be performed and also indicates the address space and burst type
(wrapped or linear).

Writes without initial latency are used for register space writes. HyperRAM device write transactions with zero latency mean that the
CA cycles are followed by write data transfers. Writes with zero initial latency, do not have a turn around period for RWDS. The
HyperRAM device will always drive RWDS during the Command-Address period to indicate whether extended latency is required for
a transaction that has initial latency. However, the RWDS is driven before the HyperRAM device has received the first byte of CA i.e.
before the HyperRAM device knows whether the transaction is a read or write to register space. In the case of a write with zero
latency, the RWDS state during the CA period does not affect the initial latency of zero. Since master write data immediately follows
the Command-Address period in this case, the HyperRAM device may continue to drive RWDS Low or may take RWDS to High-Z
during write data transfer. The master must not drive RWDS during Writes with zero latency. Writes with zero latency do not use
RWDS as a data mask function. All bytes of write data are written (full word writes).

The first byte of data in each word is presented on the rising edge of CK and the second byte is presented on the falling edge of CK.
Write data is center aligned with the clock inputs. Write transfers can be ended at any time by bringing CS# High when clock is idle.
The clock is not required to be free-running.

### Figure 3.8  Write Operation without Initial Latency

CS#

CK,  CK#

RWDS

Memory drives RWDS but master ignores it

47:40
39:32
31:24
23:16
15:8
7:0
15:8
7:0

DQ[7:0]

Data

Command-Address

Host drives DQ[7:0] with Command-Address and Write Data

16

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 17 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 4. Memory Space

When CA[46] is 0 a read or write transaction accesses the DRAM memory array.

### Table 4.1  Memory Space Address Map

| Unit Type | Count |  | System | Word Address Bits |  | CA |  | Bits |  | Notes |  |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Rows within 256 Mb 32768 device | (Rows) |  |  | A23 - A9 |  | 36 |  | - 22 |  |  |  |
| Row | 1 (row) |  |  | A8 - A3 |  | 21 |  | 512 (word - 16 1 kbytes |  | addresses) |  |
| Half-Page 8 (word | addresses) |  |  | A2 - A0 |  |  | 2 | - 0 16 bytes |  |  |  |
| 5. Register Space When CA[46] is 1 a read or write transaction Table 5.1 Register Space Address | accesses Map |  | the Register | Space. |  |  |  |  |  |  |  |
| System Register Address CA Bits | — — 47 46 |  | — 45 | 31-27 26-19 44-40 39-32 |  |  | 18-11 31-24 | 10-3 23-16 | — 15-8 |  | 2-0 7-0 |
| Identification Register 0 (read only) |  | C0h | or E0h |  | 00h |  |  | 00h 00h | 00h |  | 00h |
| Identification Register 1 (read only) |  | C0h | or E0h |  | 00h |  |  | 00h 00h | 00h |  | 01h |
| Configuration Register 0 Read |  | C0h | or E0h |  | 00h |  |  | 01h 00h | 00h |  | 00h |
| Configuration Register 0 Write |  |  | 60h |  | 00h |  |  | 01h 00h | 00h |  | 00h |
| Configuration Register 1 Read |  | C0h | or E0h |  | 00h |  |  | 01h 00h | 00h |  | 01h |
| Configuration Register 1 Write |  |  | 60h |  | 00h |  |  | 01h 00h | 00h |  | 01h |
| Note: 1. CA45 may be either 0 or 1 for either wrapped 5.1 Device Identification There are two read only, non-volatile, information fields identify:  Manufacturer  Type  Density – Row address bit count – Column address bit count Table 5.2 ID Register 0 Bit Assignments | or linear read. Registers word registers, | CA45 | must be that provide | 1 as only linear single word information on | register the device |  | writes | are supported. selected when CS# is | low. | The | device |
| Bits |  |  |  | Function |  |  |  | Settings (Binary) |  |  |  |
| 15-14 |  |  |  | Reserved |  | Reserved |  |  |  |  |  |
| 13 |  |  |  | Reserved |  | 0 | - | default |  |  |  |
| 12-8 |  |  | Row Address | Bit Count |  | 01110 |  | - Fiftteen Row address |  | bits |  |

17

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 18 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Table 5.2  ID Register 0 Bit Assignments (Continued)

| Bits |  | Function |  | Settings (Binary) |
|---|---|---|---|---|
| 7-4 Column |  | Address Bit Count | 1000 - Nine | column address bits |
| 3-0 | Manufacturer |  | 0000 - Reserved 0011 - ISSI 0010 to 1111 | - Reserved |
| Table 5.3 ID Register 1 Bit Assignments |  |  |  |  |
| Bits |  | Function |  | Settings (Binary) |
| 15-4 |  | Reserved | 0000_0000_0000b | (default) |
| 3-0 | Device | Type | 0000 - HyperRAM 0001 to 1111 | - Reserved |
| 5.1.1 Density and Row Boundaries |  |  |  |  |

The DRAM array size (density) of the device can be determined from the total number of system address bits used for the row and
column addresses as indicated by the Row Address Bit Count and Column Address Bit Count fields in the ID0 register. For example:
a 256-Mbit HyperRAM device has 9 column address bits and 15 row address bits for a total of 24 word address bits = 224 = 16
Mwords = 32 Mbytes. The 9 column address bits indicate that each row holds 29 = 512 words = 1 kbytes. The row address bit
count indicates there are 8196 x 4 rows to be refreshed within each array refresh window. The row count within each array (8196)
is used in calculating the refresh interval.
5.2
Register Space Access

Register default values are loaded upon power-up or hardware reset. The registers can be altered at any time while the device is in
the standby state.

Loading a register is accomplished with a single 16-bit word write transaction as shown in Figure 5.1. CA[47] is zero to indicate a
write transaction, CA[46] is a one to indicate a register space write, CA[45] is a one to indicate a linear write, lower order bits in the
CA field indicate the register address.

### Figure 5.1  Loading a Register

### CS#

### CK  ,   CK#

### Memory drives RWDS with Refresh Indication

### RWDS

DQ[7:0]
47:40
39:32
31:24
23:16
15:8
7:0
15:8
7:0

Command-Address
RD

### Host drives DQ[7:0] with Command-Address and Register Data

Notes:
1. The host must not drive RWDS during a write to register space.

2. The RWDS signal is driven by the memory during the Command-Address period based on whether the memory array is being refreshed. This refresh indication does
not affect the writing of register data. RWDS is driven immediately after CS# goes low, before CA[47:46] are received to indicate that the transaction is a write to
register space, for which the RWDS refresh indication is not relevant.

3. The register value is always provided immediately after the CA value and is not delayed by a refresh latency.

4. The the RWDS signal returns to high impedance after the Command-Address period. Register data is never masked. Both data bytes of the register data are loaded
into the selected register.

18

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 19 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

Each register is written with a separate single word write transaction. Register write transactions have zero latency, the single word
of data immediately follows the Command-Address. RWDS is not driven by the host during the write because RWDS is always
driven by the memory during the CA cycles to indicate whether a memory array refresh is in progress. Because a register space
write goes directly to a register, rather than the memory array, there is no initial write latency, related to an array refresh that may be
in progress. In a register write, RWDS is also not used as a data mask because both bytes of a register are always written and never
masked.

Reserved register fields must be written with their default value. Writing reserved fields with other than default values may produce
undefined results.

Reading of a register is accomplished with a single 16 bit read transaction with CA[46]=1 to select register space. If more than one
word is read, the same register value is repeated in each word read. The CA[45] burst type is “don’t care” because only a single
register value is read. The contents of the register is returned in the same manner as reading array data, with one or two latency
counts, based on the state of RWDS during the Command-Address period. The latency count is defined in the Configuration
Register 0 Read Latency field (CR0[7:4]).

## 5.2.1 Configuration Register 0

Configuration Register 0 (CR0) is used to define the power mode and access protocol operating conditions for the HyperRAM
device. Configurable characteristics include:


Wrapped Burst Length (16, 32, 64, or 128-byte aligned and length data group)


Wrapped Burst Type

–
Legacy wrap (sequential access with wrap around within a selected length and aligned group)

–
Hybrid wrap (Legacy wrap once then linear burst at start of the next sequential group)


Initial Latency


Variable Latency

–
Whether an array read or write transaction will use fixed or variable latency. If fixed latency is selected the memory will

always indicate a refresh latency and delay the read data transfer accordingly. If variable latency is selected, latency
for a refresh is only added when a refresh is required at the same time a new transaction is starting.


Output Drive Strength


Deep Power Down Mode

### Table 5.4  Configuration Register 0 Bit Assignments

| CR0 Bit | Function | Settings (Binary) |
|---|---|---|
| 15 Deep Power | 1 - Normal operation (default) Down Enable 0 - Writing 0 to CR[15] causes | the device to enter Deep Power Down |
| 14-12 Drive | 000 - 34 ohms (default) 001 - 115 ohms 010 - 67 ohms 011 - 46 ohms Strength 100 - 34 ohms 101 - 27 ohms 110 - 22 ohms 111 - 19 ohms |  |
| 11-8 | 1 - Reserved (default) Reserved Reserved for Future Use. When to 1 for future compatibility. | writing this register, these bits should be set |

19

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 20 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Table 5.4  Configuration Register 0 Bit Assignments (Continued)

| CR0 Bit |  | Function |  | Settings (Binary) |
|---|---|---|---|---|
| 7-4 | Initial | Latency | 0000 - 5 Clock Latency 0001 - 6 Clock Latency (166MHz, 0010 - 7 Clock Latency (200MHz) 0011 - 8 Clock Latency (200MHz) 0100 - Reserved ... 1101 - Reserved 1110 - 3 Clock Latency 1111 - 4 Clock Latency | default) |
| 3 Fixed |  | Latency Enable | 0 - Variable Latency - 1 or 2 times CA cycles. 1 - Fixed 2 times Initial Latency | Initial Latency depending on RWDS during (default) |
| 2 Hybrid |  | Burst Enable | 0: Wrapped burst sequences 1: Wrapped burst sequences | to follow hybrid burst sequencing in legacy wrapped burst manner (default) |
| 1-0 | Burst | Length | 00 - 128 bytes 01 - 64 bytes 10- 16 bytes 11 - 32 bytes (default) |  |

5.2.1.1
Wrapped Burst

A wrapped burst transaction accesses memory within a group of words aligned on a word boundary matching the length of the
configured group. Wrapped access groups can be configured as 16, 32, 64, or 128 bytes alignment and length. During wrapped
transactions, access starts at the Command-Address selected location within the group, continues to the end of the configured word
group aligned boundary, then wraps around to the beginning location in the group, then continues back to the starting location.
Wrapped bursts are generally used for critical word first instruction or data cache line fill read accesses.

5.2.1.2
Hybrid Burst

The beginning of a hybrid burst will wrap within the target address wrapped burst group length before continuing to the next half-
page of data beyond the end of the wrap group. Continued access is in linear burst order until the transfer is ended by returning CS#
high. This hybrid of a wrapped burst followed by a linear burst starting at the beginning of the next burst group, allows multiple
sequential address cache lines to be filled in a single access. The first cache line is filled starting at the critical word. Then the next
sequential line in memory can be read in to the cache while the first line is being processed.

### Table 5.5  CR0[2] Control of Wrapped Burst Sequence

| Bit | Default Value | Name |
|---|---|---|
| 2 | Hybrid Burst Enable 1 CR[2]= 0: Wrapped burst sequences to CR[2]= 1: Wrapped burst sequences in | follow hybrid burst sequencing legacy wrapped burst manner |

20

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 21 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

.

### Table 5.6  Example Wrapped Burst Sequences

| Burst Selection CA[45] CR0[2:0] |  |  | Burst Type | Wrap Boundary (bytes) |  |  | Start Address (Hex) |  | Address Sequence (Hex) (Words) |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 000 |  | Hybrid 128 | 128 once Linear | Wrap then | XXXXXX03 |  | 03, 04, 05, 06, 07, 08, 16, 17, 18, 19, 1A, 1B, 29, 2A, 2B, 2C, 2D, 2E, 3C, 3D, 3E, 3F, 00, 01, (wrap complete, now linear group) 40, 41, 42, 43, 44, 45, | 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 1C, 1D, 1E, 1F, 20, 21, 22, 23, 24, 25, 26, 27, 28, 2F, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 02 beyond the end of the initial 128 byte wrap 46, 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| 0 | 001 | Hybrid | 64 | 64 once Linear | Wrap then | XXXXXX03 |  | 03, 04, 05, 06, 07, 08, 16, 17, 18, 19, 1A, 1B, (wrap complete, now linear group) 20, 21, 22, 23, 24, 25, | 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 1C, 1D, 1E, 1F, 00, 01, 02, beyond the end of the initial 64 byte wrap 26, 27, 28, 29, 2A, 2B, 2C, 2D, 2E, 2F, 30, 31, ... |
| 0 | 001 | Hybrid | 64 | 64 once Linear | Wrap then | XXXXXX2E |  | 2E, 2F, 30, 31, 32, 33, 21, 22, 23, 24, 25, 26, (wrap complete, now linear group) 40, 41, 42, 43, 44, 45, | 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 27, 28, 29, 2A, 2B, 2C, 2D, beyond the end of the initial 64 byte wrap 46, 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| 0 | 010 | Hybrid | 16 | 16 once Linear | Wrap then | XXXXXX02 |  | 02, 03, 04, 05, 06, 07, (wrap complete, now linear group) 08, 09, 0A, 0B, 0C, 0D, | 00, 01, beyond the end of the initial 16 byte wrap 0E, 0F, 10, 11, 12, ... |
| 0 | 010 | Hybrid | 16 | 16 once Linear | Wrap then | XXXXXX0C |  | 0C, 0D, 0E, 0F, 08, 09, (wrap complete, now linear group) 10, 11, 12, 13, 14, 15, | 0A, 0B, beyond the end of the initial 16 byte wrap 16, 17, 18, 19, 1A, ... |
| 0 | 011 | Hybrid | 32 | 32 once Linear | Wrap then | XXXXXX0A |  | 0A, 0B, 0C, 0D, 0E, 0F, | 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, ... |
| 0 | 011 | Hybrid | 32 | 32 once Linear | Wrap then | XXXXXX1E |  | 1E, 1F, 10, 11, 12, 13, | 14, 15, 16, 17, 18, 19, 1A, 1B, 1C, 1D, ... |
| 0 | 100 | Wrap | 128 |  | 128 | XXXXXX03 |  | 03, 04, 05, 06, 07, 08, 16, 17, 18, 19, 1A, 1B, 29, 2A, 2B, 2C, 2D, 2E, 3C, 3D, 3E, 3F, 00, 01, | 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 1C, 1D, 1E, 1F, 20, 21, 22, 23, 24, 25, 26, 27, 28, 2F, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 02, ... |
| 0 | 101 | Wrap | 64 |  | 64 | XXXXXX03 |  | 03, 04, 05, 06, 07, 08, 16, 17, 18, 19, 1A, 1B, | 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 1C, 1D, 1E, 1F, 00, 01, 02, ... |
| 0 | 101 | Wrap | 64 |  | 64 | XXXXXX2E |  | 2E, 2F, 30, 31, 32, 33, 21, 22, 23, 24, 25, 26, | 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 27, 28, 29, 2A, 2B, 2C, 2D, ... |
| 0 | 110 | Wrap | 16 |  | 16 | XXXXXX02 |  | 02, 03, 04, 05, 06, 07, | 00, 01, ... |
| 0 | 110 | Wrap | 16 |  | 16 | XXXXXX0C |  | 0C, 0D, 0E, 0F, 08, 09, | 0A, 0B, ... |
| 0 | 111 | Wrap | 32 |  | 32 | XXXXXX0A |  | 0A, 0B, 0C, 0D, 0E, 0F, | 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, ... |
| 0 | 111 | Wrap | 32 |  | 32 | XXXXXX1E |  | 1E, 1F, 10, 11, 12, 13, | 14, 15, 16, 17, 18, 19, 1A, 1B, 1C, 1D, ... |
| 1 | XXX |  | Linear | Linear Burst |  | XXXXXX03 |  | 03, 04, 05, 06, 07, 08, 16, 17, 18, ... | 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, |

21

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 22 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

5.2.1.3
Initial Latency

Memory Space read and write transactions or Register Space read transactions require some initial latency to open the row selected
by the Command-Address. This initial latency is tACC. The number of latency clocks needed to satisfy tACC depends on the
HyperBus frequency and can vary from 3 to 8 clocks. The value in CR0[7:4] selects the number of clocks for initial latency. The
default value is 6 clocks, allowing for operation up to a maximum frequency of 166MHz prior to the host system setting a lower initial
latency value that may be more optimal for the system.

In the event a distributed refresh is required at the time a Memory Space read or write transaction or Register Space read
transaction begins, the RWDS signal goes high during the Command-Address to indicate that an additional initial latency is being
inserted to allow a refresh operation to complete before opening the selected row.

Register Space write transactions always have zero initial latency. RWDS may be High or Low during the Command-Address
period. The level of RWDS during the Command-Address period does not affect the placement of register data immediately after the
Command-Address, as there is no initial latency needed to capture the register data. A refresh operation may be performed in the
memory array in parallel with the capture of register data.

5.2.1.4
Fixed Latency

A configuration register option bit CR0[3] is provided to make all Memory Space read and write transactions or Register Space read
transactions require the same initial latency by always driving RWDS high during the Command-Address to indicate that two initial
latency periods are required. This fixed initial latency is independent of any need for a distributed refresh, it simply provides a fixed
(deterministic) initial latency for all of these transaction types. The fixed latency option may simplify the design of some HyperBus
memory controllers or ensure deterministic transaction performance. Fixed latency is the default POR or reset configuration. The
system may clear this configuration bit to disable fixed latency and allow variable initial latency with RWDS driven high only when
additional latency for a refresh is required.

5.2.1.5
Drive Strength

DQ signal line loading, length, and impedance vary depending on each system design. Configuration register bits CR0[14:12]
provide a means to adjust the DQ[7:0] and RWDS signal output impedance to customize the output signal impedance to the
system conditions to minimize high speed signal behaviors such as overshoot, undershoot, and ringing. The default POR or reset
configuration value is 000b to select the mid point of the available output impedance options.

The impedance values shown are typical for both pull-up and pull-down drivers at typical silicon process conditions, nominal
operating voltage (1.8Vor 3V) and 50°C. The impedance values may vary by up to ±80% from the typical values depending on the
Process, Voltage, and Temperature (PVT) conditions. Impedance will increase with slower process, lower voltage, or higher
temperature. Impedance will decrease with faster process, higher voltage, or lower temperature.

Each system design should evaluate the data signal integrity across the operating voltage and temperature ranges to select the best
drive strength settings for the operating conditions.

5.2.1.6
Deep Power Down

When the HyperRAM device is not needed for system operation, it may be placed in a very low power consuming mode called Deep
Power Down (DPD), by writing 0 to CR0[15]. When CR0[15] is cleared to 0, the device enters the DPD mode within tDPDIN time and
all refresh operations stop. The data in RAM is lost, (becomes invalid without refresh) during DPD mode. The next access to the
device driving CS# Low then High, POR, or a reset will cause the device to exit DPD mode. Returning to Standby mode requires
tDPDOUT time.

22

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 23 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 5.2.2 Configuration Register 1

Configuration Register 1 (CR1) is used to define the distributed refresh interval for this HyperRAM device. The core DRAM array
requires periodic refresh of all bits in the array. This can be done by the host system by reading or writing a location in each row
within a specified time limit. The read or write access copies a row of bits to an internal buffer. At the end of the access the bits in the
buffer are written back to the row in memory, thereby recharging (refreshing) the bits in the row of DRAM memory cells.

However, the host system generally has better things to do than to periodically read every row in memory and keep track that each
row is visited within the required refresh interval for the entire memory array. HyperRAM devices include self-refresh logic that will
refresh rows automatically so that the host system is relieved of the need to refresh the memory. The automatic refresh of a row can
only be done when the memory is not being actively read or written by the host system. The refresh logic waits for the end of any
active read or write before doing a refresh, if a refresh is needed at that time. If a new read or write begins before the refresh is
completed, the memory will drive RWDS high during the Command-Address period to indicate that an additional initial latency time
is required at the start of the new access in order to allow the refresh operation to complete before starting the new access.

The required refresh interval for the entire memory array varies with temperature as shown in Table 5.7, Array Refresh Window per
Temperature on page 23. This is the time within which all rows must be refreshed. Refresh of all rows could be done as a single
batch of accesses at the beginning of each interval, in groups (burst refresh) of several rows at a time, spread throughout each
interval, or as single row refreshes evenly distributed throughout the interval. The self-refresh logic distributes single row refresh
operations throughout the interval so that the memory is not busy doing a burst of refresh operations for a long period, such that the
burst refresh would delay host access for a long period.

### Table 5.7  Array Refresh Interval per Temperature

| Device Temperature (°C) |  | Array Refresh | Window (ms) | Array | Rows | Recommended | tCMS (µs) |
|---|---|---|---|---|---|---|---|
| 85 |  |  | 64 |  | 8192 |  | 4 |
| 105 |  |  | 16 |  | 8192 |  | 1 |
| Table 5.8 Configuration Register | 1 | Bit Assignments |  |  |  |  |  |
| CR1 Bit | Function |  |  |  | Settings (Binary) |  |  |
| 15-2 | Reserved |  | 000000h — Reserved (default) Reserved for Future Use. cleared to 0 for future compatibility. | When | writing this register, | these bits | should be |
| 1-0 Distributed | Refresh | Interval | 10b — default 4 µs for Industrial 1 µs for Industrial 11b — 1.5 times default 00b — 2 times default 01b — 4 times default |  | temperature range devices Plus temperature range | devices |  |

23

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 24 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

The distributed refresh method requires that the host does not do burst transactions that are so long as to prevent the memory from
doing the distributed refreshes when they are needed. This sets an upper limit on the length of read and write transactions so that

the refresh logic can insert a refresh between transactions. This limit is called the CS# low maximum time (tCSM). The tCSM value is
determined by the array refresh interval divided by the number of rows in the array, then reducing this calculation by half to ensure
that a distributed refresh interval cannot be entirely missed by a maximum length host access starting immediately before a
distributed refresh is needed. Because tCSM is set to half the required distributed refresh interval, any series of maximum length host
accesses that delay refresh operations will be catching up on refresh operations at twice the rate required by the refresh interval
divided by the number of rows.

The host system is required to respect the tCSM value by ending each transaction before violating tCMS. This can be done by host
memory controller logic splitting long transactions when reaching the tCSM limit, or by host system hardware or software not
performing a single read or write transaction that would be longer than tCSM.

As noted in Table 5.7, Array Refresh Window per Temperature on page 23 the array refresh interval is longer at lower temperatures
such that tCSM could be increased to allow longer transactions. The host system can either use the tCSM value from the table for the
maximum operating temperature or, may determine the current operating temperature from a temperature sensor in the system in
order to set a longer distributed refresh interval.

The host system may also effectively increase the tCSM value by explicitly taking responsibility for performing all refresh and doing
burst refresh reading of multiple sequential rows in order to catch up on distributed refreshes missed by longer transactions.

24

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 25 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# HyperRAM Hardware Interface

For the general description of the HyperBus hardware interface of HyperFlash memories refer to the
HyperBus Specification. The following section describes HyperRAM device dependent aspects of hardware
interface.
6.
Interface States

## 6.1 Power Conservation Modes

## 6.1.1 Interface Standby

Standby is the default, low power, state for the interface while the device is not selected by the host for data
transfer (CS#= High). All inputs, and outputs other than CS# and RESET# are ignored in this state.

## 6.1.2 Active Clock Stop

The Active Clock Stop mode reduces device interface energy consumption to the ICC6 level during the data
transfer portion of a read or write operation. The device automatically enables this mode when clock remains
stable for tACC + 30 ns. While in Active Clock Stop mode, read data is latched and always driven onto the
data bus.

Active Clock Stop mode helps reduce current consumption when the host system clock has stopped to pause
the data transfer. Even though CS# may be Low throughout these extended data transfer cycles, the memory
device host interface will go into the Active Clock Stop current level at tACC + 30 ns. This allows the device to
transition into a lower current mode if the data transfer is stalled. Active read or write current will resume once
the data transfer is restarted with a toggling clock. The Active Clock Stop mode must not be used in violation
of the tCSM limit. CS# must go high before tCSM is violated.

## 6.1.3 Deep Power Down

In the Deep Power Down (DPD) mode, current consumption is driven to the lowest possible level (iDPD). DPD
mode is entered by writing a 0 to CR0[15]. The device reduces power within tDPDIN time and all refresh
operations stop. The data in Memory Space is lost, (becomes invalid without refresh) during DPD mode. The
next access to the device, driving CS# Low then High, will cause the device to exit DPD mode. A read or write
transaction used to drive CS# Low then High to exit DPD mode is a dummy transaction that is ignored by the
device. Also, POR, or a hardware reset will cause the device to exit DPD mode. Only the CS# and RESET#
signals are monitored during DPD mode. Returning to Standby mode following a dummy transaction or reset
requires tDPDOUT time. Returning to Standby mode following a POR requires tVCS time, as with any other
POR. Following the exit from DPD due to any of these events, the device is in the same state as following
POR.

### Table 6.1  Deep Power Down Timing Parameters

| Parameter |  | Description | Min | Max |  | Unit |
|---|---|---|---|---|---|---|
| tDPDIN | Deep Power Down CR0[15]=0 | register write to DPD power level | 10 |  | - | µs |
| tDPDCSL | Length of CS# Low period to | cause an exit from Deep Power Down | 200 |  | - | ns |
| tDPDOUT | CS# Low then High to Standby | wakeup time | - | 150 |  | µs |

25

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 26 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Figure 6.1  Deep Power Down Entry Timing

CS#

CK#
,
CK

DQ[7:0]

tDPDIN

Phase
Write Command-Address
CR Value
Enter DPD Mode
DPD mode

### Figure 6.2  Deep Power Down CS# Exit Timing

tDPDCSL

CS#

CK#
,
CK

DQ[7:0]

tDPDOUT

Phase
DPD mode
Dummy Transaction to Exit DPD
Exit DPD Mode
Standby
New Transaction

26

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 27 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 7. HyperRAM Connection Descriptions

Following is the description for other package connectors.

## 7.1 Other Connectors Summary

### Table 7.1  Other Connectors Summary

| Symbol |  | Type |  | Description |
|---|---|---|---|---|
| VCC | Power | Supply | Core Power. |  |
| VCCQ | Power | Supply | Input/Output Power. |  |
| VSS | Power | Supply | Core Ground. |  |
| VSSQ | Power | Supply | Input/Output Ground. |  |
| NC | No Connect |  | Not Connected internally. The signal/ball location of a routing channel. | may be used in Printed Circuit Board (PCB) as part |
| RFU | No Connect |  | Reserved for Future Use. May or may not be left unconnected and unused by PCB routing used by a signal in the future. | connected internally, the signal/ball location should be channel for future compatibility. The signal/ball may be |
| DNU | Reserved |  | Do Not Use. Reserved for use by ISSI. The signal/ball left open on the PCB. | is connected internally. The signal/ball must be |

27

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 28 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 7.2 HyperRAM Block Diagram

### Figure 7.1  HyperRAM Connections, Including Optional Signals

VCC
VCCQ

VCC
VCCQ

## Master Slave 0

CS0#

CS#

CK

CK#
CK

CK#

DQ[7:0]

DQ[7:0]

RWDS

RWDS

CS1#

RESET#

RESET#

VSS
VSSQ

VSS
VSSQ

VCC
VCCQ

## Slave 1

CS#

CK#
CK

DQ[7:0]

RWDS

RESET#

VSS
VSSQ

28

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 29 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 8. Interface States

The Interface States table describes the required value of each signal for each interface state.

### Table 8.1  Interface States

| Interface State |  | VCC / VCCQ | CS# |  | CK, | CK# |  | D7-D0 |  | RWDS |  |  | RESET# |  |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Power-On (Cold) Reset |  VCC | / VCCQ min |  | X |  | X |  | High-Z |  | High-Z |  |  |  | X |
| Hardware (Warm) Reset |  VCC | / VCCQ min |  | X |  | X |  | High-Z |  | High-Z |  |  |  | L |
| Interface Standby |  VCC | / VCCQ min |  | H |  | X |  | High-Z |  | High-Z |  |  |  | H |
| Command-Address |  VCC | / VCCQ min |  | L |  | T | Master |  | Output Valid |  |  | X |  | H |
| Read Initial Access Latency (data bus turn around period) |  VCC | / VCCQ min |  | L |  | T |  | High-Z |  |  |  | L |  | H |
| Write Initial Access Latency (RWDS turn around period) |  VCC | / VCCQ min |  | L |  | T |  | High-Z |  | High-Z |  |  |  | H |
| Read data transfer |  VCC | / VCCQ min |  | L |  | T Slave |  |  | Output Valid | Output | Slave Valid X | or T |  | H |
| Write data transfer with Initial Latency |  VCC | / VCCQ min |  | L |  | T | Master |  | Output Valid | Master Output | Valid X | or T |  | H |
| Write data transfer without Initial Latency (2) |  VCC | / VCCQ min |  | L |  | T | Master |  | Output Valid | Output High-Z | Slave L | or |  | H |
| Active Clock Stop (3) |  VCC | / VCCQ min |  | L | Idle |  | Master Output | High-Z | or Slave Valid or |  |  | X |  | H |
| Deep Power Down(3) |  VCC | / VCCQ min |  | H | X | or T | Slave | High-Z | Output | High-Z |  |  |  | H |
| Legend L = VIL H = VIH X = either VIL or VIH L/H = rising edge H/L = falling edge T = Toggling during information transfer Idle = CK is low and CK# is high. Valid = all bus signals have stable L or H level Notes: 1. When the RSTO# or INT# open-drain outputs are 2. Writes without initial latency (with zero initial latency), Command-Address period to indicate whether extended device may continue to drive RWDS Low or may not use RWDS as a data mask function. All bytes 3. Active Clock Stop is described in Active Clock Stop | High-Z take of | the pull-up resistance do not have a turn around latency is required. Since RWDS to High-Z. The master write data are written (full on page 25. DPD is described | word | provided by period for master write must not writes). in Deep | the RWDS. data drive Power | master or an external The HyperRAM immediately RWDS during Down on page | device follows Writes 25. |  | resistor will pull the will always drive the Command-Address with zero latency. |  | signal Writes | to High. RWDS during period with zero | the the HyperRAM latency | do |

29

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 30 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 9. Electrical Specifications

## 9.1 Absolute Maximum Ratings

## 65 °C to +150 °C Storage Temperature Plastic Packages

Ambient Temperature with Power Applied
65°C to +115 °C

Voltage with Respect to Ground

## 0.5V to +(VCC + 0.5V)

All signals

Output Short Circuit Current (2)

100 mA
0.5V to +4.0V

VCC

### Notes:

No more than one output may be shorted to ground at a time. Duration of the short circuit should not be greater than one
second.

1.

2.

Stresses above those listed under Absolute Maximum Ratings may cause permanent damage to the device. This is a
stress rating only; functional operation of the device at these or any other conditions above those indicated in the
operational sections of this data sheet is not implied. Exposure of the device to absolute maximum rating conditions for
extended periods may affect device reliability.

## 9.2 Latchup Characteristics Table 9.1  Latchup Specification

| Description | Min |  | Max | Unit |  |
|---|---|---|---|---|---|
| Input voltage with respect to VSSQ on all input only connections |  1.0 | VCCQ | + 1.0 |  | V |
| Input voltage with respect to VSSQ on all I/O connections | 1.0 | VCCQ | + 1.0 |  | V |
| VCCQ Current | 100 |  | +100 | mA |  |
| Note: 1. Excludes power supplies VCC/VCCQ. Test conditions: VCC = VCCQ = 1.8 V, one connection | at a time tested, connections |  | not being tested are at VSS. |  |  |

30

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 31 -->

9.3
Operating Ranges
Operating ranges define those limits between which the functionality of the device is guaranteed.
9.3.1
Temperature Ranges
9.3.2
Power Supply Voltages
Parameter
Symbol
Device
Spec
Unit
Min
Max
Ambient Temperature
TA
Industrial (I)
–40
85
°C
VCC and VCCQ
1.7v to 1.95V
VCC and VCCQ
2.7V to 3.6V
IS66WVH32M8DALL/BLL 
IS67WVH32M8DALL/BLL
 
Input Signal Overshoot
Figure 9.1  Maximum Negative Overshoot Waveform
Figure 9.2  Maximum Positive Overshoot Waveform
VSSQ to VCCQ
- 1.0V
≤20 ns
VCCQ + 1.0V
≤20 ns
VSSQ to VCCQ
Minimum DC voltage on input or I/O signal is −1.0V. During voltage transitions, input or I/O signals may undershoot VSS 
to -1.0V for periods of up to 20 ns. See Figure 9.1. Maximum DC voltage on input or I/O signals is VCC +1.0V. During 
voltage transitions, input or I/O signals may overshoot to VCC +1.0V for periods up to 20 ns. See Figure 9.2.
9.3.3
–
Automotive,  Grade A1
–40
85
Automotive,  Grade A2
105
40
Integrated Silicon Solution, Inc. - www.issi.com 
Rev. A7 
11/21/2024
31

<!-- page 32 -->

Notes:
1. Not 100% tested.
2. RESET# low initiates exits from DPD mode and initiates the draw of ICC5 reset current, making ILI during Reset# Low insignificant.
9.4
DC Characteristics
Table 9.2  DC Characteristics (CMOS Compatible)
Parameter
Description
Test Conditions
Min
Typ (1)
Max
Unit
ILI
Input Leakage Current
3V Device Reset Signal High Only
VIN = VSS to VCC,
VCC = VCC max


µA
ILI
Input Leakage Current
1.8V Device Reset Signal High Only
VIN = VSS to VCC,
VCC = VCC max


µA
ILI
Input Leakage Current
3V Device Reset Signal Low Only (2)
VIN = VSS to VCC,
VCC = VCC max


+20.0
µA
ILI
Input Leakage Current
1.8V Device Reset Signal Low Only (2)
VIN = VSS to VCC,
VCC = VCC max 


+20.0
µA
ICC1
VCC Active Read Current
CS# = VIL, @200 MHz, VCC = 1.9V
mA

CS# = VIL, @166 MHz, VCC = 3.6V

mA
ICC2
VCC Active Write Current
CS# = VIL, @200 MHz, VCC = 1.9V
mA

CS# = VIL, @166 MHz, VCC = 3.6V

mA
ICC4I
VCC Standby Current 
(−40 °C to +85 °C)
CS#, VCC = VCC max,

750
800
µA
ICC4IP
VCC Standby Current 
(−40 °C to +105 °C)
CS#, VCC = VCC max

750
1200
µA
ICC5
Reset Current
CS# = VIH, RESET# = VIL, 
VCC = VCC max

mA
ICC6I
Active Clock Stop Current 
(−40 °C to +85 °C)
CS# = VIL, RESET# = VIH, 
VCC = VCC max

mA
ICC6IP
Active Clock Stop Current  
(−40 °C to +105 °C)
CS# = VIL, RESET# = VIH, 
VCC = VCC max

mA
ICC7
VCC Current during power up (1)
CS#, = H, VCC = VCC max, 
VCC = VCCQ = 1.95V or 3.6V (Note 1)


mA
IDPD
Deep Power Down Current 3V 85°C
CS#, VCC = 3.6V, TA = 85 °C


µA
IDPD
Deep Power Down Current 1.8V 85°C
CS#, VCC = 1.9V, TA = 85 °C 


µA
IDPD
Deep Power Down Current 3V 105°C
CS#, VCC = 3.6V, TA = 105 °C


µA
IDPD
Deep Power Down Current 1.8V 105°C CS#, VCC = 1.9V, TA = 105 °C 


µA
VIL
Input Low Voltage
-0.5
-
0.3 x 
VCC
V
VIH
Input High Voltage
0.7 x 
VCC
-
VCC + 
0.3
V
VOL
Output Low Voltage
IOL = 100 µA for DQ[7:0]
-
-
0.15 x 
VCC
V
VOH
Output High Voltage
IOH = 100 µA for DQ[7:0]
0.85 x 
VCC
V
-
-
IS66WVH32M8DALL/BLL 
IS67WVH32M8DALL/BLL
25
25
25
30
25
5
10
5
10
5
10
40
20
30
30
50
-10.0
-5.0
30
30
30
Integrated Silicon Solution, Inc. - www.issi.com 
Rev. A7 
11/21/2024
32

<!-- page 33 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 9.4.1 Capacitance Characteristics

### Table 9.3  1.8V Capacitive Characteristics

| Description | Parameter |  |  | Min |  |  | Max |  |  | Unit |  |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Input Capacitance (CK, CK#, CS#) |  | CI |  | 3 |  |  | 4.5 |  |  |  | pF |
| Delta Input Capacitance (CK, CK#) |  | CID |  |  |  |  | 0.25 |  |  |  | pF |
| Output Capacitance (RWDS) |  | CO |  | 3 |  |  |  | 4 |  |  | pF |
| IO Capacitance (DQx) |  | CIO |  | 3 |  |  |  | 4 |  |  | pF |
| IO Capacitance Delta (DQx) | CIOD |  |  |  |  |  | 0.5 |  |  |  | pF |
| Notes: 1. These values are guaranteed by design and are tested on a sample basis only. 2. Contact capacitance is measured according to JEP147 procedure for measuring capacitance applied and all other signals (except the signal under test) floating. DQ’s should be in the high 3. Note that the capacitance values for the CK, CK#, RWDS and DQx signals must have similar time matching in the system. The capacitance value for CS# is not as critical because there are (Low) and data being presented on the DQs bus. Table 9.4 3.0V Capacitive Characteristics | using impedance capacitance no | a vector network state. values to allow critical timings between | analyzer. | VCC, VCCQ for signal propagation CS# going | active | are |  |  |  |  |  |
| Description Parameter |  | Min |  |  | Max |  |  | Unit |  |  |  |
| Input Capacitance (CK, CS#) | CI |  | 3 |  | 4.5 |  |  |  | pF |  |  |
| Output Capacitance (RWDS) | CO |  | 3 |  |  | 4 |  |  | pF |  |  |
| IO Capacitance (DQx) | CIO |  | 3 |  |  | 4 |  |  | pF |  |  |
| IO Capacitance Delta (DQx) CIOD |  |  |  |  | 0.5 |  |  |  | pF |  |  |
| Notes: 1. These values are guaranteed by design and are tested on a sample basis only. 2. Contact capacitance is measured according to JEP147 procedure for measuring capacitance applied and all other signals (except the signal under test) floating. DQ’s should be in the high 3. The capacitance values for the CK, RWDS and DQx signals must have similar capacitance values in the system. The capacitance value for CS# is not as critical because there are no critical timings being presented on the DQs bus. 9.5 Power-Up Initialization | using impedance | a vector network state. to allow for signal between CS# going | analyzer. propagation active | VCC, VCCQ time matching (Low) and |  | are data |  |  |  |  |  |

HyperRAM products include an on-chip voltage sensor used to launch the power-up initialization process. VCC and VCCQ must be
applied simultaneously. When the power supply reaches a stable level at or above VCC(min), the device will require tVCS time to
complete its self-initialization process.

The device must not be selected during power-up. CS# must follow the voltage applied on VCCQ until VCC (min) is reached during
power-up, and then CS# must remain high for a further delay of tVCS. A simple pull-up resistor from VCCQ to Chip Select (CS#) can
be used to insure safe and proper power-up.

If RESET# is Low during power up, the device delays start of the tVCS period until RESET# is High. The tVCS period is used primarily
to perform refresh operations on the DRAM array to initialize it.

When initialization is complete, the device is ready for normal operation.

33

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 34 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Figure 9.3  Power-up with RESET# High

Vcc_VccQ

VCC Minimum

Device
Access Allowed

tVCS

CS#

RESET#

### Figure 9.4  Power-up with RESET# Low

Device
Access Allowed

Vcc_VccQ

VCC Minimum

CS#

tVCS

RESET#

### Table 9.5  Power Up and Reset Parameters

| Parameter |  | Description | Min | Max | Unit |  |
|---|---|---|---|---|---|---|
| VCC | 1.8V VCC Power Supply |  | 1.7 | 1.95 |  | V |
| VCC | 3V VCC Power Supply |  | 2.7 | 3.6 |  | V |
| tVCS | VCC and VCCQ  minimum access | and RESET# High to first |  | 150 |  | µs |
| Notes: 1. Bus transactions (read and 2. VCCQ must be the same voltage 3. VCC ramp rate may be non-linear. | write) are not allowed during as VCC. | the power-up reset time (tVCS). |  |  |  |  |

34

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 35 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 9.6 Power Down

HyperRAM devices are considered to be powered-off when the core power supply (VCC) drops below the VCC Lock-Out voltage
(VLKO). During a power supply transition down to the VSS level, VCCQ should remain less than or equal to VCC.

At the VLKO level, the HyperRAM device will have lost configuration or array data.

VCC must always be greater than or equal to VCCQ (VCC  VCCQ).

During Power-Down or voltage drops below VLKO, the core power supply voltages must also drop below VCC Reset (VRST) for a
Power Down period (tPD) for the part to initialize correctly when the power supply again rises to VCC minimum. See Figure 9.5.

If during a voltage drop the VCC stays above VLKO the part will stay initialized and will work correctly when VCC is again above VCC
minimum. If VCC does not go below and remain below VRST for greater than tPD, then there is no assurance that the POR process
will be performed. In this case, a hardware reset will be required ensure the HyperBus device is properly initialized.

### Figure 9.5  Power Down or Voltage Drop

VCC (Max)

| VCC | No Device Access Allowed |
|---|---|
|  | Device Access tVCS Allowed |

VCC (Min)

VLKO

VRST

t

PD

Time

The following section describes HyperRAM device dependent aspects of power down specifications.

### Table 9.6  1.8V Power-Down Voltage and Timing

| Symbol |  | Parameter | Min | Max |  | Unit |  |
|---|---|---|---|---|---|---|---|
| VCC | VCC Power Supply |  | 1.7 | 1.95 |  |  | V |
| VLKO | VCC Lock-out below which re-initialization | is required | 1.7 |  |  |  | V |
| VRST | VCC Low Voltage needed to ensure | initialization will occur | 0.8 |  |  |  | V |
| tPD | Duration of VCC VRST  |  | 30 |  |  |  | µs |
| Note: 1. VCC ramp rate can Table 9.7 3.0V Power-Down | be non-linear. Voltage and Timing |  |  |  |  |  |  |
| Symbol |  | Parameter | Min | Max |  | Unit |  |
| VCC | VCC Power Supply |  | 2.7 | 3.6 |  |  | V |
| VLKO | VCC Lock-out below which re-initialization | is required | 2.7 |  |  |  | V |
| VRST | VCC Low Voltage needed to ensure | initialization will occur | 0.8 |  |  |  | V |
| tPD | Duration of VCC  VRST |  | 50 |  |  |  | µs |
| Note: 1. VCC ramp rate can | be non-linear. |  |  |  |  |  |  |

35

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 36 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 9.7 Hardware Reset

The RESET# input provides a hardware method of returning the device to the standby state.

During tRPH the device will draw ICC5 current. If RESET# continues to be held Low beyond tRPH, the device draws CMOS standby
current (ICC4). While RESET# is Low (during tRP), and during tRPH, bus transactions are not allowed.

A hardware reset will:


cause the configuration registers to return to their default values,


halt self-refresh operation while RESET# is low,


and force the device to exit the Deep Power Down state.

After RESET# returns High, the self-refresh operation will resume. Because self-refresh operation is stopped during RESET# Low,
and the self-refresh row counter is reset to its default value, some rows may not be refreshed within the required array refresh
interval per Table 5.7, Array Refresh Interval per Temperature on page 23. This may result in the loss of DRAM array data during or
immediately following a hardware reset. The host system should assume DRAM array data is lost after a hardware reset and reload
any required data.

### Figure 9.6  Hardware Reset Timing Diagram

tRP

RESET#

tVCS - if RESET# Low > tRP max

tRH

tRPH

CS#

### Table 9.8  Power Up and Reset Parameters

| Parameter |  | Description | Min | Max |  | Unit |
|---|---|---|---|---|---|---|
| tRP | RESET# Pulse Width |  | 200 |  |  | ns |
| tRH | Time between RESET# | (high) and CS# (low) | 200 |  |  | ns |
| tRPH | RESET# Low to CS# | Low | 400 |  |  | ns |

36

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 37 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 10. Timing Specifications

The following section describes HyperRAM device dependent aspects of timing specifications.

## 10.1 Key to Switching Waveforms

## Valid_High_or_Low

## High_to_Low_Transition

## Low_to_High_Transition

## Invalid

## High_Impedance

## 10.2 AC Test Conditions

### Figure 10.1  Test Setup

Device

CL

Under

Test

### Table 10.1.1  Test Specification

| Parameter | All |  | Speeds | Units |  |
|---|---|---|---|---|---|
| Output Load Capacitance, CL |  |  | 20 |  | pF |
| Minimum Input Rise and Fall Slew Rates (Note 1) |  |  | 2.0 | V/ns |  |
| Input Pulse Levels | 0.0-VCCQ |  |  |  | V |
| Input timing measurement reference levels |  | VCCQ/2 |  |  | V |
| Output timing measurement reference levels |  | VCCQ/2 |  |  | V |
| Notes: 1. All AC timings assume an input slew rate of 2V/ns. CK/CK# differential slew rate of at least 4V/ns. 2. Input and output timing is referenced to VCCQ/2 or to the crossing of CK/CK#. |  |  |  |  |  |

### Figure 10.2.1  Input Waveforms and Measurement Levels

VccQ

Input VccQ / 2
Measurement Level
VccQ / 2 Output

Vss

Note:
1. Input timings for the differential CK/CK# pair are measured from clock crossings.

37

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 38 -->

IS66WVH32M8DALL/BLL 
IS67WVH32M8DALL/BLL
10.2.1 CLK Characteristics
Figure 10.2.2 Clock Characteristics
Table 10.1.2 Clock Timings(1, 2)
Notes
1. Clock jitter of ±5% is permitted. 
2. Minimum Frequency (Maximum tCK) is dependent upon maximum CS# LOW time (tCSM), Initial Latency and Burst Length. 
Table 10.1.3 Clock AC/DC Electrical Characteristics(1. 2)
Parameter
Symbol
Min
Max
Unit
DC Input Voltage 
VIN 
–0.3
VCCQ+ 0.3 
V 
DC Input Differential Voltage 
VID(DC)
VCCQ  0.4 
VCCQ+ 0.6 
V 
AC Input Differential Voltage 
VID(AC)
VCCQ  0.6 
VCCQ + 0.6 
V 
AC Differential Crossing Voltage 
VIX 
VCCQ  0.4 
VCCQ x 0.6 
V 
Notes
1. VID is the magnitude of the difference between the input level on CK and the input level on CK#. 
2. The value of VIX is expected to equal VCCQ/2 of the transmitting device and must track variations in the DC level of VCCQ. 
Parameter 
Symbol
200 MHz 
166 MHz 
133 MHz
Unit
Min 
Max 
Min 
Max 
Min 
Max 
CK Period 
tCK 
5.0 
- 
6.0 
- 
7.5 
- 
ns 
CK Half Period - Duty Cycle 
tCKHP 
0.45 
0.55 
0.45 
0.55 
0.45 
0.55 
tCK 
CK Half Period at Frequency 
Min = 0.45tCK Min 
Max = 0.55tCK Min
tCKHP 
2.25 
2.75 
2.7 
3.3 
3.375 
4.125 
ns 
Integrated Silicon Solution, Inc. - www.issi.com 
Rev. A7 
11/21/2024
38

<!-- page 39 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 10.3 AC Characteristics

## 10.3.1 Read Transactions

### Table 10.2  HyperRAM Specific 1.8V Read Timing Parameters

| Parameter | Symbol |  |  | 200 MHz Min | Max |  | Min Min Min | 166 MHz | Max |  | Min Min Min |  | 133 MHz Max |  | Unit |  |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Chip Select High Between Transactions |  | tCSHI |  | 5 |  | – |  | 6 |  | – | 7.5 |  |  | – |  | ns |
| HyperRAM Read-Write Recovery Time |  | tRWR |  | 35 |  |  |  | 36 |  |  | 37.5 |  |  |  |  | ns |
| Chip Select Setup to next CK Rising Edge |  | tCSS |  | 3 |  | – |  | 3 |  | – |  |  | 3 | – |  | ns |
| Data Strobe Valid |  | tDSV |  | – |  | 12 |  | – |  | 12 |  | – |  | 12 |  | ns |
| Input Setup |  | tIS |  | 0.5 |  | – | 0.6 |  |  | – | 0.8 |  |  | – |  | ns |
| Input Hold |  | tIH |  | 0.5 |  | – | 0.6 |  |  | – | 0.8 |  |  | – |  | ns |
| HyperRAM Read Initial Access Time |  | tACC |  | 35 |  |  |  | 36 |  |  | 37.5 |  |  |  |  | ns |
| Clock to DQs Low Z |  | tDQLZ |  | 0 |  | – |  | 0 |  | – |  | 0 |  | – |  | ns |
| CK transition to DQ Valid |  | tCKD |  | 1 | 5.0 |  |  | 1 | 5.5 |  |  | 1 | 5.5 |  |  | ns |
| CK transition to DQ Invalid |  | tCKDI |  | 0 | 4.2 |  |  | 0 | 4.6 |  |  | 0 | 4.5 |  |  | ns |
| Data Valid (tDV min = tCKHP min - tCKD max + tCKDI max) |  | tDV |  | 1.45 |  | – | 1.8 |  |  | – | 2.375 |  |  | – |  | ns |
| CK transition to RWDS valid |  | tCKDS |  | 1 | 5.0 |  |  | 1 | 5.5 |  |  | 1 | 5.5 |  |  | ns |
| RWDS transition to DQ Valid |  | tDSS | -0.40 | +0.40 |  |  | -0.45 | +0.45 |  |  | -0.6 |  | +0.6 |  |  | ns |
| RWDS transition to DQ Invalid |  | tDSH | -0.40 | +0.40 |  |  | -0.45 | +0.45 |  |  | -0.6 |  | +0.6 |  |  | ns |
| Chip Select Hold After CK Falling Edge |  | tCSH |  | 2 |  | – |  | 3 |  | – |  |  | 3 | – |  | ns |
| Chip Select Inactive to RWDS High-Z |  | tDSZ |  | – |  | 6 |  | – |  | 6 |  |  | – | 6 |  | ns |
| Chip Select Inactive to DQ High-Z |  | tOZ |  | – |  | 6 |  | – |  | 6 |  |  | – | 6 |  | ns |
| HyperRAM Chip Select Maximum Low Time: (-40⁰C to 85⁰C) HyperRAM Chip Select Maximum Low Time: (-40⁰C to +105⁰C) |  | tCSM |  | – – | 4.0 1.0 |  |  | – – | 4.0 1.0 |  |  |  | 4.0 – – 1.0 |  |  | us us |
| Refresh Time |  | tRFH |  | 35 |  |  |  | 36 |  |  | 37.5 |  |  |  |  | ns |

39

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 40 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Table 10.3  HyperRAM Specific 3.0V Read Timing Parameters

| Parameter | Symbol |  |  | 200 MHz Min Max |  | Min Min Min | 166 MHz | Max | Min Min Min | 133 MHz Max |  | Unit |  |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Chip Select High Between Transactions |  | tCSHI |  | 5 | – |  | 6 | – |  | 7.5 | – |  | ns |
| HyperRAM Read-Write Recovery Time |  | tRWR |  | 35 |  |  | 36 |  | 37.5 |  |  |  | ns |
| Chip Select Setup to next CK Rising Edge |  | tCSS |  | 3 | – |  | 3 | – |  | 3 | – |  | ns |
| Data Strobe Valid |  | tDSV |  | – | 12 |  | – | 12 |  | – | 12 |  | ns |
| Input Setup |  | tIS |  | 0.5 | – | 0.6 |  | – |  | 0.8 | – |  | ns |
| Input Hold |  | tIH |  | 0.5 | – | 0.6 |  | – |  | 0.8 | – |  | ns |
| HyperRAM Read Initial Access Time |  | tACC |  | 35 |  |  | 36 |  | 37.5 |  |  |  | ns |
| Clock to DQs Low Z |  | tDQLZ |  | 0 | – |  | 0 | – |  | 0 | – |  | ns |
| CK transition to DQ Valid |  | tCKD |  | 1 6.5 |  |  | 1 | 7 |  | 1 | 7 |  | ns |
| CK transition to DQ Invalid |  | tCKDI |  | 0.5 5.7 |  | 0.5 | 5.6 |  |  | 0.5 | 5.6 |  | ns |
| Data Valid (tDV min = tCKHP min - tCKD max + tCKDI max) |  | tDV |  | 1.45 | – | 1.3 |  | – | 1.975 |  | – |  | ns |
| CK transition to RWDS valid |  | tCKDS |  | 1 6.5 |  |  | 1 | 7 |  | 1 | 7 |  | ns |
| RWDS transition to DQ Valid |  | tDSS | -0.40 | +0.40 |  | -0.45 | +0.45 |  | -0.6 |  | +0.6 |  | ns |
| RWDS transition to DQ Invalid |  | tDSH | -0.40 | +0.40 |  | -0.45 | +0.45 |  | -0.6 |  | +0.6 |  | ns |
| Chip Select Hold After CK Falling Edge |  | tCSH |  | 2 | – |  | 3 | – |  | 3 | – |  | ns |
| Chip Select Inactive to RWDS High-Z |  | tDSZ |  | – | 6 |  | – | 6 |  | – | 6 |  | ns |
| Chip Select Inactive to DQ High-Z |  | tOZ |  | – | 6 |  | – | 6 |  | – | 6 |  | ns |
| HyperRAM Chip Select Maximum Low Time: (-40⁰C to 85⁰C) HyperRAM Chip Select Maximum Low Time: (-40⁰C to +105⁰C) |  | tCSM |  | 4.0 – – 1.0 |  |  | – – | 4.0 1.0 |  | – – | 4.0 1.0 |  | us us |
| Refresh Time |  | tRFH |  | 35 |  |  | 36 |  | 37.5 |  |  |  | ns |

### Figure 10.3  Read Timing Diagram — No Additional Latency Required

tCSHI

tCSM

CS#

tCSS

tCSH

tRWR =Read Write Recovery
tACC = Access

tCSS

CK, CK#

4 cycle latency

tDSV

tCKDS

tDSZ

High = 2x Latency Count
Low =  1x Latency Count

RWDS

tOZ
tDSS

tCKD

tIS
tIH

tDQLZ

tDSH

Dn
A

Dn
B

Dn+1
A

Dn+1
B

DQ[7:0]

47:40 39:32 31:24 23:16 15:8
7:0

Command-Address

RWDS and Data
are edge aligned

Memory drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

40

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 41 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

### Figure 10.4 Read Timing Diagram - With Additional Latency Required

CS#

Additional Latency
tACC = Access

tRWR = Read Write Recovery

CK, CK#

tDSV

4 cycle latency 1
4 cycle latency 2

tCKDS
tCKDS

RWDS

High = 2x Latency Count
Low = 1x Latency Count

tCKD

Dn+1

47:40  39:32  31:24  23:16  15:8      7:0
Dn

Dn

Dn+1

DQ[7:0]

B

A

B

A

Command-Address

Memory drives DQ[7:0] and RWDS

Host drives DQ[7:0] and Memory drives RWDS

### Figure 10.5 Read Timing Diagram - Data Valid Timing

CS#

tCSS

tCSHS

tCKHP

CK
CK#

tCKDS

tDSZ

RWDS

tDSS

tCKD

tCKDI

tDQLZ

tOZ
tDV

tCKD

tDSH

Dn
A

Dn
B

Dn+1

Dn+1

DQ[7:0]

A

B

RWDS and Data are driven by the memory

41

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 42 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 10.3.2 Write Transactions

### Table 10.4  1.8V, 3.0V Write Timing Parameters

| Parameter | Symbol |  | 200 MHz Min Max |  | 166 MHz Min Max |  | 133 MHz Min Min M in Max |  | Unit |
|---|---|---|---|---|---|---|---|---|---|
| Read-Write Recovery Time |  | tRWR | 35 |  | 36 |  | 37.5 |  | ns |
| Access Time |  | tACC | 35 |  | 36 |  | 37.5 |  | ns |
| Refresh Time |  | tRFH | 35 |  | 36 |  | 37.5 |  | ns |
| Chip Select Maximum Low Time (-40⁰C to 85⁰C) Chip Select Maximum Low Time (-40⁰C to +105⁰C) |  | tCSM |  4.0  1.0 |  |  4.0  1.0 |  |  4.0  1.0 |  | µs µs |

### Figure 10.6  Write Timing Diagram — No Additional Latency

tCSHI
tCSM

CS#

tCSS

tCSH

tRWR =Read Write Recovery
tACC = Access

tCSS

CK, CK#

4 cycle latency

tDSV

tIS

tDSZ

tIH

tDMV

High = 2x Latency Count
Low =  1x Latency Count

RWDS

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

DQ[7:0]

47:40
39:32
31:24
23:16
15:8
7:0

Command-Address

CK and Data
are center aligned

Host drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

42

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 43 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 10.4 Timing reference levels

### Figure 10.7 DDR input timing reference levels

tCK

VCCQ

CK, CK#

VSSQ

tIS
tIH
tIS
tIH

VCCQ

VIH(min)

DQ[7:0]

VIL(max)

VSSQ

### Figure 10.8 DDR output timing reference levels

tSCK

VCCQ

RWDS

VSSQ

tDSS

tDSH

VCCQ

VOH(min)

DQ[7:0]

VOL(max)

VSSQ

43

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 44 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 11. Physical Interface

## 11.1 FBGA 24-Ball 5 x 5 Array Footprint

HyperRAM devices are provided in Fortified Ball Grid Array (FBGA), 1 mm pitch, 24-ball, 5 x 5 ball array footprint, with 6mm x 8mm
body.

### Figure 11.1  24-Ball FBGA, 6 x 8 mm, 5x5 Ball Footprint, Top View

5

3
2
4
1

A

RFU

RFU
CS#
RESET#

B

RFU

Vss
CK
Vcc
CK#

C

RFU

RWDS
RFU
DQ2
VssQ

D

DQ4

DQ0
DQ1
DQ3
VccQ

E

VssQ

DQ5
DQ6
VccQ
DQ7

Notes:
1. B1 is assigned to CK# on the 1.8V device.

2. B1 is a RFU on the 3.0V device.

44

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 45 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 12. DDR Center Aligned Read Strobe Functionality

The HyperRAM device offers an optional feature that enables independent skewing (phase shifting) of the RWDS signal with respect
to the read data outputs. This feature is provided in certain devices, based on the Ordering Part Number (OPN).

When the DDR Center Aligned Read Strobe (DCARS) feature is provided, a second differential Phase Shifted Clock input PSC/
PSC# is used as the reference for RWDS edges instead of CK/CK#. The second clock is generally a copy of CK/CK# that is phase
shifted 90 degrees to place the RWDS edges centered within the DQ signals valid data window. However, other degrees of phase
shift between CK/CK# and PSC/PSC# may be used to optimize the position of RWDS edges within the DQ signals valid data
window so that RWDS provides the desired amount of data setup and hold time in relation to RWDS edges.

PSC/PSC# is not used during a write transaction. PSC and PSC# may be driven High and Low respectively or, both may be driven
Low during write transactions.

The PSC/PSC# differential clock is used only in HyperBus devices with 1.8 V nominal core and I/O voltage. HyperBus devices with
3 V nominal core and I/O voltage use only PSC as a single-ended clock.

## 12.1 HyperRAM Products with DCARS Signal Descriptions

### Figure 12.1  HyperBus Product with DCARS Signal Diagram

VCC
VCCQ
RESET#

CS#

DQ[7:0]

CK#
CK

RWDS

PSC

PSC#

VSS
VSSQ

### Signal Descriptions

| Symbol |  | Type |  | Description |
|---|---|---|---|---|
| CS# | Input |  | Chip Select. HyperBus transactions are initiated are terminated with a Low to High transition. | with a High to Low transition. HyperBus transactions |
| CK, CK# | Input |  | Differential Clock. Command-Address/Data of the CK and CK# signals. CK# is not used | information is input or output with respect to the crossing on the 3.0 V device, only a single ended CK is used. |
| PSC, PSC# | Input |  | Phase Shifted Clock. PSC/PSC# allows independent the CK/CK# inputs. PSC# is only used on the Low respectively or both may be driven Low | skewing of the RWDS signal with respect to 1.8 V device. PSC (and PSC#) may be driven High and during write transactions. |
| RWDS | Output |  | Read-Write Data Strobe. Data bytes output on the phase shift from CK, CK# to PSC, PSC#. phase shift from CK, CK# to PSC, PSC# is used RWDS is an input during write transactions to transactions RWDS is an output and indicates (1 = additional latency count, 0 = no additional | during read transactions are aligned with RWDS based PSC, PSC# cause the transitions of RWDS, thus the to place RWDS edges within the data valid window. function as a data mask. At the beginning of all bus whether additional initial latency count is required latency count). |
| DQ[7:0] | Input/Output |  | Data Input/Output. Command-Address/Data and Write transactions. | information is transferred on these DQs during Read |
| RESET# | Input |  | Hardware RESET. When Low the device will DQ[7:0] are placed into the High-Z state when RESET# is left unconnected it will be pulled | self initialize and return to the idle state. RWDS and RESET# is Low. RESET# includes a weak pull-up, if up to the High state. |
| VCC | Power | Supply | Core Power. |  |
| VCCQ | Power | Supply | Input/Output Power. |  |
| VSS | Power | Supply | Core Ground. |  |
| VSSQ | Power | Supply | Input/Output Ground. |  |

45

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 46 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 12.2 HyperRAM Products with DCARS — FBGA 24-ball, 5x5 Array Footprint

### Figure 12.2  24-ball FBGA, 5x5 Ball Footprint, Top View

5

3
2
4
1

A

RFU

RFU
CS#
RESET#

B

PSC

Vss
CK
Vcc
CK#

C

PSC#

RWDS
RFU
DQ2
VssQ

D

DQ4

DQ0
DQ1
DQ3
VccQ

E

VssQ

DQ5
DQ6
VccQ
DQ7

Notes:
1. B1 is an RFU on the 3.0 V device and is assigned to CK# on the 1.8 V device.

2. C5 is an RFU on the 3.0 V device and is assigned to PSC# on the 1.8 V device.

## 12.3 HyperRAM Memory with DCARS Timing

The HyperRAM device read transaction timing parameters vary by device, voltage range, and temperature range. Some timing
parameters are not shown in this supplement documentation. Refer to the individual device data sheets for all current timing
parameter information. The illustrations and parameters in this document are only those needed to define the DCARS feature and
show the relationship between the Phase Shifted Clock, RWDS, and data.

### Figure 12.3  HyperRAM Memory DCARS Timing Diagram

tCSHI

CS#

tCSH

tACC = Access time

tCSS
tCSS

CK, CK#

4 cycle latency

PSC, PSC#

tDSV

tPSCRWDS

tDSZ

High = 2x Latency Count
Low =  1x Latency Count

RWDS

tCKD

tIS
tIH

tDQLZ

tOZ

Dn
A

Dn
B

Dn+1
A

Dn+1
B

DQ[7:0]

47:40 39:32 31:24 23:16 15:8
7:0

Command-Address

RWDS aligned
by PSC

Memory drives DQ[7:0]
and RWDS

Host drives DQ[7:0] and Memory drives RWDS

Notes:
1. Transactions must be initiated with CK = Low and CK# = High. CS# must return High before a new transaction is initiated.

2. CK# and PSC# are only used on the 1.8 V device. The 3 V device uses a single ended CK and PSC input.

3. The memory drives RWDS during read transactions.

4. This example demonstrates a latency code setting of four clocks and no additional initial latency required.

46

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 47 -->

Figure 12.4  DCARS Data Valid Timing
Notes:
1. This figure shows a closer view of the data transfer portion of Figure 12.1, HyperBus Product with DCARS Signal Diagram  on page 43 in order to more clearly show 
the Data Valid period as affected by clock jitter and clock to output delay uncertainty.
2. CK# and PSC# are only used on the 1.8 V device. The 3 V device uses a single ended CK and PSC input.
3. The delay (phase shift) from CK to PSC is controlled by the HyperBus master interface (Host) and is generally between 40 and 140 degrees in order to place the 
RWDS edge within the data valid window with sufficient set-up and hold time of data to RWDS. The requirements for data set-up and hold time to RWDS are 
determined by the HyperBus master interface design and are not addressed by the HyperBus slave timing parameters.
4. The HyperBus timing parameters of tCKD, and tCKDI define the beginning and end position of the data valid period. The tCKD and tCKDI values track together (vary by the 
same ratio) because RWDS and Data are outputs from the same device under the same voltage and temperature conditions.
 DCARS Read Timings (@ 3.0 V)
Note:
1. Sampled, not 100% tested.
 DCARS Read Timings (@ 1.8 V)
Note:
1. Sampled, not 100% tested.
Parameter
Symbol
166 MHz
133 MHz
Unit 
Min
Max 
Min 
Max
HyperRAM PSC transition to RWDS transition
tPSCRWDS
1
5.5
1
5.5
ns
Time delta between CK to DQ valid and PSC to 
RWDS
tPSCRWDS - tCKD
-1.0
+0.5
-1.0
+0.5
ns
CS#
CK ,CK#
PSC ,PSC#
RWDS
DQ[7:0]
tCKD
tCKD
tCSS
tPSCRWDS
tDQLZ
tCSH
tDSZ
tOZ
tDV
tCKDI
tCKHP
Dn
 A
Dn
 B
Dn+1
  A
Dn+1
  B
RWDS and Data are driven by the memory
IS66WVH32M8DALL/BLL 
IS67WVH32M8DALL/BLL
Parameter
Symbol
166 MHz
133 MHz
Unit 
Min
Max 
Min 
Max
HyperRAM PSC transition to RWDS transition
tPSCRWDS
ns
Time delta between CK to DQ valid and PSC to 
RWDS
tPSCRWDS - tCKD
-1.0
+0.5
-1.0
+0.5
ns
1
1
7
7
Integrated Silicon Solution, Inc. - www.issi.com 
Rev. A7 
11/21/2024
47

<!-- page 48 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

# 13. ORDERING RULE & INFORMATION

## 13.1 ORDERING RULE

# PACKAGED

# – 200 B L I

# IS66/67 WVH 32M8 D ALL

Frquency
200: 200 MHZ
166: 166 MHZ
133: 133 MHZ
100: 100 MHZ

VDD
ALL   = 1.8V
BLL   = 3.0V

Den/Org
32M8 = 256Mb/32M x8

66: for PSRAM
67: for AutomoƟve PSRAM

Package Code
B1 = 24-ball TFBGA
B2 = 24-ball TFBGA with PSC/PSC#

Die Rev
D – die rev D

PSRAM Product Type
H – Hyper RAM

Solder Type
L = Green Package
(RoHS Compliant,
Halogen-Free) and
TSCA Compliant

Temperature Range
I = Industrial (-40 °C to 85 °C)
A1 = AutomoƟve (-40 °C to 85 °C)

# KGD –

31=31mil

48

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 49 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 13.2 ORDERING INFORMATION

## ALL : VDD 1.7V~1.95V, VDDQ 1.7V~1.95V

## Industrial Temperature Range: (-40oC to +85oC)

Config.
Frequency

Order Part No.
Package

### (MHz)

200
IS66WVH32M8DALL-200B1LI
24-ball TFBGA , 5x5 Array

IS66WVH32M8DALL-166B1LI
24-ball TFBGA , 5x5 Array

### 32Mx8

### 166

IS66WVH32M8DALL-166B2LI
24-ball TFBGA, 5x5 Array, PSC/PSC#

133
IS66WVH32M8DALL-133B2LI
24-ball TFBGA, 5x5 Array, PSC/PSC#

## Automotive A1 Temperature Range: (-40oC to +85oC)

Config.
Frequency

Order Part No.
Package

### (MHz)

200
IS67WVH32M8DALL-200B1LA1
24-ball TFBGA , 5x5 Array

166
IS67WVH32M8DALL-166B1LA1
24-ball TFBGA , 5x5 Array

### 32Mx8

133
IS67WVH32M8DALL-133B2LA1
24-ball TFBGA, 5x5 Array, PSC/PSC#

## Automotive A2 Temperature Range: (-40oC to +105oC)

Config.
Frequency

Order Part No.
Package

### (MHz)

200
IS67WVH32M8DALL-200B1LA2
24-ball TFBGA , 5x5 Array

166
IS67WVH32M8DALL-166B1LA2
24-ball TFBGA , 5x5 Array

### 32Mx8

133
IS67WVH32M8DALL-133B2LA2
24-ball TFBGA, 5x5 Array, PSC/PSC#

49

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 50 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## BLL : VDD 2.7V~3.6V, VDDQ 2.7V~3.6V

## Industrial Temperature Range: (-40oC to +85oC)

Config.
Frequency

Order Part No.
Package

### (MHz)

200
IS66WVH32M8DBLL-200B1LI
24-ball TFBGA , 5x5 Array

166
IS66WVH32M8DBLL-166B1LI
24-ball TFBGA , 5x5 Array

### 32Mx8

133
IS66WVH32M8DBLL-133B1LI
24-ball TFBGA , 5x5 Array

IS66WVH32M8DBLL-133B2LI
24-ball TFBGA, 5x5 Array, PSC/PSC#

## Automotive A1 Temperature Range: (-40oC to +85oC)

### Frequency

(MHz)
Config.
Order Part No.
Package

200
IS67WVH32M8DBLL-200B1LA1
24-ball TFBGA , 5x5 Array

166
IS67WVH32M8DBLL-166B1LA1
24-ball TFBGA , 5x5 Array

### 32Mx8

133
IS67WVH32M8DBLL-133B1LA1
24-ball TFBGA , 5x5 Array

IS67WVH32M8DBLL-133B2LA1
24-ball TFBGA, 5x5 Array, PSC/PSC#

## Automotive A2 Temperature Range: (-40oC to +105oC)

### Frequency

(MHz)
Config.
Order Part No.
Package

200
IS67WVH32M8DBLL-200B1LA2
24-ball TFBGA , 5x5 Array

166
IS67WVH32M8DBLL-166B1LA2
24-ball TFBGA , 5x5 Array

### 32Mx8

133
IS67WVH32M8DBLL-133B1LA2
24-ball TFBGA , 5x5 Array

IS67WVH32M8DBLL-133B2LA2
24-ball TFBGA, 5x5 Array, PSC/PSC#

50

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- page 51 -->

## IS66WVH32M8DALL/BLL IS67WVH32M8DALL/BLL

## 14. PACKAGE INFORMATION

51

Integrated Silicon Solution, Inc. - www.issi.com
Rev. A7
11/21/2024

<!-- END VERBATIM SOURCE -->
