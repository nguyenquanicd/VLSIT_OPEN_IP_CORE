# WDT RTL Review

## Scope

Reviewed the ten SystemVerilog files in rtl/ and compared the implementation with FTEL_CDC_WDT_Hardware_Design_Specification_v1.2.docx.pdf. The supplied RTL was not changed. The spec records observed behavior; the source PDF remains untouched.

## Findings

| ID | Severity | Finding | Evidence / effect |
|---|---|---|---|
| WDT-R-01 | High | The v1.2 HDS does not match the supplied RTL snapshot. | Current RTL has CNT_EN at bit 2 separate from INTEN, DBGEN at bit 3, RESDIV at bits 7:4, and a programmable reset-pulse block. The old HDS describes different bit positions/enable behavior and lacks this pulse implementation. Software written from the old map may program the wrong behavior. |
| WDT-R-02 | High | DBGEN is used as an unconditional counter halt. | m_fpt_wdt_top connects DBGEN directly to core i_halt; there is no live debug-mode input. Setting DBGEN stops the watchdog even when the processor is not in debug. Confirm intended semantics before any RTL change. |
| WDT-R-03 | Medium | WD_DBG_STAT is configuration readback, not live debug status. | Top feeds w_dbgen to the CSR status input. Software cannot use it to observe processor debug entry. |
| WDT-R-04 | Medium | The top-level APB port list is a reduced APB4 profile. | PSTRB and PPROT are absent; PSTRB is internally tied to 4'b1111. Sparse writes and external privilege attributes are unavailable. |
| WDT-R-05 | Medium | Locked writes are silently ignored. | Register write enables include synchronized unlock, while APB completion does not flag a lock rejection. Firmware can see a completed APB write that had no effect. |
| WDT-R-06 | Medium | The target CSR workbook is not a specification of the current RTL snapshot. | Current WD_INT_CLR emits a pulse on any unlocked write, independent of write-data bit. Target HDS v2.0 replaces that legacy behavior with W1C on wd_irq_raw; RTL remains unchanged. |
| WDT-R-07 | Integration | Resets and clocks need SoC-level coordination. | The wrapper has separate APB and WDT resets; reset during a request or one-sided reset is not handled by a flush/recovery protocol. |
| WDT-R-08 | Integration | Parameter declarations are wider in scope than the validated implementation. | Decoder uses fixed 16-bit addresses, and the wrapper fixes 16/32/32/4 configuration. Overrides are not qualified. |
| WDT-R-09 | Evidence gap | No testbench, simulation, lint, CDC/RDC, synthesis or STA result was supplied or run in this review. | HDS v2.0 separates as-built observations from target requirements; WaveDroms are explanatory target examples. Neither is verification evidence. |

## Functional summary

- CNT_EN, not INTEN, enables counting.
- First timeout sets sticky raw status independent of INTEN. INTEN gates the interrupt output and masked status.
- Rewriting WD_CNT_LD or writing WD_INT_CLR clears timeout state and reloads the counter.
- A second timeout with pending state and RESEN=1 requests an active-high pulse of 2^RESDIV WDT cycles; the counter remains stopped until WDT reset.
- Legal RESDIV is 0..8; APB writes above 8 are rejected.
- A load L yields (L+1) watchdog clock cycles before timeout. At the illustrative 40 kHz clock, the 32-bit maximum is about 29 h 49 min 34.18 s.

## Recommendation

Before using the old v1.2 PDF for firmware or integration, review the current bit layout and DBGEN behavior with the RTL owner. Confirm the real WDT clock and signoff DFF/scan setup. This report does not propose or apply an RTL fix.
