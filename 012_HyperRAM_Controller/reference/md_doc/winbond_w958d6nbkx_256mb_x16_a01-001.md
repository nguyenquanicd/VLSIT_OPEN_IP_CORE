---
protocol: "Winbond W958D6NBKX HyperRAM 3.0 Extended-I/O x16 datasheet"
revision: "A01-001 (2023-03-09)"
source: "https://www.winbond.com/resource-files/W958D6NBKX%20256Mb%20HyperRAM%203.0%20WFBGA49%20SDP%20datasheet_A01-001_20230309.pdf"
license: "Winbond copyright; all rights reserved"
redistribution: "forbidden"
retrieved: 2026-10-27
source_sha256: "1b20458786d101d8452562922131167813621d1a778e9f9f7ed2af5e95041107"
converter: "vlsit_pdf_to_md.py (PyMuPDF)"
---

# Winbond W958D6NBKX HyperRAM 3.0 Extended-I/O x16 datasheet - revision A01-001 (2023-03-09)

> **Key notes (written by the converter operator, not part of the source):**
> - none recorded

> The text between the markers below is the source text, converted without rewording.

<!-- BEGIN VERBATIM SOURCE -->

<!-- page 1 -->

# W958D6NBKX

# 256Mb HyperRAM 3.0 x16 pSRAM

### Table of Contents-

1. FEATURES .................................................................................................................................................................................. 3
2. ORDER INFORMATION .............................................................................................................................................................. 3
3. BALL ASSIGNMENT.................................................................................................................................................................... 4
4. BALL DESCRIPTIONS ................................................................................................................................................................ 5
5. BLOCK DIAGRAM ....................................................................................................................................................................... 6
6. FUNCTIONAL DESCRIPTION ..................................................................................................................................................... 7
6.1
General Description ....................................................................................................................................................... 7
6.2
HyperBus-Extend-IO ...................................................................................................................................................... 7
7. HyperBus-Extend-IO TRANSACTION DETAILS ....................................................................................................................... 10
7.1
Command/Address Bit Assignments ............................................................................................................................ 10
7.2
Read Transactions ....................................................................................................................................................... 13
7.3
Write Transactions (Memory Array Write) .................................................................................................................... 15
7.4
Write Transactions without Initial Latency (Register Write) .......................................................................................... 17
8. MEMORY SPACE ...................................................................................................................................................................... 18
8.1
HyperBus-Extend-IO Memory Space addressing ........................................................................................................ 18
8.2
Density and Row Boundaries ....................................................................................................................................... 18
9. REGISTER SPACE ................................................................................................................................................................... 19
9.1
HyperRAM Register Addressing .................................................................................................................................. 19
9.2
Register Space Access ................................................................................................................................................ 19
9.3
Device Identification Registers ..................................................................................................................................... 20
9.4
Configuration Register 0 .............................................................................................................................................. 20
9.4.1
Wrapped Burst ............................................................................................................................................... 21
9.4.2
Hybrid Burst ................................................................................................................................................... 22
9.4.3
Initial Latency ................................................................................................................................................. 23
9.4.4
Fixed Latency ................................................................................................................................................ 23
9.4.5
Drive Strength ................................................................................................................................................ 23
9.4.6
Deep Power Down ......................................................................................................................................... 23
9.5
Configuration Register 1 .............................................................................................................................................. 24
9.5.1
Master Clock Type ......................................................................................................................................... 24
9.5.2
Partial Array Refresh ...................................................................................................................................... 24
9.5.3
Hybrid Sleep .................................................................................................................................................. 25
9.5.4
Distributed Refresh Interval ........................................................................................................................... 25
10. INTERFACE STATES ................................................................................................................................................................ 26
10.1
IO condition of interface states..................................................................................................................................... 26
10.2
Power Conservation Modes ......................................................................................................................................... 27
10.2.1
Interface Standby ........................................................................................................................................... 27
10.2.2
Active Clock Stop ........................................................................................................................................... 27
10.2.3
Hybrid Sleep .................................................................................................................................................. 27
10.2.4
Deep Power Down ......................................................................................................................................... 28
11. ELECTRICAL SPECIFICATIONS .............................................................................................................................................. 29
11.1
Absolute Maximum Ratings ......................................................................................................................................... 29
11.2
Latch up Characteristics .............................................................................................................................................. 29
11.3
Operating Ranges ........................................................................................................................................................ 29
11.3.1
DC Characteristics ......................................................................................................................................... 29

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 1 -

<!-- page 2 -->

# W958D6NBKX

11.3.2
Operating Temperature .................................................................................................................................. 29
11.3.3
ICC Characteristics ........................................................................................................................................ 30
11.3.4
Power-Up Initialization ................................................................................................................................... 31
11.3.5
Power-Down .................................................................................................................................................. 32
11.3.6
Hardware Reset ............................................................................................................................................. 33
11.3.7
Capacitance Characteristics .......................................................................................................................... 34
11.4
Input Signal Overshoot ................................................................................................................................................ 34
12. TIMING SPECIFICATIONS ........................................................................................................................................................ 35
12.1
Key to Switching Waveforms ....................................................................................................................................... 35
12.2
AC Test Conditions ...................................................................................................................................................... 35
12.3
AC Characteristics ....................................................................................................................................................... 36
12.3.1
Read Transactions ......................................................................................................................................... 36
12.3.2
Write Transactions ......................................................................................................................................... 40
12.3.3
Hybrid Sleep Timings ..................................................................................................................................... 42
12.3.4
Deep Power down Timings ............................................................................................................................ 42
13. PACKAGE SPECIFICATION ..................................................................................................................................................... 43
14. REVISION HISTORY ................................................................................................................................................................. 44

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 2 -

<!-- page 3 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 3 - 
1. FEATURES 
• Interface: HyperBus-Extend-IO (HyperRAM 3.0) 
• Power supply: 1.7V~2.0V 
• Maximum clock rate: 250MHz 
• Double-Data Rate (DDR) Up to 1000 MB/s 
• Clock: 
– Single ended clock (CK) 
– Differential clock (CK/CK#) 
• Chip Select (CS#) 
• 16-bit data bus (DQ[15:0]) 
• Hardware reset (RESET#) 
• Read-Write Data Strobe (RWDS[1:0]) 
– Bidirectional Data Strobe / Mask 
– Output at the start of all transactions to indicate 
refresh latency 
– Output during read transactions as Read Data 
Strobe 
– Input during write transactions as Write Data 
Mask 
Performance and Power 
• Configurable output drive strength 
• Power Saving Modes 
– Hybrid Sleep Mode 
– Deep Power Down 
• Configurable Burst Characteristics 
– Linear burst 
– Wrapped burst lengths: 
– 16 (8 clocks) 
– 32 (16 clocks) 
– 64 (32 clocks) 
– 128 (64 clocks) 
– Hybrid burst - one wrapped burst followed by 
linear burst 
• Array Refresh Modes 
– Full Array Refresh 
– Partial Array Refresh 
• Support package: 
49 balls WFBGA 
(4x4 mm2 with thickness of 0.8 mm) 
• Operating temperature range: 
-40°C ≤ TCASE ≤ 85°C 
2. ORDER INFORMATION 
Part Number 
VCC/VCCQ 
I/O Width 
Package 
Interface 
Others 
W958D6NBKX5I 
1.8V 
16 
49 balls WFBGA 
HyperBus-Extend-
IO (HyperRAM 3.0) 
200MHz, -40°C~85°C 
W958D6NBKX4I 
1.8V 
16 
49 balls WFBGA 
HyperBus-Extend-
IO (HyperRAM 3.0) 
250MHz, -40°C~85°C

<!-- page 4 -->

# W958D6NBKX

### 3. BALL ASSIGNMENT

## 1 2 6 5 7 4 3

## A

RFU

RFU
RESET#
VSS
RFU
CS#
RFU

## B

RFU
CK
VSSQ
RFU
VSS
CK#

VCC

## C

DQ2
VCCQ
RFU
RWDS0
VSSQ
VCC

RFU

## D

RFU
DQ4
DQ0
VCCQ
DQ1
VSSQ
DQ3

## E

VCCQ
DQ6
VCCQ
RFU
VSSQ
DQ5
DQ7

## F

DQ9
VCCQ
DQ8
DQ10
VCCQ
RWDS1
DQ11

## G

DQ13
VSSQ
DQ12
DQ14
VSSQ
RFU
DQ15

### TOP VIEW (Ball Down)

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 4 -

<!-- page 5 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 5 - 
4. BALL DESCRIPTIONS 
Signal Name 
Type 
Description 
CS# 
Input 
Chip Select: 
Bus transactions are initiated with a High to Low transition. Bus transactions 
are terminated with a Low to High transition. The master device has a 
separate CS# for each slave. 
CK, CK# 
Input 
Differential Clock: 
Command, address, and data information is output with respect to the 
crossing of the CK and CK# signals. 
Single Ended Clock: 
CK# is not used, only a single ended CK is used. The clock is not required to 
be free-running. 
DQ[15:0] 
Input / Output 
Data Input / Output: 
DQ[7:0] for Command, Address, and Data information are transferred on these 
signals during Read and Write transactions. 
DQ[15:8] for Data information are transferred on these signals during Read 
and Write transactions. Host has to drive DQ[15:8] all to “H” or “L” during the 
CA period. Floating is not allowed. 
RWDS[1:0] 
Input / Output 
Read Write Data Strobe: 
During the Command/Address portion of all bus transactions RWDS is a slave 
output and indicates whether additional initial latency is required. Slave output 
during read data transfer, data is edge aligned with RWDS. Slave input during 
data transfer in write transactions to function as a data mask. 
RWDS[0] corresponds to the data on DQ[7:0] 
RWDS[1] corresponds to the data on DQ[15:8] 
RWDS High indicates additional latency, Low indicates no additional latency. 
RESET# 
Input, 
Internal Pull-up 
Hardware Reset: 
When Low the slave device will self-initialize and return to the Standby state. 
RWDS[1:0] and DQ[15:0] are placed into the High-Z state when RESET# is 
Low. The slave RESET# input includes a weak pull-up, if RESET# is left 
unconnected it will be pulled up to the High state. 
VCC 
Power Supply 
VCC Power Supply: 
For supplying input buffer of CK/CK#, CS#, RESET#, DQ[15:0] and RWDS[1:0] 
internal circuitry and memory array. 
VCCQ 
Power Supply 
VCCQ Power Supply: 
For supplying output buffer of DQ[15:0] and RWDS[1:0]. 
VSS 
Power Supply 
VSS Ground: Ground of VCC. 
VSSQ 
Power Supply 
VSSQ Ground: Ground of VCCQ. 
RFU 
No Connect 
Reserved for Future Use: 
May or may not be connected internally, the signal/ball location should be left 
unconnected and unused by PCB routing channel for future compatibility. The 
signal/ball may be used by a signal in the future.

<!-- page 6 -->

# W958D6NBKX

### 5. BLOCK DIAGRAM

# CS#

# X Decoders

# Memory

# CK/CK#

# RWDS[1:0]

# Y Decoders

# I/O Control Logic

# Data Latch

# DQ[15:0]

# RESET#

# Data Path

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 6 -

<!-- page 7 -->

# W958D6NBKX

6. FUNCTIONAL DESCRIPTION
6.1 General Description
HyperRAM is a pSRAM device with HyperBus or HyperBus-Extend-IO, both are low signal count, Double Data Rate
(DDR) interfaces. The DDR protocol transfers two 8-bit or two 16-bit data per clock cycle on the DQ input/output pins.
HyperBus consists 8-bit wide DQ signals, a 16-bit wide data can be transferred in one clock cycle and HyperBus-Extend-
IO consists 16-bit wide DQ signals, a 32-bit wide data can be transferred in one clock cycle. All inputs and outputs are
LV-CMOS compatible. Each HyperRAM devices may have different features depends on its device names. For example,
HyperRAM 3.0. The HyperRAM 3.0 device is one of HyperRAM devices with low signal count including 16 DQ pins,
Double Data Rate (DDR) HyperBus-Extend-IO interface, that achieves much higher speed read and write throughput.
6.2 HyperBus-Extend-IO
The DDR protocol transfers two 16-bit data per clock cycle on the DQ input/output signals. A read or write transaction
on HyperBus-Extend-IO consists of a series of 32-bit wide, one clock cycle data transfers at the internal array with two
corresponding 16-bit wide, one-half-clock-cycle data transfers on the DQ signals. All inputs and outputs are LV-CMOS
compatible. Command, address, and data information is transferred over the sixteen HyperBus-Extend-IO DQ[15:0]
signals. The clock (CK#, CK) is used for information capture by a HyperBus-Extend-IO slave device when receiving
command, address, or data on the DQ signals. Command or Address values are center aligned with clock transitions.
Every transaction begins with the assertion of CS# and Command-Address (CA) signals, followed by the start of clock
transitions to transfer six CA bytes, followed by initial access latency and either read or write data transfers, until CS# is
de-asserted.
Read and write transactions require two clock cycles to define the target row address and burst type, then an initial
access latency of tACC. During the CA part of a transaction, the memory will indicate whether an additional latency for a
required refresh time (tRFH) is added to the initial latency; by driving the RWDS signal to the High state. During the CA
period the third clock cycle will specify the target data(32-bits) address within the target row. During a read (or write)
transaction, after the initial data value has been output (or input), additional data can be read from (or written to) the row
on subsequent clock cycles in either a wrapped or linear sequenced. When configured in linear burst mode, the device
will automatically fetch the next sequential row from the memory array to support a continuous linear burst.
Simultaneously accessing the next row in the array while the read or write data transfer is in progress, allows for a linear
sequential burst operation.

### CS#

tRWR = Read Write Recovery
tACC = Access

### CK#,CK

Latency Count

### RWDS[1:0]

Low =  1x Latency Count

RWDS and Data
are edge aligned

47:40 39:32 31:24 23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

### DQ[15:0]

A

B

A

B

Memory drives DQ[15:0]
and RWDS

Command-Address

Figure 1 - Read Transaction, Single Initial Latency Count
Note: DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive

DQ[15:8] to “H” or “L”.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 7 -

<!-- page 8 -->

# W958D6NBKX

The Read/Write Data Strobe (RWDS[1:0]) are bidirectional signals that indicates:

⚫ When data will start to transfer from a HyperRAM device to the master device in read transactions (initial read

latency)
⚫ When data is being transferred from a HyperRAM device to the master device during read transactions (as a

source synchronous read data strobe)
⚫ When data may start to transfer from the master device to a HyperRAM device in write transactions (initial write

latency)
⚫ Data masking during write data transfers
During the CA transfer portion of a read or write transaction, RWDS[1:0] acts as an output from a HyperRAM device to
indicate whether additional initial access latency is needed in the transaction.
During read data transfers, RWDS[1:0] are read data strobe with data values edge aligned with the transitions of
RWDS[1:0].

CS#

tRWR = Read Write Recovery
Additional Latency

tACC = Access

CK#,CK

Latency Count 2

Latency Count 1

High = 2x Latency Count

RWDS[1:0]

RWDS and Data
are edge aligned

47:40 39:32 31:24 23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

Memory drives DQ[15:0]
and RWDS[1:0]

Command-Address

Figure 2 - Read Transaction, Additional Latency Count

During write data transfers, RWDS indicates whether each data transfer is masked with RWDS High (invalid and
prevented from changing the data location in a memory) or not masked with RWDS Low (valid and written to a memory).
Data masking may be used by the host to byte align write data within a memory or to enable merging of multiple non-
word aligned writes in a single burst write. During write transactions, data is center aligned with clock transitions.

CS#

tRWR = Read Write Recovery
tACC = Access

CK#,CK

CK and Data
are center aligned

Latency Count

RWDS[1:0]

Low = 1x Latency Count

47:40 39:32 31:24 23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

Host drives DQ[15:0]
and RWDS[1:0]

Command-Address

Figure3 - Write Transaction, Single Initial Latency Count
Note: The last write data can be masked or not masked.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 8 -

<!-- page 9 -->

# W958D6NBKX

Read and write transactions are burst oriented, transferring the next sequential 32-bits during each clock cycle. Each
individual read or write transaction can use either a wrapped or linear burst sequence.

32 Data(32-bits) group alignment
boundaries

Linear Burst

4h
5h
6h
7h
8h
9h
Ah
Bh
Ch
Dh
Eh
Fh 10h 11h 12h 13h

Initial address = 4h

Wrapped Burst

4h
5h
6h
7h
8h
9h
Ah
Bh
Ch
Dh
Eh
Fh
0h
1h
2h
3h

Figure 4 - Linear Versus Wrapped Burst Sequence
During wrapped transactions, accesses start at a selected location and continue to the end of a configured 32-bits group
aligned boundary, then wrap to the beginning location in the group, then continue back to the starting location. Wrapped
bursts are generally used for critical 32-bits first cache line fill read transactions. During linear transactions, accesses
start at a selected location and continue in a sequential manner until the transaction is terminated when CS# returns
High. Linear transactions are generally used for large contiguous data transfers such as graphic images. Since each
transaction command selects the type of burst sequence for that transaction, wrapped and linear bursts transactions
can be dynamically intermixed as needed.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 9 -

<!-- page 10 -->

# W958D6NBKX

### 7. HyperBus-Extend-IO TRANSACTION DETAILS

7.1 Command/Address Bit Assignments
All HyperBus-Extend-IO transactions can be classified as either read or write. A bus transaction is started with CS#
going Low with clock in idle state (CK=Low and CK#=High). The first three clock cycles transfer three words of
Command/Address (CA0, CA1, CA2) information to define the transaction characteristics. The Command/Address
words are presented with DDR timing, using the first six clock edges. The following characteristics are defined by the
Command/Address information:

◼ Read or Write transaction
◼ Address Space: memory array space or register space

– Register space is used to access Device Identification (ID) registers and Configuration Registers (CR) that

identify the device characteristics and determine the slave specific behavior of read and write transfers on the
HyperBus-Extend-IO.
◼ Whether a transaction will use a linear or wrapped burst sequence
◼ The target row (and half-page) address (upper order address)
◼ The target column (word within half-page) address (lower order address)

### CS#

### CK,CK#

CA0[47:40] CA0[39:32] CA1[31:24] CA1[23:16]
CA2[15:8]
CA2[7:0]

### DQ[7:0]

Figure 5 - Command-Address (CA) Sequence

Notes:
1. Figure shows the initial three clock cycles of all transactions on the HyperBus-Extend-IO.
2. CK# of differential clock is shown as dashed line waveform.
3. CA information is “center aligned” with the clock during both Read and Write transactions.
4. Data bits in each byte are always in high to low order with bit 7 on DQ7 and bit 0 on DQ0.
5. In command/Address phase, DQ[15:8] input will be not used for command/Address decoding, however, the controller has to drive
DQ[15:8] to “H” or “L”.

Table 1 - CA Bit Assignment to DQ Signals

Signal
CA0[47:40]
CA0[39:32]
CA1[31:24]
CA1[23:16]
CA2[15:8]
CA2[7:0]

DQ[7]
CA[47]
CA[39]
CA[31]
CA[23]
CA[15]
CA[7]

DQ[6]
CA[46]
CA[38]
CA[30]
CA[22]
CA[14]
CA[6]

DQ[5]
CA[45]
CA[37]
CA[29]
CA[21]
CA[13]
CA[5]

DQ[4]
CA[44]
CA[36]
CA[28]
CA[20]
CA[12]
CA[4]

DQ[3]
CA[43]
CA[35]
CA[27]
CA[19]
CA[11]
CA[3]

DQ[2]
CA[42]
CA[34]
CA[26]
CA[18]
CA[10]
CA[2]

DQ[1]
CA[41]
CA[33]
CA[25]
CA[17]
CA[9]
CA[1]

DQ[0]
CA[40]
CA[32]
CA[24]
CA[16]
CA[8]
CA[0]

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 10 -

<!-- page 11 -->

# W958D6NBKX

Table 2 - Command/Address Bit Assignments

| Bit Function |
|---|
| Identifies the transaction as a read or write. R/W#=1 indicates a Read transaction R/W#=0 indicates a Write transaction |
| Indicates whether the read or write transaction accesses the memory or register space. AS=0 indicates memory space AS=1 indicates the register space The register space is used to access device ID and Configuration registers. |
| Indicates whether the burst will be linear or wrapped. Burst Type=0 indicates wrapped burst Burst Type=1 indicates linear burst |
| Row & Upper Column component of the target address: System data address bits A31-A3 Any upper Row address bits not used by a particular device density should be set to 0 by the host controller master interface. The size of Rows and therefore the address bit boundary between Row and Column address is slave device dependent. |
| Reserved for future column address expansion. Reserved bits are don’t care in current HyperBus devices but should be set to 0 by the host controller master interface for future compatibility. |

47
R/W#

46
Address Space

(AS)

45
Burst Type

44-16
Row & Upper
Column Address

15-3
Reserved

Lower Column component of the target address:
System data address bits A2-A0 selecting the starting data(32-bits) within a half-page.

2-0
Lower Column

Address

Notes:
1. The Column address selects the burst transaction starting data location within a Row. The Column address is split into an upper and
lower portion. The upper portion selects an 8 data(32-bits) Half-page and the lower portion selects the 32-bits within a Half-page
where a read or write transaction burst starts.
2. The initial read access time starts when the Row and Upper Column (Half-page) address bits are captured by a slave interface.
Continuous linear read burst is enabled by memory devices internally interleaving access to 8 data(32-bits) half-pages.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 11 -

<!-- page 12 -->

# W958D6NBKX

### CS#

### CK,CK#

### RWDS[1:0]

## Dn B Dn+1 A Dn+1 B Dn+2 A

## Dn+1 A Dn A

### DQ[15:0]

Figure 6 - Data Placement during a Read Transaction

Notes:
1. Figure shows a portion of a Read transaction on the HyperBus-Extend-IO. CK# of differential clock is shown as dashed line
waveform.
2. Data is “edge aligned” with the RWDS serving as a read data strobe during read transactions.
3. Data is always transferred in full 32-bits increments (32-bits granularity transfers).
4. The address increments in each clock cycle. Dn A(16-bits) is between RWDS rising and falling edges and is followed by Dn B(16-
bits) between RWDS falling and rising edges, of each 32-bit data.
5. Each 16-bits data always in high to low order with bit 15 on DQ15 and bit 0 on DQ0.

### CS#

### CK,CK#

### RWDS[0]

### RWDS[1]

## Dn B Dn+1 A Dn+1 B Dn+2 A

## Dn+1 A Dn A

### DQ[7:0]

## Dn B Dn+1 A Dn+1 B Dn+2 A DQ[15:8] Dn+1 A Dn A

Data masked
Figure 7 - Data Placement during a Write Transaction

Notes:
1. Figure shows a portion of a Write transaction on the HyperBus-Extend-IO.
2. Data is “center aligned” with the clock during a Write transaction.
3. RWDS[1:0] functions as a data mask during write data transfers with initial latency.
RWDS[0] as a input data mask for the data on DQ0-7.
RWDS[1] as a input data mask for the data on DQ8-15.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 12 -

<!-- page 13 -->

# W958D6NBKX

7.2 Read Transactions
The HyperBus-Extend-IO master begins a transaction by driving CS# Low while clock is idle. The clock then begins
toggling while CA words are transferred.

In CA0, CA[47] = 1 indicates that a Read transaction is to be performed. CA[46] = 0 indicates the memory space is
being read or CA[46] = 1 indicates the register space is being read. CA[45] indicates the burst type (wrapped or
linear). Read transactions can begin the internal array access as soon as the row and upper column address has been
presented in CA0 and CA1 (CA[47:16]). CA2 (CA[15:0]) identifies the target Word address within the chosen row.

The HyperBus-Extend-IO master then continues clocking for a number of cycles defined by the latency count setting in
Configuration Register 0. The initial latency count required for a particular clock frequency is based on RWDS. If
RWDS is Low during the CA cycles, one latency count is inserted. If RWDS is High during the CA cycles, an additional
latency count is inserted. Once these latency clocks have been completed the memory starts to simultaneously
transition the Read-Write Data Strobe (RWDS) and output the target data.

New data is output edge aligned with every transition of RWDS. Data will continue to be output as long as the host
continues to transition the clock while CS# is Low. However, the HyperRAM device may stop RWDS transitions with
RWDS Low, between the deliveries of words, in order to insert latency between words when crossing memory array
boundaries.

Wrapped bursts will continue to wrap within the burst length and linear burst will output data in a sequential manner
across row boundaries. When a linear burst read reaches the last address in the array, continuing the burst beyond
the last address will provide data from the beginning of the address range. Read transfers can be ended at any time
by bringing CS# High when the clock is idle.

The clock is not required to be free-running. The clock may remain idle while CS# is High.

CS#

tRWR = Read Write Recovery
Additional Latency

tACC = Access

CK#,CK

High = 2x Latency Count

RWDS[1:0]

RWDS and Data
are edge aligned

Latency Count 2

Latency Count 1

47:40 39:32 31:24 23:16 15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

Memory drives DQ[15:0]
and RWDS[1:0]

Command-Address

Figure 8 - Read Transaction with Additional Initial Latency

Notes:
1. Transactions are initiated with CS# falling while CK=Low and CK#=High.
2. CS# must return High before a new transaction is initiated.
3. CK# is the complement of the CK signal.CK# of a differential clock is shown as a dashed line waveform.
4. Read access array starts once CA[23:16] is captured.
5. The read latency is defined by the initial latency value in a configuration register.
6. In this read transaction example the initial latency count was set to four clocks.
7. In this read transaction RWDS High indication during CA delays output of target data by an additional four clocks.
8. The memory device drives RWDS during read transactions.
9. For register read, the output data Dn A[7:0] is RG[15:8], Dn B[7:0] is RG[7:0], Dn+1 A[7:0] is RG[15:8], Dn+1 B[7:0] is RG[7:0].
10. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive DQ[15:8]
to “H” or “L”.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 13 -

<!-- page 14 -->

# W958D6NBKX

CS#

tRWR = Read Write Recovery
tACC = Initial Access

CK#,CK

RWDS[1:0]

Low =  1x Latency Count

RWDS and Data
are edge aligned

4 cycle latency

47:40 39:32 31:24 23:16 15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

Memory drives DQ[15:0]
and RWDS[1:0]

Command-Address

Figure 9 - Read Transaction without Additional Initial Latency

Notes:
1. RWDS is Low during the CA cycles. In this Read Transaction there is a single initial latency count for read data access because, this
read transaction does not begin at a time when additional latency is required by the slave.
2. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive DQ[15:8] to
“H” or “L”.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 14 -

<!-- page 15 -->

# W958D6NBKX

7.3 Write Transactions (Memory Array Write)
The HyperBus-Extend-IO master begins a transaction by driving CS# Low while clock is idle. Then the clock begins
toggling while CA words are transferred.

In CA0, CA[47] = 0 indicates that a Write transaction is to be performed. CA[46] = 0 indicates the memory space is being
written. CA[45] indicates the burst type (wrapped or linear). Write transactions can begin the internal array access as
soon as the row and upper column address has been presented in CA0 and CA1 (CA[47:16]). CA2 (CA[15:0]) identifies
the target word address within the chosen row.

The HyperBus-Extend-IO master then continues clocking for a number of cycles defined by the latency count setting in
configuration register 0. The initial latency count required for a particular clock frequency is based on RWDS. If RWDS
is Low during the CA cycles, one latency count is inserted. If RWDS is High during the CA cycles, an additional latency
count is inserted.

Once these latency clocks have been completed the HyperBus-Extend-IO master starts to output the target data. Write
data is center aligned with the clock edges. The first 16-bits data is captured by the memory on the rising edge of CK
and the second 16-bits data is captured on the falling edge of CK.

During the CA clock cycles, RWDS is driven by the memory.

During the write data transfers, RWDS is driven by the host master interface as a data mask. When data is being written
and RWDS is High the data will be masked and the array will not be altered. When data is being written and RWDS is
Low the data will be placed into the array. Because the master is driving RWDS during write data transfers, neither the
master nor the HyperRAM device is able to indicate a need for latency within the data transfer portion of a write
transaction. The acceptable write data burst length setting is also shown in configuration register 0.

Data will continue to be transferred as long as the HyperBus-Extend-IO master continues to transition the clock while
CS# is Low. Legacy format wrapped bursts will continue to wrap within the burst length. Hybrid wrap will wrap once then
switch to linear burst starting at the next wrap boundary. Linear burst accepts data in a sequential manner across page
boundaries. Write transfers can be ended at any time by bringing CS# High when the clock is idle.

When a linear burst write reaches the last address in the memory array space, continuing the burst will write to the
beginning of the address range.

The clock is not required to be free-running. The clock may remain idle while CS# is High.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 15 -

<!-- page 16 -->

# W958D6NBKX

### CS#

tRWR = Read Write Recovery
Additional Latency

tACC = Initial Access

### CK#,CK

CK and Data
are center aligned

Latency Count 1

Latency Count 2

High = 2x Latency Count

### RWDS[1:0]

47:40
39:32
31:24
23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

A
Dn+1

A
Dn+1

### DQ[15:0]

A

B

A

B

Host drives DQ[15:0]
and RWDS[1:0]

Command-Address

Figure 10 - Write Transaction with Additional Initial Latency
Notes:
1. Transactions must be initiated with CK=Low and CK#=High.
2. CS# must return High before a new transaction is initiated.
3. During CA, RWDS is driven by the memory and indicates whether additional latency cycles are required.
4. In this example, RWDS indicates that additional initial latency cycles are required.
5. At the end of CA cycles the memory stops driving RWDS to allow the host HyperBus-Extend-IO master to begin driving RWDS. The
master must drive RWDS to a valid Low before the end of the initial latency to provide a data mask preamble period to the slave.
6. During data transfer, RWDS is driven by the host to indicate which data should be either masked or loaded into the array.
7. The figure shows RWDS masking Dn A and Dn+1 B to perform an unaligned data write to Dn B and Dn+1 A.
8. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive DQ[15:8] to
“H” or “L”.

### CS#

tRWR = Read Write Recovery
tACC = Access

### CK#,CK

CK and Data
are center aligned

Latency Count

### RWDS[1:0]

Low = 1x Latency Count

47:40
39:32
31:24
23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

### DQ[15:0]

A

B

A

B

Host drives DQ[15:0]
and RWDS

Command-Address

Figure 11 - Write Transaction without Additional Initial Latency
Notes:
1. During CA, RWDS is driven by the memory and indicates whether additional latency cycles are required.
2. In this example, RWDS indicates that there is no additional latency required.
3. At the end of CA cycles the memory stops driving RWDS to allow the host HyperBus-Extend-IO master to begin driving RWDS. The
master must drive RWDS to a valid Low before the end of the initial latency to provide a data mask preamble period to the slave.
4. During data transfer, RWDS is driven by the host to indicate which data should be either masked or loaded into the array.
5. The figure shows RWDS masking Dn A and Dn+1 B to perform an unaligned data write to Dn B and Dn+1 A.
6. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive DQ[15:8] to
“H” or “L”.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 16 -

<!-- page 17 -->

# W958D6NBKX

7.4 Write Transactions without Initial Latency (Register Write)
A Write transaction starts with the first three clock cycles providing the Command/Address information indicating the
transaction characteristics. CA0 may indicate that a Write transaction is to be performed and also indicates the address
space and burst type (wrapped or linear).

Writes without initial latency are used for register space writes. HyperRAM device write transactions with zero latency
mean that the CA cycles are followed by write data transfers. Writes with zero initial latency, do not have a turnaround
period for RWDS. The HyperRAM device will always drive RWDS during the CA period to indicate whether extended
latency is required for a transaction that has initial latency. However, the RWDS is driven before the HyperRAM device
has received the first byte of CA i.e. before the HyperRAM device knows whether the transaction is a read or write to
register space. In the case of a write with zero latency, the RWDS state during the CA period does not affect the initial
latency of zero. Since master write data immediately follows the CA period in this case, the HyperRAM device may
continue to drive RWDS Low or may take RWDS to High-Z during write data transfer. The master must not drive RWDS
during Writes with zero latency. Writes with zero latency do not use RWDS as a data mask function. All write data are
written.

The first 16-bits data is presented on the rising edge of CK and the second 16-bits data is presented on the falling edge
of CK. Write data is center aligned with the clock inputs. Write transfers can be ended at any time by bringing CS# High
when clock is idle. The clock is not required to be free-running.

### CS#

### CK,CK#

### RWDS[1:0]

### DQ[7:0]

CA
[47:40]

CA
[39:32]

CA
[31:24]

CA
[23:16]

CA
[15:8]

CA
[7:0]

RG
[15:8]

RG
[7:0]

Command-Address

Figure 12 - Write Operation without Initial Latency (Register Write)
Notes:
1. RWDS not driven by the master during write data transfers with zero initial latency. Full data are always written in this case. RWDS
may be driven Low or left High-Z by the slave during write data transfer.
2. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive DQ[15:8] to
“H” or “L”.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 17 -

<!-- page 18 -->

# W958D6NBKX

8. MEMORY SPACE
8.1 HyperBus-Extend-IO Memory Space addressing
Table 3 - Memory Space Address Map (data based – 32-bits)

| Unit Type |
|---|
| Rows within 256 Mb device |
| Row |
| Half-Page |

| Count |
|---|
| 32768 (Rows) |
| 1 (row) |
| 8 (32 bits addresses) |

| Notes |
|---|
| 256 (32-bits addresses) 1K bytes |
| 8 (32-bits addresses) 32 bytes |

| Row Address |
|---|
| Column Address |
| Half-Page (HP) Address |
| Word of HP Address |
| Notes: 1. Each row has 32 Half-pages. Each Half-page 2. Half-Page address is also named as upper |

| System Data Address Bits |
|---|
| CA Bits |
| System Data Address Bits |
| CA Bits |
| System Data Address Bits |
| CA Bits |
| System Data Address Bits |
| CA Bits |

| 256Mb |
|---|
| A22~A8 |
| 35~21 |
| A7~A0 |
| 20~16; 2~0 |
| A7~A3 |
| 20~16 |
| A2~A0 |
| 2~0 |

Notes:
1. Each row has 32 Half-pages. Each Half-page has 8 data(32-bits). Each column has 256 data(32-bits) (1K bytes).
2. Half-Page address is also named as upper column address. 32-bits of HP address is also named as lower column address.
8.2 Density and Row Boundaries
The DRAM array size (density) of the device can be determined from the total number of system address bits used for
the row and column addresses as indicated by the Row Address Bit Count and Column Address Bit Count fields in the
ID0 register.

A 256Mbit HyperRAM device has 8 column address bits and 15 row address bits for a total of 23 address bits for 32-
bits address = 223 x 32 = 8M x 32 = 256Mbit. The 8 column address bits indicate that each row holds 28 x 32 = 8192
bits. The row address bit count indicates there are 32768 rows to be refreshed within each array refresh interval. The
row count is used in calculating the refresh interval.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 18 -

<!-- page 19 -->

# W958D6NBKX

9. REGISTER SPACE
9.1 HyperRAM Register Addressing
Table 5 - Register Space Address Map

| System Address |
|---|
| CA Bits |

Register

Identification Register 0 (read only)
C0h or E0h
00h
00h
00h
00h
00h

| Identification Register 1 (read only) |
|---|
| Configuration Register 0 Read |
| Configuration Register 0 Write |
| Configuration Register 1 Read |
| Configuration Register 1 Write |
| Notes: 1. When CA[46] is 1 a read or write transaction 2. CA[45] may be either 0 or 1 for either wrapped 3. The Burst type (wrapped/linear) definition is |

| C0h or E0h |
|---|
| C0h or E0h |
| 60h |
| C0h or E0h |
| 60h |

Notes:
1. When CA[46] is 1 a read or write transaction accesses the Register Space.
2. CA[45] may be either 0 or 1 for either wrapped or linear read. CA[45] must be 1 as only linear single word register writes are supported.
3. The Burst type (wrapped/linear) definition is not supported in Register Reads. Hence C0h/E0h have the same effect.
9.2 Register Space Access
Register default values are loaded upon power-up or hardware reset. The registers can be altered at any time while the
device is in the standby state.

Loading a register is accomplished with write transaction without initial latency using a single 16-bits word write
transaction.

Each register is written with a separate single word write transaction. Register write transactions have zero latency, the
single word of data immediately follows the CA. RWDS is not driven by the host during the write because RWDS is
always driven by the memory during the CA cycles to indicate whether a memory array refresh is in progress. Because
a register space write goes directly to a register, rather than the memory array, there is no initial write latency, related to
an array refresh that may be in progress. In a register write, RWDS is also not used as a data mask because both bytes
of a register are always written and never masked.

Reserved register fields must be written with their default value. Writing reserved fields with other than default values
may produce undefined results.

Note: The host must not drive RWDS during a write to register space.

Note: The RWDS signal is driven by the memory during the CA period based on whether the memory array is being
refreshed. This refresh indication does not affect the writing of register data.

Note: The RWDS signal returns to high impedance after the CA period. Register data is never masked. Both data bytes
of the register data are loaded into the selected register.

Reading of a register is accomplished with read transaction with single or double initial latency using a single 16 bit read
transaction. If more than one word is read, the same register value is repeated in each word read. The contents of the
register is returned in the same manner as reading array data, with one or two latency counts, based on the state of
RWDS during the CA period. The latency count is defined in the Configuration Register 0 Read Latency field (CR0[7:4]).

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 19 -

<!-- page 20 -->

# W958D6NBKX

9.3 Device Identification Registers
There are two read only, non-volatile, word registers, that provide information on the device selected when CS# is low.
The device information fields identify:
◼ Manufacture
◼ Type
◼ Density

– Row address bit count
– Column address bit count

Table 6 - ID Register 0 Bit Assignments

| Bits |
|---|
| [15:14] |
| [13] |
| [12:8] |
| [7:4] |
| [3:0] |
| Bits |
| [15:4] |
| [3:0] |
| 9.4 Configuration Register |

| Function |
|---|
| Reserved |
| Reserved |
| Row Address Bit Count |
| Column Address Bit Count |
| Manufacturer |
| Table 7 - ID Register |
| Function |
| Reserved |
| Device Type |

| Settings (Binary) |
|---|
| 00b - (default) |
| 0b - (default) |
| 01110b - Fifteen Row address bits |
| 0111b - Eight column address bits |
| 0110b - Winbond |
| 1 Bit Assignments |
| Settings (Binary) |
| 0000_0000_0000b (default) |
| 1001b - HyperRAM 3.0 Others - Reserved |

9.4 Configuration Register 0
Configuration Register 0 (CR0) is used to define the power state and access protocol operating conditions for the
HyperRAM device. Configurable characteristics include:
◼ Wrapped Burst Length (16, 32, 64, or 128 data(16-bits) aligned and length data group)
◼ Wrapped Burst Type

– Legacy wrapped burst (sequential access with wrap around within a selected length and aligned group)
– Hybrid burst (Legacy wrapped burst once then linear burst at start of the next sequential group)
◼ Initial Latency
◼ Variable Latency

– Whether an array read or write transaction will use fixed or variable latency. If fixed latency is selected the memory

will always indicate a refresh latency and delay the read data transfer accordingly. If variable latency is selected,
latency for a refresh is only added when a refresh is required at the same time a new transaction is starting.
◼ Output Drive Strength
◼ Deep Power Down Mode

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 20 -

<!-- page 21 -->

# W958D6NBKX

Table 8 - Configuration Register 0 Bit Assignments

| Function |
|---|
| Deep Power Down Enable |
| Drive Strength |
| Reserved |
| Initial Latency |
| Fixed Latency Enable |
| Hybrid Burst Enable |

| Settings (Binary) |
|---|
| 1b - Normal operation (default) 0b - Writing 0 to CR0[15] causes the device to enter Deep Power Down (DPD) Note: 1: HyperRAM will automatically set the value of CR0[15] to “1” after exit DPD. |
| 000b - 34 ohms (default) 001b - 115 ohms 010b - 67 ohms 011b - 46 ohms 100b - 34 ohms 101b - 27 ohms 110b - 22 ohms 111b - 19 ohms |
| 1b - Reserved (default) Reserved for Future Use. When writing this register, these bits should be set to 1 for future compatibility. |
| 0000b - 5 Clock Latency for clock rate ≤ 133MHz 0001b - 6 Clock Latency for clock rate ≤ 166MHz 0010b - 7 Clock Latency for clock rate ≤ 200MHz (default) 0010b - 7 Clock Latency for clock rate ≤ 250MHz 0011b - Reserved 0100b - Reserved ... 1101b - Reserved 1110b - 3 Clock Latency for clock rate ≤ 85MHz 1111b - 4 Clock Latency for clock rate ≤ 104MHz |
| 0b - Variable Latency – 1 or 2 times Initial Latency depending on RWDS during CA cycles. 1b - Fixed 2 times Initial Latency (default) |
| 0b: Wrapped burst sequences to follow hybrid burst sequencing 1b: Wrapped burst sequences in legacy wrapped burst manner (default) |
| 00b - 128 |

00b - 128
01b - 64
10b - 16
11b - 32 (default)

[1:0]
Burst Length

9.4.1
Wrapped Burst
A wrapped burst transaction accesses memory within a group of data(16-bits) aligned on a 16-bits boundary matching
the length of the configured group. Wrapped access groups can be configured as 16, 32, 64, or 128 data(16-bits)
alignment and length. During wrapped transactions, access starts at the CA selected location within the group, continues
to the end of the configured 16-bits group aligned boundary, then wraps around to the beginning location in the group,
then continues back to the starting location. Wrapped bursts are generally used for critical 16-bits first instruction or data
cache line fill read accesses.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 21 -

<!-- page 22 -->

# W958D6NBKX

9.4.2
Hybrid Burst
The beginning of a hybrid burst will wrap within the target address wrapped burst group length before continuing to the
next half-page of data beyond the end of the wrap group. Continued access is in linear burst order until the transfer is
ended by returning CS# High. This hybrid of a wrapped burst followed by a linear burst starting at the beginning of the
next burst group, allows multiple sequential address cache lines to be filled in a single access. The first cache line is
filled starting at the critical 16-bits. Then the next sequential line in memory can be read in to the cache while the first
line is being processed.

Table 9 - CR0[2] Control of Wrapped Burst Sequence

| Name |
|---|
| Hybrid Burst Enable CR0[2]= 0b: Wrapped burst sequences to follow hybrid burst sequencing CR0[2]= 1b: Wrapped burst sequences in legacy wrapped burst manner |

Table 10 - Example Wrapped Burst Sequences (HyperRAM Addressing)

| Address Sequence (Hex) of Data(32-bits) |
|---|
| 03, 04, 05, 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 1A, 1B, 1C, 1D, 1E, 1F, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 2A, 2B, 2C, 2D, 2E, 2F, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 00, 01, 02 (Wrap complete, now linear beyond the end of the initial 128 wrap group) 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| 03, 04, 05, 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 1A, 1B, 1C, 1D, 1E, 1F, 00, 01, 02, (Wrap complete, now linear beyond the end of the initial 64 wrap group) 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 2A, 2B, 2C, 2D, 2E, 2F, 30, 31, ... |
| 2E, 2F, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 2A, 2B, 2C, 2D, (Wrap complete, now linear beyond the end of the initial 64 wrap group) 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, ... |
| 02, 03, 04, 05, 06, 07, 00, 01, (Wrap complete, now linear beyond the end of the initial 16 wrap group) 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, ... |
| 0C, 0D, 0E, 0F, 08, 09, 0A, 0B, (Wrap complete, now linear beyond the end of the initial 16 wrap group) 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 1A, ... |
| 0A, 0B, 0C, 0D, 0E, 0F, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09 (Wrap complete, now linear beyond the end of the initial 32 wrap group) 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 1A, ... |
| 03, 04, 05, 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 1A, 1B, 1C, 1D, 1E, 1F, 00, 01, 02, ... |
| 2E, 2F, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 3C, 3D, 3E, 3F, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 2A, 2B, 2C, 2D, ... |
| 02, 03, 04, 05, 06, 07, 00, 01, ... |
| 0C, 0D, 0E, 0F, 08, 09, 0A, 0B, ... |
| 0A, 0B, 0C, 0D, 0E, 0F, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, ... |
| 03, 04, 05, 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F, 10, 11, 12, 13, 14, 15, 16, 17, 18, ... |

Burst Type
Wrap Boundary

Start Address

(16-bits)

Hybrid 128
128 Wrap once
then Linear
XXXXXX03

Hybrid 64
64 Wrap once
then Linear
XXXXXX03

Hybrid 64
64 Wrap once
then Linear
XXXXXX2E

Hybrid 16
16 Wrap once
then Linear
XXXXXX02

Hybrid 16
16 Wrap once
then Linear
XXXXXX0C

Hybrid 32
32 Wrap once
then Linear
XXXXXX0A

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 22 -

<!-- page 23 -->

# W958D6NBKX

9.4.3
Initial Latency
Memory Space read and writes transactions or Register Space read transactions require some initial latency to open
the row selected by the CA. This initial latency is tACC. The number of latency clocks needed to satisfy tACC depends on
the HyperRAM clock input frequency and can vary from 3 to 7 clocks. The value in CR0[7:4] selects the number of clocks
for initial latency. The default value is 7 clocks, allowing for operation up to a maximum frequency of 250MHz prior to
the host system setting a lower initial latency value that may be more optimal for the system.

In the event a distributed refresh is required at the time a Memory Space read or write transaction or Register Space
read transaction begins, the RWDS signals goes High during the CA to indicate that an additional initial latency is being
inserted to allow a refresh operation to complete before opening the selected row.

Register Space write transactions always have zero initial latency. RWDS may be High or Low during the CA period.
The level of RWDS during the CA period does not affect the placement of register data immediately after the CA, as
there is no initial latency needed to capture the register data. A refresh operation may be performed in the memory array
in parallel with the capture of register data.

9.4.4
Fixed Latency
A configuration register option bit CR0[3] is provided to make all Memory Space read and write transactions or Register
Space read transactions require the same initial latency by always driving RWDS High during the CA to indicate that
two initial latency periods are required. This fixed initial latency is independent of any need for a distributed refresh, it
simply provides a fixed (deterministic) initial latency for all of these transaction types. The fixed latency option may
simplify the design of some HyperBus-Extend-IO memory controllers or ensure deterministic transaction performance.
Fixed latency is the default POR or reset configuration. The system may clear this configuration bit to disable fixed
latency and allow variable initial latency with RWDS driven High only when additional latency for a refresh is required.

9.4.5
Drive Strength
DQ and RWDS signal line loading, length, and impedance vary depending on each system design. Configuration register
bits CR0[14:12] provide a means to adjust the DQ[7:0] and RWDS signal output impedance to customize the DQ and
RWDS signal impedance to the system conditions to minimize high speed signal behaviors such as overshoot,
undershoot, and ringing. The default POR or reset configuration value is 000b to select the mid-point of the available
output impedance options.

The impedance values shown are typical for both pull-up and pull-down drivers at typical silicon process conditions,
nominal operating voltage (1.8V) and 50°C. The impedance values may vary from the typical values depending on the
Process, Voltage, and Temperature (PVT) conditions. Impedance will increase with slower process, lower voltage, or
higher temperature. Impedance will decrease with faster process, higher voltage, or lower temperature.

Each system design should evaluate the data signal integrity across the operating voltage and temperature ranges to
select the best drive strength settings for the operating conditions.

9.4.6
Deep Power Down
When the HyperRAM device is not needed for system operation, it may be placed in a very low power consuming state
called Deep Power Down (DPD), by writing 0 to CR0[15]. When CR0[15] is cleared to 0, the device enters the DPD state
within tDPDIN time and all refresh operations stop. The data in RAM is lost, (becomes invalid without refresh) during DPD
state. Exiting DPD requires driving CS# Low then High, POR, or a reset. Only CS# and RESET# signals are monitored
during DPD mode. All register content might lost in Deep Power Down State.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 23 -

<!-- page 24 -->

# W958D6NBKX

9.5 Configuration Register 1
Configuration Register 1 (CR1) is used to define the refresh array size, refresh rate and Hybrid Sleep for the HyperRAM
device. Configurable characteristics include:

◼ Partial Array Refresh
◼ Hybrid Sleep State
◼ Refresh Rate

Table 11 - Configuration Register 1 Bit Assignments

| Function |
|---|
| Reserved |
| Reserved |
| Master Clock Type |
| Hybrid Sleep |
| Partial Array Refresh |

| Settings (Binary) |
|---|
| FFh - Reserved (default) Reserved for Future Use. When writing this register, these bits should keep FFh for future compatibility. |
| 1b - Reserved (default) When writing this register, this bit should keep 1b. |
| 1b - Single Ended - CK (default) 0b - Differential - CK#, CK |
| 1b - Writing 1 to CR1[5] causes the device to enter Hybrid Sleep (HS) State 0b - Normal operation (default) |
| 000b - Full Array (default) 001b - Bottom 1/2 Array 010b - Bottom 1/4 Array 011b - Bottom 1/8 Array 100b - Reserved 101b - Top 1/2 Array 110b - Top 1/4 Array 111b - Top 1/8 Array |
| 10b - Reserved 11b - Reserved 00b - Reserved 01b - 4μS (tCSM) |

[1:0]*1
Distributed Refresh Interval

Note:
1. CR1[1:0] is read only.

9.5.1
Master Clock Type
Two clock types, namely single ended and differential, are supported by HyperRAM. CR1[6] selects which type to use.

9.5.2
Partial Array Refresh
The partial array refresh configuration restricts the refresh operation in HyperRAM device to a portion of the memory
array specified by CR1[4:2]. This reduces the standby current. The default configuration refreshes the whole array.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 24 -

<!-- page 25 -->

# W958D6NBKX

9.5.3
Hybrid Sleep
When the HyperRAM device is not needed for system operation, it may be placed in Hybrid Sleep state if data in the
device needs to be retained. Enter Hybrid Sleep state by writing 1 to CR1[5]. Bringing CS# Low will cause the device to
exit HS state and set CR1[5] to 0. Also, POR, or a hardware reset will cause the device to exit Hybrid Sleep state. Note
that a POR or a hardware reset disables refresh where the memory core data can potentially get lost.

9.5.4
Distributed Refresh Interval
The HyperRAM device is built with volatile memory array which requires periodic refresh of all bits in the array. The
refresh operation can be done by an internal self-refresh logic that will evenly refresh the memory array automatically.

The automatic refresh operation can only be done when the memory array is not being actively read or written by the
host system. The refresh logic waits for the end of any active read or write before doing a refresh, if a refresh is needed
at that time. If a new read or write begins before the refresh is completed, the memory will drive RWDS high during the
CA period to indicate that an additional initial latency time is required at the start of the new access in order to allow the
refresh operation to complete before starting the new access.

The evenly distributed refresh operations requires a maximum refresh interval between two adjacent refresh operations.
The maximum distributed refresh interval will varies with temperature as shown in Table 12 - Distributed Refresh Interval
per Temperature.

Table 12 - Distributed Refresh Interval per Temperature

| Device Temperature (TCASE °C) |
|---|
| TCASE < 85 |

| Maximum Distributed Refresh Interval (µS) |
|---|
| 4 |

The distributed refresh operation requires that the host does not do burst transactions longer than the distributed refresh
interval to prevent the memory from unable doing the distributed refreshes operation when it is needed.

This sets an upper limit on the length of read and write transactions so that the automatic distributed refresh operation
can be done between transactions. This limit is called the CS# low maximum time (tCSM) and the tCSM will be equal to
the maximum distributed refresh interval.

The host system is required to respect the tCSM value by ending each transaction before violating tCSM. This can be
done by host memory controller logic splitting long transactions when reaching the tCSM limit, or by host system hardware
or software not performing a single read or write transaction that would be longer than tCSM.

As noted in Table 12 of distributed refresh interval, the maximum refresh interval is longer at lower temperatures such
that tCSM could be increased to allow longer transactions. The host system can either use the CR1[1:0] value from the
table for the maximum operating temperature or, may determine the current operating temperature from a temperature
sensor in the system in order to set a longer distributed refresh interval.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 25 -

<!-- page 26 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 26 - 
10. INTERFACE STATES 
10.1 IO condition of interface states 
Below Interface States table describes the required value of each signal for each interface state. 
Table 13 - Interface States 
Interface State 
VCC / VCCQ 
CS# 
CK, CK# 
DQ15-DQ0 
RWDS[1:0] 
RESET# 
Power-Off 
< VLKO 
X 
X 
High-Z 
High-Z 
X 
Power-On (Cold) Reset 
≥ VCC / VCCQ min 
X 
X 
High-Z 
High-Z 
X 
Hardware (Warm) Reset 
≥ VCC / VCCQ min 
X 
X 
High-Z 
High-Z 
L 
Interface Standby 
≥ VCC / VCCQ min 
H 
X 
High-Z 
High-Z 
H 
CA 
≥ VCC / VCCQ min 
L 
T 
Master Output Valid 
X 
H 
Read Initial Access Latency 
(data bus turn around period) 
≥ VCC / VCCQ min 
L 
T 
High-Z 
L 
H 
Write Initial Access Latency 
(RWDS turn around period) 
≥ VCC / VCCQ min 
L 
T 
High-Z 
High-Z 
H 
Read data transfer 
≥ VCC / VCCQ min 
L 
T 
Slave Output Valid 
Slave Output Valid  
X or T 
H 
Write data transfer with Initial 
Latency 
≥ VCC / VCCQ min 
L 
T 
Master Output Valid 
Master Output Valid 
X or T 
H 
Write data transfer without Initial 
Latency *1 
≥ VCC / VCCQ min 
L 
T 
Master Output Valid 
Slave Output L or 
High-Z 
H 
Active Clock Stop 
≥ VCC / VCCQ min 
L 
Idle 
Master or Slave Output 
Valid or High-Z 
X 
H 
Deep Power Down 
≥ VCC / VCCQ min 
H 
X or T 
High-Z 
High-Z 
H 
Hybrid Sleep 
≥ VCC / VCCQ min 
H 
X or T 
High-Z 
High-Z 
H 
Legend 
L = VIL 
H = VIH 
X = either VIL, VIH, VOL or VOH 
L/H = rising edge 
H/L = falling edge 
T = Toggling during information transfer 
Idle = CK is Low and CK# is High. 
Valid = all bus signals have stable L or H level 
 
Note: 
1. Writes without initial latency (with zero initial latency), do not have a turnaround period for RWDS[1:0]. The HyperRAM device 
will always drive RWDS[1:0] during the CA period to indicate whether extended latency is required. Since master write data 
immediately follows the CA period the HyperRAM device may continue to drive RWDS[1:0] Low or may take RWDS[1:0] to 
High-Z. The master must not drive RWDS[1:0] during Writes with zero latency. Writes with zero latency do not use RWDS[1:0] 
as a data mask function. All write data are written.

<!-- page 27 -->

# W958D6NBKX

10.2 Power Conservation Modes
10.2.1 Interface Standby
Standby is the default, low power, state for the interface while the device is not selected by the host for data transfer
(CS#= High). The HyperRAM device will stay at interface standby state when CS# = High, CK, CK# = 0 or 1, and
RESET# = High. When the HyperRAM device staying at interface standby state, it will not drive the DQs pin and RWDS
pin and only monitor the status of CS# and RESET# input pins.
10.2.2 Active Clock Stop
The Active Clock Stop state reduces device interface energy consumption to the ICC6 level during the data transfer
portion of a read or write operation. The device automatically enables this state when clock remains stable for tACC + 30
nS. While in Active Clock Stop state, read data is latched and always driven onto the data bus. Active Clock Stop state
helps reduce current consumption when the host system clock has stopped to pause the data transfer. Even though
CS# may be Low throughout these extended data transfer cycles, the memory device host interface will go into the
Active Clock Stop current level at tACC + 30 nS. This allows the device to transition into a lower current state if the data
transfer is stalled. Active read or write current will resume once the data transfer is restarted with a toggling clock. The
Active Clock Stop state must not be used in violation of the tCSM limit. CS# must go High before tCSM is violated. Note
that it is recommended to stop the clock when it is in Low state.

CS#

CK#,CK

Clock Stopped

Latency Count (1X)

RWDS[1:0]

Low: 1X Latency Count

RWDS & Data are edge aligned

DoutB
[15:0]

47:40
39:32
31:24
23:16
15:8
7:0
DoutA

DoutA+1

DoutB+1

DQ[15:0]

Output Driven

[15:0]

[15:0]

[15:0]

Command - Address
Read Data

Figure 13 - Active Clock Stop during Read Transaction (DDR)
Note: DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive

DQ[15:8] to “H” or “L”.
10.2.3 Hybrid Sleep
In the Hybrid Sleep (HS) state, the current consumption is reduced (IHS). HS state is entered by writing a 1 to CR1[5].
The device reduces power within tHSIN time. The data in Memory Space and Register Space is retained during HS state.
Bringing CS# Low will cause the device to exit HS state and set CR1[5] to 0. Also, POR, or a hardware reset will cause
the device to exit HS state. Returning to Standby state requires tEXTHS time. Following the exit from HS due to any of
these events, the device is in the same state as entering HS.

CS#

CK#,CK

RWDS[1:0]

tHSIN

DQ[7:0]

47:40
39:32
31:24
23:16
15:8
7:0
15:8
7:0

Command - Address
Write Data

HS

Enter Hybrid Sleep

CR1 Value

Figure 14 - Enter Hybrid Sleep Transaction

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 27 -

<!-- page 28 -->

# W958D6NBKX

Note: DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive

DQ[15:8] to “H” or “L”.

## CS#

tCSHS
tEXTHS

Figure 15 - Exit Hybrid Sleep Transaction

10.2.4 Deep Power Down
In the Deep Power down (DPD) state, current consumption is driven to the lowest possible level (IDPD). DPD state is
entered by writing a 0 to CR0[15]. The device reduces power within tDPDIN time and all refresh operations stop. The data
in Memory Space is lost, (becomes invalid without refresh) during DPD state. Driving CS# Low then High will cause the
device to exit DPD state. Also, POR, or a hardware reset will cause the device to exit DPD state. Returning to Standby
state requires tEXTDPD time. Returning to Standby state following a POR requires tVCS time, as with any other POR.
Following the exit from DPD due to any of these events, the device is in the same state as following POR.

CS#

CK#,CK

RWDS[1:0]

tDPDIN

DQ[7:0]

47:40
39:32
31:24
23:16
15:8
7:0
15:8
7:0

Command - Address
Write Data

DPD

Enter Deep Power Down

CR0 Value

tDPDIN

Figure 16 - Enter DPD Transaction

Note: DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive

DQ[15:8] to “H” or “L”.

# CS#

tCSDPD
tEXTDPD

Figure 17 - Exit DPD Transaction

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 28 -

<!-- page 29 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 29 - 
11. ELECTRICAL SPECIFICATIONS 
11.1 Absolute Maximum Ratings 
Parameter 
Min 
Max 
Unit 
Notes 
Voltage on VCC, VCCQ supply relative to VSS 
-0.5 
VCC +0.5 
V 
1 
Voltage to any ball except VCC relative to VSS 
-0.5 
VCC +0.5 
V 
1 
Soldering temperature and time 10s (solder ball only) 
+260 
°C 
1 
Storage temperature (plastic) 
-65 
+150 
°C 
1 
Output Short Circuit Current 
 
100 
mA 
1, 2 
Notes: 
1. Stresses above those listed under Absolute Maximum Ratings may cause permanent damage to the device. This is a stress 
rating only; functional operation of the device at these or any other conditions above those indicated in the operational sections 
of this data sheet is not implied. Exposure of the device to absolute maximum rating conditions for extended periods may affect 
device reliability. 
2. No more than one output may be shorted to ground at a time. Duration of the short circuit should not be greater than one second. 
11.2 Latch up Characteristics 
Table 14 - Latch up Specification 
Description 
Min 
Max 
Unit 
Input voltage with respect to VSS on all input only connections 
-1.0 
VCC + 1.0 
V 
Input voltage with respect to VSSQ on all I/O connections 
-1.0 
VCCQ + 1.0 
V 
VCCQ Current 
-100 
+100 
mA 
Note: 
1. Excludes power supplies VCC/VCCQ. Test conditions: VCC = VCCQ, one connection at a time tested, connections not being tested 
are at VSS. 
11.3 Operating Ranges 
11.3.1 DC Characteristics 
Parameter 
Description 
Test Conditions 
Min 
Max 
Unit 
VCC, VCCQ 
Power Supply (typical 1.8V) 
 
1.7 
2.0 
V 
VIL 
Input Low Voltage 
 
-0.15 x VCC 
0.3 x VCC 
V 
VIH 
Input High Voltage 
 
0.7 x VCC 
1.15 x VCC 
V 
VOL 
Output Low Voltage 
IOL = 100µA for DQ[15:0] 
− 
0.2 
V 
VOH 
Output High Voltage 
IOH = 100µA for DQ[15:0] 
VCCQ - 0.2 
− 
V 
Note: 
1. All parts list in order information table (section 2) will not guarantee to meet functional and AC specification if the VCC, VCCQ 
operation condition out of range mentioned in above table. 
11.3.2 Operating Temperature 
Parameter 
Symbol 
Range 
Unit 
Notes 
Operating Temperature 
TCASE 
-40~85 
°C 
1 
Note: 
1. All parts list in order information table (section 2) will not guarantee to meet functional and AC specification if the operation 
temperature range out of range mentioned in above table.

<!-- page 30 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 30 - 
11.3.3 ICC Characteristics 
Parameter Description 
Test Conditions 
Min 
Typ*1 
Max 
Unit 
ILI2 
Input Leakage Current 
Reset Signal High Only 
VIN = VSS to VCC, VCC = VCC max 
– 
– 
2 
µA 
ILI4 
Input Leakage Current 
Reset Signal Low Only *2 
VIN = VSS to VCC, VCC = VCC max 
– 
– 
15 
µA 
ICC1 
VCC Active Read Current 
(-40°C to +85°C) 
CS# = VIL, @200 MHz, VCC = VCC max 
– 
12 
20 
mA 
CS# = VIL, @250 MHz, VCC = VCC max 
– 
14 
20 
mA 
ICC2 
VCC Active Write Current 
(-40°C to +85°C) 
CS# = VIL, @200 MHz, VCC = VCC max 
– 
13 
22 
mA 
CS# = VIL, @250 MHz, VCC = VCC max 
– 
15 
22 
mA 
ICC5 
Reset Current 
CS# = VIH, RESET# = VIL, 
VCC = VCC max 
– 
– 
550 
µA 
ICC6 
Active Clock Stop Current 
(-40°C to +85°C) 
CS# = VIL, RESET# = VIH, 
VCC = VCC max 
– 
– 
13 
mA 
ICC7 
VCC Current during power up*1 
CS# = VIH, VCC = VCC max 
– 
– 
35 
mA 
IDPD 
Deep Power Down Current (85°C) 
CS# = VIH, VCC = VCC max 
– 
– 
12 
µA 
 
 
Parameter 
Description 
Test Conditions 
 
Min 
Typ*1 
Max 
Unit 
ICC4 
VCC Standby Current 
(-40°C to +85°C) 
CS# = VIH, VCC = VCC max 
Full Array 
– 
80 
1200 
µA 
Bottom 1/2 Array 
– 
65 
850 
Bottom 1/4 Array 
– 
60 
700 
Bottom 1/8 Array 
– 
55 
600 
Top 1/2 Array 
– 
65 
850 
Top 1/4 Array 
– 
60 
700 
Top 1/8 Array 
– 
55 
600 
IHS 
Hybrid Sleep Current (85°C) 
CS# = VIH, VCC = VCC max 
Full Array 
– 
35 
1100 
µA 
Bottom 1/2 Array 
– 
30 
800 
Bottom 1/4 Array 
– 
25 
600 
Bottom 1/8 Array 
– 
22 
500 
Top 1/2 Array 
– 
30 
800 
Top 1/4 Array 
– 
25 
600 
Top 1/8 Array 
– 
22 
500 
Notes: 
1. Typical values are referring to the median average value measured @ TCASE=25°C and for reference only, not tested in mass production 
process. 
2. RESET# Low initiates exits from DPD state and initiates the draw of ICC5 reset current, making ILI during Reset# Low insignificant.

<!-- page 31 -->

# W958D6NBKX

11.3.4 Power-Up Initialization
The HyperRAM device include an on-chip voltage sensor used to launch the power-up initialization process. VCC and
VCCQ must be applied simultaneously. When the power supply reaches a stable level at or above VCC (min), the device
will require tVCS time to complete its self-initialization process.

The device must not be selected during power-up. CS# must follow the voltage applied on VCCQ until VCC (min) is
reached during power-up, and then CS# must remain high for a further delay of tVCS. A simple pull-up resistor from
VCCQ to Chip Select (CS#) can be used to insure safe and proper power-up.

If RESET# is Low during power up, the device delays start of the tVCS period until RESET# is High. The tVCS period is
used primarily to perform refresh operations on the DRAM array to initialize it.
When initialization is complete, the device is ready for normal operation.

## VCC Minimum VCC_VCCQ

tVCS

## CS#

## RESET#

Figure 18 - Power-up with RESET# High

## VCC Minimum VCC_VCCQ

## CS#

tVCS

## RESET#

Figure 19 - Power-up with RESET# Low

Table 15 - Power Up and Reset Parameters

| Description |
|---|
| VCC Power Supply (typical 1.8V) |
| VCC and VCCQ ≥ minimum and RESET# High to first access |

Notes:
1. Bus transactions (read and write) are not allowed during the power-up reset time (tVCS).
2. VCCQ must be the same voltage as VCC.
3. VCC ramp rate may be non-linear.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 31 -

<!-- page 32 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 32 - 
11.3.5 Power-Down 
The HyperRAM devices are considered to be powered-off when the array power supply (VCC) drops below the VCC 
Lock-Out voltage (VLKO). During a power supply transition down to the VSS level, VCCQ should remain less than or equal 
to VCC. At the VLKO level, the HyperRAM device will have lost configuration or array data. 
VCC must always be greater than or equal to VCCQ (VCC ≥ VCCQ). 
During Power-Down or voltage drops below VLKO, the array power supply voltages must also drop below VCC Reset 
(VRST) for a Power Down period (tPD) for the part to initialize correctly when the power supply again rises to VCC 
minimum. See Figure 20 - Power Down or Voltage Drop. 
If during a voltage drop the VCC stays above VLKO the part will stay initialized and will work correctly when VCC is again 
above VCC minimum. If VCC does not go below and remain below VRST for greater than tPD, then there is no assurance 
that the POR process will be performed. In this case, a hardware reset will be required ensure the HyperRAM device is 
properly initialized. 
VCC
VCC (Max)
VCC (Min)
VLKO 
VRST 
Time
tVCS
tPD
 
Figure 20 - Power Down or Voltage Drop 
The following section describes HyperRAM device dependent aspects of power down specifications. 
 
Table 16 - Power-Down Voltage and Timing 
Parameter 
Description 
Min 
Max 
Unit 
VCC 
VCC Power Supply (typical 1.8V) 
1.7 
2.0 
V 
VLKO 
VCC Lock-out below which re-initialization is required 
1.5 
– 
V 
VRST 
VCC Low Voltage needed to ensure initialization will occur 
0.7 
– 
V 
tPD 
Duration of VCC ≤ VRST 
50 
– 
µS 
Note: VCC ramp rate can be non-linear.

<!-- page 33 -->

# W958D6NBKX

11.3.6 Hardware Reset
The RESET# input provides a hardware method of returning the device to the standby state.

During tRPH the device will draw ICC5 current. If RESET# continues to be held Low beyond tRPH, the device draws CMOS
standby current (ICC4). While RESET# is Low (during tRP), and during tRPH, bus transactions are not allowed.

A Hardware Reset will:

◼ Cause the configuration registers to return to their default values
◼ Halt self-refresh operation while RESET# is low - memory array data is considered as invalid
◼ Force the device to exit the Hybrid Sleep state
◼ Force the device to exit the Deep Power Down state
After RESET# returns High, the self-refresh operation will resume. Because self-refresh operation is stopped during
RESET# Low, and the self-refresh row counter is reset to its default value, some rows may not be refreshed within the
required array refresh interval per Table 12 - Distributed Refresh Interval per Temperature on page 25. This may result
in the loss of DRAM array data during or immediately following a hardware reset. The host system should assume DRAM
array data is lost after hardware reset and reload any required data.

tRP

RESET#

tRH

tRPH

CS#

Figure 21 - Hardware Reset Timing Diagram

Table 17 - Power Up and Reset Parameters

| Description |
|---|
| RESET# Pulse Width |
| Time between RESET# (High) and CS# (Low) |
| RESET# Low to CS# Low |

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 33 -

<!-- page 34 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 34 - 
11.3.7 Capacitance Characteristics 
Table 18 - Capacitive Characteristics 
Parameter 
Description 
Min 
Max 
Unit 
CI 
Input Capacitance (CK, CK#, CS#) 
 
3.0 
pF 
CID 
Delta Input Capacitance (CK, CK#) 
 
0.25 
pF 
CO 
Output Capacitance (RWDS[1:0]) 
 
3.0 
pF 
CIO 
IO Capacitance (DQx) 
 
3.0 
pF 
CIOD 
IO Capacitance Delta (DQx) 
 
0.25 
pF 
Notes: 
1. These values are guaranteed by design and are tested on a sample basis only. 
2. These values are applies to die device only (does not include package capacitance). 
3. Contact capacitance is measured according to JEP147 procedure for measuring capacitance using a vector network analyzer. 
VCC, VCCQ are applied and all other signals (except the signal under test) floating. DQ’s should be in the high impedance state. 
4. The capacitance values for the CK, CK#, RWDS[1:0] and DQx signals must have similar capacitance values to allow for signal 
propagation time matching in the system. The capacitance value for CS# is not as critical because there are no critical timings 
between CS# going active (Low) and data being presented on the DQs bus. 
11.4 Input Signal Overshoot 
During DC conditions, input or I/O signals should remain equal to or between VSS and VCC. During voltage transitions, 
inputs or I/Os may negative overshoot VSS to -1.0V or positive overshoot to VCC +1.0V, for periods up to 20 nS. 
 
 
 
 
 
 
Figure 22 - Maximum Negative Overshoot Waveform 
 
 
 
 
 
 
 
Figure 23 - Maximum Positive Overshoot Waveform 
 
 
≤ 20 ns
VCCQ + 1.0V
VSSQ to VCCQ
≤ 20 ns
- 1.0V
VSSQ to VCCQ

<!-- page 35 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 35 - 
12. TIMING SPECIFICATIONS 
The following section describes HyperRAM device dependent aspects of timing specifications. 
12.1 Key to Switching Waveforms 
 
Valid_High_or_Low
High_to_Low_Transition
Low_to_High_Transition
Invalid
High_Impedance
 
12.2 AC Test Conditions 
Device 
under 
test
CL
 
Figure 24 - Test load reference 
Table 19 - Test Specification 
Description 
All 
Unit 
Notes 
Output Load Capacitance, CL 
15 
pF 
 
Minimum Input Rise and Fall Slew Rates 
1.13 
V/nS 
1 
Input Pulse Levels 
0-VCCQ 
V 
 
Input timing measurement reference levels 
VCCQ/2 
V 
2 
Output timing measurement reference levels 
VCCQ/2 
V 
2 
Notes: 
1. All AC timings assume this input slew rate. 
2. Input and output timing is referenced to VCCQ/2 for single ended clock or RWDS or referenced to the crossing of CK/CK# for 
the differential clock pair. 
VCCQ
VSS
Input VCCQ / 2
VCCQ / 2 Output
Measurement Level
 
 
Figure 25 - Input Waveforms and Measurement Levels

<!-- page 36 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 36 - 
12.3 AC Characteristics 
12.3.1 Read Transactions 
Table 20 - HyperRAM Specific Read Timing Parameters 
Description 
Parameter 
250 MHz 
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
Min 
Max 
Chip Select High Between Transactions 
tCSHI 
6 
– 
6 
– 
6 
– 
7.5 
– 
nS 
HyperRAM Read-Write Recovery Time 
tRWR 
35 
– 
35 
– 
36 
– 
37.5 
– 
nS 
Chip Select Setup to next CK Rising Edge 
tCSS 
4 
– 
4 
– 
3 
– 
3 
– 
nS 
Data Strobe Valid 
tDSV 
– 
5 
– 
5 
– 
12 
– 
12 
nS 
Input Setup Time 
tIS 
0.5 
– 
0.5 
– 
0.6 
– 
0.8 
– 
nS 
Input Hold Time 
tIH 
0.5 
– 
0.5 
– 
0.6 
– 
0.8 
– 
nS 
HyperRAM Read Initial Access Time 
tACC 
28 
– 
35 
– 
36 
– 
37.5 
– 
nS 
Clock to DQs Low Z 
tDQLZ 
0 
– 
0 
– 
0 
– 
0 
– 
nS 
CK transition to DQ Valid 
tCKD 
1 
5 
1 
5 
1 
5.5 
1 
5.5 
nS 
CK transition to DQ Invalid 
tCKDI 
0 
4.2 
0 
4.2 
0 
4.6 
0 
4.5 
nS 
Data Valid 
(tDV min = tCKHP min - tCKD max + tCKDI max) 
tDV 
1 
– 
1.45 
– 
1.8 
– 
2.375 
– 
nS 
CK transition to RWDS Valid 
tCKDS 
1 
5 
1 
5 
1 
5.5 
1 
5.5 
nS 
RWDS transition to DQ Valid 
tDSS 
-0.4 
+0.4 
-0.4 
+0.4 
-0.45 
+0.45 
-0.6 
+0.6 
nS 
RWDS transition to DQ Invalid 
tDSH 
-0.4 
+0.4 
-0.4 
+0.4 
-0.45 
+0.45 
-0.6 
+0.6 
nS 
Chip Select Hold After CK Falling Edge 
tCSH 
0 
– 
0 
– 
0 
– 
0 
– 
nS 
Chip Select Inactive to RWDS High-Z 
tDSZ 
– 
5 
– 
5 
– 
6 
– 
6 
nS 
Chip Select Inactive to DQ High-Z 
tOZ 
– 
5 
– 
5 
– 
6 
– 
6 
nS 
HyperRAM Chip Select Maximum Low Time 
(TCASE < 85°C) 
tCSM 
– 
4 
– 
4 
– 
4 
– 
4 
µS 
Refresh Time 
tRFH 
28 
– 
35 
– 
36 
– 
37.5 
– 
nS 
CK transition to RWDS Low @CA phase 
@Read 
tCKDSR 
1 
5.5 
1 
5.5 
1 
5.5 
1 
5.5 
nS

<!-- page 37 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 37 - 
 
CK#
CK
tCK 
tCKHP 
tCKHP 
VCCQ / 2
VIX(Max)
VIX(Min)
 
Figure 26 - Clock Characteristics 
 
Table 21 - Clock Timings 
Description 
Parameter 
250 MHz 
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
Min 
Max 
CK Period 
tCK 
4 
100 
5 
100 
6 
100 
7.5 
100 
nS 
CK Half Period - Duty Cycle 
tCKHP 
0.45 
0.55 
0.45 
0.55 
0.45 
0.55 
0.45 
0.55 
tCK 
CK Half Period at Frequency 
Min = 0.45 tCK Min 
Max = 0.55 tCK Min 
tCKHP 
1.8 
2.2 
2.25 
2.75 
2.7 
3.3 
3.375 
4.125 
nS 
Notes: 
1. Clock jitter of ±5% is permitted. 
2. Minimum Frequency (Maximum tCK) is dependent upon maximum CS# Low time (tCSM), Initial Latency and Burst Length. 
3. All parts list in order information table (section 2) will not guarantee to meet functional and AC specification if the tCK and 
tCKHP out of range mentioned in above table.

<!-- page 38 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 38 - 
 
Table 22 - Clock AC/DC Electrical Characteristics 
Description 
Parameter 
Min 
Max 
Unit 
DC Input Voltage 
VIN 
-0.3 
VCCQ + 0.3 
V 
DC Input Differential Voltage 
VID(DC) 
VCCQ x 0.4 
VCCQ + 0.6 
V 
AC Input Differential Voltage 
VID(AC) 
VCCQ x 0.6 
VCCQ + 0.6 
V 
AC Differential Crossing Voltage 
VIX 
VCCQ x 0.4 
VCCQ x 0.6 
V 
 
Differential Clock Input Levels
VIN MAX
VIN MIN
VID(DC)
VIX
VID(AC)
CK
CK#
VCCQ+0.3V
- 0.3V
VCCQ/2
 
 
Notes: 
1. CK and CK# input slew rate must be ≥1V/nS (2V/nS if measured differentially). 
2. VID(DC) is the magnitude of the difference between the input level on CK and the input level on CK# when the CK and CK# is 
stable at a certain voltage level. 
3. VID(AC) is the magnitude of the difference between the input level on CK and the input level on CK# when the CK and CK# is 
transient within a range defined for VIN. 
4. The value of VIX is expected to equal VCCQ/2 of the transmitting device and must track variations in the DC level of VCCQ.

<!-- page 39 -->

# W958D6NBKX

tCSHI

tCSM

CS#

tCSS

tCSH

tRWR = Read Write Recovery
tACC = Access

tCSS

CK#,CK

tDSZ

tDSV

tCKDS

4 cycle latency

RWDS[1:0]

Low = 1x Latency Count

tDSS

tOZ

tCKD

tIS
tIH
tDQLZ

tDSH

47:40
39:32
31:24
23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

Memory drives DQ[15:0]
and RWDS[1:0]
RWDS and Data
are edge aligned

Command-Address

Figure 27 - Read Timing Diagram — No Additional Latency Required

CS#

tACC = Access
tRWR = Read Write Recovery

Additional Latency

CK#,CK

4 cycle latency 2
4 cycle latency 1

tDSV
tCKDSR

tCKDS

High = 2x Latency Count

RWDS[1:0]

RWDS and Data
are edge aligned

tCKD

47:40 39:32 31:24 23:16 15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

Command-Address
Memory drives DQ[15:0]
and RWDS[1:0]

Figure 28 - Read Timing Diagram — With Additional Latency
Notes:
1. Timing parameters applicable to HyperBus-Extend-IO.
2. Transactions must be initiated with CK = Low and CK# = High.
3. CS# must return High before a new transaction is initiated.
4. The memory drives RWDS during the entire Read transaction.
5. Transactions without additional latency count have RWDS Low during CA cycles. Transactions with additional latency count
have RWDS High during CA cycles and RWDS returns low at tCKDSR. All other timing relationships are the same for both
figures although they are not shown in the second figure. A four cycle latency is used for illustration purposes only. The
required latency count is device and clock frequency dependent.
6. These parameters are required by HyperRAM.
7. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive
DQ[15:8] to “H” or “L”.
8. RWDS[0] corresponds to the data on DQ[7:0] and RWDS[1] corresponds to the data on DQ[15:8]. DQ output data is edge
aligned with RWDS strobe output.
9. When CS# go LOW from HIGH or go HIGH from LOW, after tCSS, CK/CK# is allowed to start oscillating.
10. When CK go LOW and CK# go HIGH, after tCSH, CS# is allowed to go HIGH from LOW or go LOW from HIGH.
11. The clock rate of each transaction must be kept same. The clock rate for different transaction can be different under
appropriate initial latency setting.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 39 -

<!-- page 40 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 40 - 
 
Dn
A
Dn
B
Dn+1
A
Dn+1
B
tCKHP
tCSH
tOZ
RWDS and Data are edge aligned and driven by the memory
CK
DQ[15:0]
RWDS[1:0]
tDSZ
tDQLZ
tCKD
tCKD
tCKDI
tDV
CK#
tCSS
tCKDS
tDSS
tDSH
CS#
 
Figure 29 - Data Valid Timing 
Notes: 
1. This figure shows a closer view of the data transfer portion of read transaction diagrams to more clearly show the Data Valid 
period as affected by clock jitter and clock to output delay uncertainty. 
2. The tCKD and tCKDI timing parameters define the beginning and end position of the data valid period. 
3. The tDSS and tDSH timing parameters define how early or late RWDS may transition relative to the transition of data. This is the 
potential skew between the clock to data delay tCKD, and clock to data strobe delay tCKDS. Aside from this skew, the tCKD, tCKDI, 
and tCKDS values track together (vary by the same ratio) because RWDS and Data are outputs from the same device under the 
same voltage and temperature conditions. 
12.3.2 Write Transactions 
Table 23 - Write Timing Parameters 
Description 
Parameter 
250 MHz 
200 MHz 
166 MHz 
133 MHz 
Unit 
Min 
Max Min 
Max Min 
Max Min 
Max 
HyperRAM Read-Write Recovery Time 
tRWR 
35 
– 
35 
– 
36 
– 
37.5 
– 
nS 
HyperRAM Read Initial Access Time 
tACC 
28 
– 
35 
– 
36 
– 
37.5 
– 
nS 
Refresh Time 
tRFH 
28 
– 
35 
– 
36 
– 
37.5 
– 
nS 
HyperRAM Chip Select Maximum Low Time 
(TCASE < 85°C) 
tCSM 
– 
4 
– 
4 
– 
4 
– 
4 
µS 
RWDS Data Mask Valid 
tDMV 
0 
– 
0 
– 
0 
– 
0 
– 
nS

<!-- page 41 -->

# W958D6NBKX

tCSHI

tCSM

CS#

tCSS

tCSH

tRWR = Read Write Recovery

tACC = Access

tCSS

CK#,CK

tIS

tDSV

4 cycle latency

tIH

tDMV

tDSZ

RWDS[1:0]

Low = 1x Latency Count

tIS

tIS
tIH
tIH

47:40
39:32
31:24
23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

CK and Data
are center aligned

Host drives DQ[15:0]
and RWDS[1:0]

Command-Address

Figure 30 - Write Timing Diagram — No Additional Latency
Note: DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive

DQ[15:8] to “H” or “L”.

CS#

Additional Latency
tACC = Access
tRWR = Read Write Recovery

CK#,CK

4 cycle latency 2
4 cycle latency 1
tDMV
tDSZ

RWDS[1:0]

High = 2x Latency Count

47:40
39:32
31:24
23:16
15:8
7:0
Dn

Dn

Dn+1

Dn+1

DQ[15:0]

A

B

A

B

CK and Data
are center aligned

Host drives DQ[15:0]
and RWDS[1:0]

Command-Address

Figure 31 - Write Timing Diagram — With Additional Latency
Notes:
1. Timing parameters applicable to HyperBus-Extend-IO.
2. Transactions must be initiated with CK=Low and CK#=High. CS# must return High before a new transaction is initiated.
3. During write transactions with latency, RWDS is used as an additional latency indicator initially and is then used as a data
mask during data transfer.
4. Transactions without additional latency count have RWDS Low during CA cycles and RWDS returns Hi-Z at tDSZ.
Transactions with additional latency count have RWDS High during CA cycles and RWDS returns Hi-Z at tDSZ. All other timing
relationships are the same for both figures although they are not shown in the second figure. A four cycle latency is used for
illustration purposes only. The required latency count is device and clock frequency dependent.
5. At the end of Command-Address cycles the memory stops driving RWDS to allow the host HyperBus-Extend-IO master to
begin driving RWDS. The master must drive RWDS to a valid Low before the end of the initial latency to provide a data mask
preamble period to the slave. This can be done during the last cycle of the initial latency.
6. The write transaction shown demonstrates the Dn A(16-bits) and the Dn+1 B(16-bits) being masked. Only Dn B(16-bits) and
Dn+1 A(16-bits) are modified in the array. Dn A(16-bits) and Dn+1 B(16-bits) remain unchanged.
7. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive
DQ[15:8] to “H” or “L”.

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 41 -

<!-- page 42 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 42 - 
 
CA
[47:40]
CA
[39:32]
CA
[31:24]
CA
[23:16]
CA
[15:8]
CA
[7:0]
RG
[15:8]
RG
[7:0]
Command-Address
Data
CS#
CK#,CK
DQ[7:0]
RWDS[1:0]
tCSHI
tCSM
tCSS
tDSV
tIS
tIH
tDSZ
tCSH
 
 
Figure 32 - Write Operation without Initial Latency (Register Write) 
Notes: 
1. Transactions must be initiated with CK=Low and CK#=High. CS# must return High before a new transaction is initiated. 
2. Writes without Initial Latency, do not have a turnaround period for RWDS. The slave device will always drive RWDS during the 
Command-Address period to indicate whether extended latency is required for a transaction that has initial latency. However, 
the RWDS is driven before the slave device has received the first byte of CA, that is, before the slave knows whether the 
transaction is a read or write, to memory space or register space. In the case of a write without Initial Latency, the RWDS state 
during the CA period does not affect the Latency of Register Write. Since master write data immediately follows the Command-
Address period in this case, the slave may continue to drive RWDS Low or may take RWDS to High-Z during write data 
transfer. The master must not drive RWDS during Register Write. Register Write do not use RWDS as a data mask function. 
All write data are written. 
3. DQ[15:8] input will be not used for command/Address decoding or as the write data, however, the controller has to drive 
DQ[15:8] to “H” or “L”. 
 
12.3.3 Hybrid Sleep Timings 
Table 24 - Hybrid Sleep Timing Parameters 
Description 
Parameter 
Min 
Max 
Unit 
Hybrid Sleep CR1[5]=1 register write to Hybrid Sleep power level 
tHSIN 
– 
3 
µS 
CS# Pulse Width to Exit Hybrid Sleep 
tCSHS 
60 
3000 
nS 
CS# Exit Hybrid Sleep to Standby wakeup time 
tEXTHS 
– 
100 
µS 
Note: 
1. After exit Hybrid Sleep command effective. the host must wait for at least 100µS to do the next valid command to the HyperRAM device. 
12.3.4 Deep Power down Timings 
Table 25 - Deep Power down Timing Parameters 
Description 
Parameter 
Min 
Max 
Unit 
Deep Power Down CR0[15]=0 register write to DPD power level 
tDPDIN 
– 
3 
µS 
CS# Pulse Width to Exit DPD 
tCSDPD 
200 
3000 
nS 
CS# Exit Deep Power Down to Standby wakeup time 
tEXTDPD 
– 
150 
µS 
Note: 
1. After exit DPD command effective. the host must wait for at least 150µS to do the next valid command to the HyperRAM device.

<!-- page 43 -->

# W958D6NBKX

13. PACKAGE SPECIFICATION
Package Outline WFBGA 49 Balls (4x4 mm2, Ball pitch: 0.5mm)

TOP VIEW
BOTTOM VIEW

S
aaa
B

S
bbb
//

D
A

D1

A1
eD

PIN A1   INDEX

PIN A1   INDEX

1
2
3
4
5
6

7

eE

A

B

C

A

D

E1

E

E

F

G

B

S
aaa
A

S
ccc

Φb

S

SOLDER BALL DIAMETER REFERS.
TO POST REFLOW CONDITION.

SEATING PLANE

C
A

ddd M

B

C

eee

M

### Controlling Dimension: Millimeters

DIMENSION

DIMENSION

(Inch)

(MM)

SYMBOL

BALL LAND

MIN.
NOM.
MAX.

MIN.
NOM.
MAX.
A
A1
b
D
E
D1
E1
eD
eE
aaa
bbb
ccc
ddd

0.024
0.028
0.007
0.010

0.80
0.23
0.30
4.10
4.10
4.00
4.00
3.90
3.90
0.20
0.13
0.60

0.032

0.70
0.18
0.25

0.009
0.012
0.161
0.161

0.005
0.008
0.154
0.154
0.158
0.158

---
---
---
---
---
---
0.15
0.10
0.20
---
---
0.15
0.50 BSC.
0.50 BSC.
3.0 BSC.
3.0 BSC.

---
---
0.020 BSC.
0.020 BSC.
0.118 BSC.
0.118 BSC.

1

0.006
0.008
0.004
0.006
0.003

BALL OPENING

---
---
---
---
---
---

Note:
1.  Ball land: 0.34mm, Ball opening:  0.24mm,
PCB Ball land suggested   0.24mm

eee
---
---
0.08

---
---

The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or

reproduced without permission from Winbond.

Publication Release Date: Mar. 09, 2023

Revision: A01-001
- 43 -

<!-- page 44 -->

W958D6NBKX 
 
The above information is the exclusive intellectual property of Winbond Electronics and shall not be disclosed, distributed or 
reproduced without permission from Winbond. 
Publication Release Date: Mar. 09, 2023 
Revision: A01-001 
- 44 - 
14. REVISION HISTORY 
VERSION 
DATE 
PAGE 
DESCRIPTION 
A01-001 
Mar. 09, 2023 
All 
Initial formal datasheet 
 
 
Note: The content of this document is subject to change without notice.

<!-- END VERBATIM SOURCE -->
