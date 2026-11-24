# Survey of I2S audio interface IP in two audio-capable SoC/MCU families

Purpose: functional reference for the APB I2S controller specification (`VLSIT_APB_I2S_HDS.md`). The features below are restated in the author's own words from the I2S chapters of two public reference manuals; no text, figure or table is copied. The PDFs were read in a temporary folder and are not kept in this repository (the vendors' documentation licences do not allow redistribution).

## 1. Sources and limits

| Item | ESP32-S3 | i.MX RT1170 |
|---|---|---|
| Vendor | Espressif Systems | NXP Semiconductors |
| Document | ESP32-S3 Technical Reference Manual, version 1.8 | i.MX RT1170 Processor Reference Manual (IMXRT1170RM), Rev. 3, 11/2024 |
| Chapter read | Chapter 28 "I2S Controller (I2S)", manual pages 1038 to 1077 | Chapter 58 "Synchronous Audio Interface (SAI)", pages 3467 to 3518 |
| Downloaded from | documentation.espressif.com (official), 15.2 MB | A DigiKey-hosted copy of the NXP manual, 35.1 MB (the official NXP link returned HTTP 404) |
| Downloaded on | 2026-11-20 | 2026-11-20 |
| Instances | I2S0 and I2S1 | SAI1, SAI2, SAI3 and SAI4 |

Limits of this survey:

- Neither device is an audio-only part: the ESP32-S3 is a wireless MCU and the i.MX RT1170 is a crossover processor. Both carry mature audio interfaces and are used in voice and audio products. A dedicated audio codec SoC was not found with a public manual.
- Only the functional chapters were read. Electrical timing, pin multiplexing, and the clock tree outside the audio blocks were not read.
- The third candidate (nRF5340) was not downloaded: no official copy could be reached (the only hit returned HTTP 403).
- The register lists below name registers only where it helps to understand a feature; they are not a register map of our IP.

## 2. ESP32-S3 I2S controller (I2S0, I2S1)

### 2.1 Structure and roles

- Two independent controllers; each has a separate transmit unit and receive unit, which run at the same time or alone (full duplex or half duplex).
- Each unit can be master (drives its own bit clock and word select) or slave (follows external ones), chosen per unit by a register bit. The two units therefore may have different roles.
- Three-line interface (bit clock, word select, serial data) plus an optional master clock input and output. All signals reach the pins through a general signal matrix.
- A transmit FIFO and a receive FIFO of 64 words of 32 bits each, filled and emptied by a general DMA controller (descriptor based). There is no per-sample register access.
- Compress and decompress blocks (A-law and mu-law) sit in front of the FIFOs.

### 2.2 Audio formats

- Philips I2S: the word select leads the data by one bit clock.
- MSB-aligned (left-justified): word select and data change together.
- PCM short frame: a one-clock word-select pulse one bit clock before the data.
- PDM: word select toggles continuously at half the bit clock rate; left channel while low, right while high.
- TDM versions of the first three formats, with up to 16 channels per frame in both directions.
- The standard is chosen with four mode bits per unit (TDM enable, PDM enable, MSB shift, PCM bypass).

### 2.3 Clocking

- The unit clock is selected from a 40 MHz crystal, a 160 MHz PLL, a 240 MHz PLL, or an external master clock, and divided by an integer-plus-fraction divider (integer 2 to 256).
- The bit clock is divided again from the unit clock by an integer; a divider value of 1 is forbidden.
- In slave mode the unit clock must be at least eight times the bit clock.
- Sample rates listed: 8, 16, 32, 44.1, 48, 88.2, 96, 128 and 192 kHz (192 kHz not in 32-bit slave mode).
- Configuration registers live in the bus clock domain and reach the unit clock domain only after a dedicated "update" bit is set; this avoids half-updated settings.
- Separate reset bits exist for each unit and for each FIFO; the clock must be set up before resetting.

### 2.4 Data formatting (transmit and receive)

- Valid data width 8, 16, 24 or 32 bits; a separate 24-bit fill option (24 bits stored in a 32-bit slot).
- Channel (slot) width is independent of the data width: unused bits are zero filled, with a left-align option that puts the data at the top of the slot; if the slot is narrower, the extra bits are dropped.
- Byte-order (endian) control of the memory words, and bit-order reversal inside a channel.
- A-law and mu-law encode or decode of each sample.

### 2.5 Channel handling

- TDM: total channel count is programmable (up to 16), each channel can be enabled; on transmit a disabled channel either repeats the previous channel's data or sends a fixed programmable value; on receive a disabled channel is not stored.
- TDM word-select width and idle polarity are programmable in master mode; half-sample bit count sets the word-select period.
- PDM: mono or stereo data fetching from memory with control of which half-period requests data; channel select bits can duplicate one channel or use the fixed value.
- On I2S0 only: PCM-to-PDM output (with 1-line PDM or 1/2-line DAC formats and a programmable oversampling rate) and PDM-to-PCM input from up to four data lines (eight channels) with a programmable down-sampling rate.

### 2.6 Start, stop and error behavior

- Start and stop bits per unit; a stop-enable bit decides whether the master stops when the FIFO is drained or repeats the last frame.
- A slave transmitter sends zeros while no bit clock or no data arrives; an idle status bit shows when the transmitter has finished.
- Interrupts: transmit done, receive done, transmit hung and receive hung (timeout when the master gives no clock, word select or data for a programmable time).

### 2.7 Software model

Documented sequence: set the clock, map pins, choose role, set data and channel modes and the update bit, reset unit and FIFO, enable interrupts, program the DMA, set start, wait for the interrupt or the idle bit, clear start.

## 3. i.MX RT1170 Synchronous Audio Interface (SAI)

### 3.1 Structure and roles

- A transmitter and a receiver per instance, each with its own bit clock, frame sync and register set; each can be master or slave independently.
- Instances SAI1 has four data lines in each direction; SAI2 and SAI3 have one (chip note). Synchronous mode between different SAI instances is not supported on this device.
- An asynchronous FIFO of 32 words of 32 bits for every data line; writes and reads go through data registers (one per line) and a FIFO status register shows the pointers.
- Supported protocols: I2S, AC97, TDM and codec/DSP style frames.

### 3.2 Frame model (generic, not tied to a named format)

- A frame is 1 to 32 words, a word is 8 to 32 bits; the first word can have a different length from the others.
- Frame sync: internal or external, active high or low, asserted with the first bit or one bit early, with a width from one bit clock up to the first word length.
- Data order MSB first or LSB first, and a "first bit shifted" field places the data anywhere inside the 32-bit FIFO word (so 8, 12, 16, 20, 24 and 32-bit data can all be aligned).
- A word mask register (double buffered, so it can change every frame) masks selected words: on transmit the data pin is tri-stated (or driven to zero in "output mode") and nothing is read from the FIFO; on receive the word is discarded.
- A new frame sync is ignored or not produced during the first four bit clocks after enabling.
- These options cannot be changed once the transmitter or receiver is enabled.

### 3.3 FIFO features

- 8-bit and 16-bit packing of several words in one 32-bit FIFO word; pointers advance only when a full 32-bit word was accessed; 8, 16 and 32-bit bus accesses are accepted.
- FIFO combine: several data-line FIFOs behave as one FIFO for software (a DMA can address one location and walk across lines), and for the data path (one line spreads over all enabled lines).
- Writes to a full transmit FIFO and reads from an empty receive FIFO are ignored; software must write at least 3 bit clocks before the next unmasked word to avoid an underrun and fill the FIFO before enabling the transmitter.
- Per-channel FIFO reset and a whole-FIFO reset (one cycle); independent software reset that keeps the configuration.

### 3.4 Flags, interrupts and DMA

- FIFO request flag: transmit when any enabled FIFO is at or below the watermark; receive when any is above the watermark. It drives an interrupt or a DMA request.
- FIFO warning flag: transmit when any FIFO is empty; receive when any is full; interrupt or DMA request.
- FIFO error flag (underrun or overflow): after it sets, transmit sends zeros and receive discards data until software clears it. An optional "continue on error" mode restarts the stream in the right word position without software help.
- Sync error flag: external frame sync arrived while the previous frame was still running.
- Word start flag: marks the start of a configurable word in the frame (interrupt only).
- Separate interrupts and DMA requests for transmitter and receiver; asynchronous interrupt versions can wake the CPU from stop mode.

### 3.5 Clocking, sharing and power

- The bit clock comes from the bus clock or one of up to three audio master clocks, divided by an even divider, with programmable clock polarity (which edge drives and which samples) and an option to delay the internal clock to model the pad delay.
- Synchronous operation: the receiver can use the transmitter bit clock and frame sync (or the reverse); a bit-clock swap field allows one side to share only the clock while keeping its own frame sync. Enable and disable order is prescribed.
- On-demand mode: in master mode the frame sync is produced only while the FIFO warning flag is clear, so the interface idles instead of underrunning.
- Stop and debug modes: the unit finishes the current frame and stops unless stop-enable or debug-enable is set.
- Version and parameter registers report the build (data lines, FIFO depth).

## 4. Comparison with the APB I2S controller specification

Legend: YES = our specification has it, PART = partly, NO = not in our specification.

| Feature | ESP32-S3 | i.MX RT1170 | Our spec (VLSIT_APB_I2S_HDS.md) |
|---|---|---|---|
| Separate TX and RX units, independent | Yes | Yes | YES (REQ-FUNC-047) |
| Independent role (master/slave) per direction | Yes | Yes | PART: one role for both |
| Philips I2S frame | Yes | Yes (generic frame) | YES |
| Left-justified (MSB aligned) frame | Yes | Yes (frame sync early bit) | NO |
| PCM short or long frame | Yes (short) | Yes (frame sync width) | NO |
| TDM, up to 16 channels or slots | Yes | Up to 32 words per frame | YES (16 slots of fixed 32 clocks) |
| Variable TDM slot width | Yes | Yes | NO (slot fixed at 32) |
| PDM microphone input and output | Yes | No | NO (out of scope) |
| Programmable word length per direction | 8, 16, 24, 32 | 8 to 32 | YES (12, 16, 20, 24, 32) |
| First word different from other words | No | Yes | NO |
| Data alignment inside the FIFO word | Left-align option | First-bit-shifted field | PART: LSB aligned only |
| Endian and bit-order control | Yes | MSB or LSB first | NO |
| A-law and mu-law | Yes | No | NO |
| Per-slot enable | Yes | Word mask | YES (slot enables) |
| Word mask changed every frame | No | Yes (double buffered) | NO |
| Tri-state of masked or disabled slots | n/a | Yes (or zero output mode) | PART (serial output enable) |
| FIFO per channel and FIFO depth | 64 shared with DMA | 32 per data line | YES (2 to 256) |
| Packing of 8 or 16-bit words in a FIFO word | Memory-side only | Yes | NO |
| FIFO combine across lines | No | Yes | NO |
| Hardware DMA handshake | Via general DMA | DMA request | YES (dedicated or combined) |
| Overrun and underrun flags | Hung and done interrupts | Error flag | YES |
| Automatic restart after underrun or overflow | No | Yes (continue on error) | NO (zeros, no automatic resync) |
| Frame sync error flag (external sync too early) | No | Yes | NO |
| Hung or timeout interrupt (no clock or no data) | Yes | No | NO |
| On-demand frame sync (stall instead of underrun) | No | Yes | NO |
| Clock source selection and divider in the IP | Yes (fraction) | Yes (bus or 3 MCLKs) | NO (clock generation inputs only) |
| Bit clock polarity control | Edge by format | Yes | NO |
| Shared bit clock between TX and RX | Not needed | Yes (synchronous modes) | NO |
| Master clock output | Yes | MCLK pins | NO |
| Update strobe for configuration crossing | Yes | No | PART (handshake in CDC-004) |
| Software reset per unit, keeps configuration | Yes | Yes | NO (only global enable) |
| Stop and debug power modes | Not described | Yes | NO |
| Build parameter registers | No | Yes | YES |

## 5. Candidate additions for the specification (for the owner to decide)

None of these were added to `VLSIT_APB_I2S_HDS.md`; each is a possible new feature or open decision.

1. Frame format options beyond the Philips frame: a frame-sync-early bit (left-justified versus I2S) and a configurable frame-sync width (PCM short frame). Both are cheap and used by common codecs.
2. Automatic restart after underrun or overrun that resumes at the right slot, so the left/right pair cannot slip (our spec has only a flush-and-resync rule, ERR-010).
3. A frame-sync error flag for target mode (external word select that arrives in the middle of a frame) and an optional hung-clock timeout interrupt; both help debugging of integration faults.
4. A per-direction role (a transmitter as controller and the receiver as target), if the product needs full-duplex with different clock masters.
5. A word mask that can change every frame, as a lighter alternative to per-slot enables in TDM.
6. A software reset per direction that keeps the configuration (a second level between the block enable and the global enable).
7. Optional data alignment and 24-in-32 fill, so the same FIFO word format works for 24-bit samples on a 32-bit bus; byte-order control only if the host is big-endian.
8. Master-clock handling in the IP (clock source, divider, polarity), if the SoC integrator does not want an external divider for each audio rate.

## 6. Method note

Text of the two chapters was extracted with a PDF library into temporary files, then read; the survey states behavior only where the chapters state it. Items marked "No" in the comparison mean the chapter does not describe the feature, not that the device lacks it.
