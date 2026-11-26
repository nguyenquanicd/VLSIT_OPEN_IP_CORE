# DVP Controller test review notes

For the human reviewer of the tests. AI-generated candidate (R-117): nothing here is approved, and the review columns of [verification_report.md](verification_report.md) stay `pending` until a named reviewer fills them (R-244). Everything below was measured on the run named in each section; a number without a source is not claimed.

## 1. What to review, in order

| # | Item | Where | Why it needs a human |
|---|---|---|---|
| 1 | Expected values that rest on an interpretation of the HDS | section 3 | The tests and the checker follow the text as I read it; only the specification owner can say the reading is right |
| 2 | Formal assumptions | section 4 | An assumption that is too strong makes a property vacuous; one that is too weak gives a false counterexample |
| 3 | Claims that a surviving mutant is equivalent | section 5 | These are my reasoning from the RTL, not proofs |
| 4 | Test-to-mutant kill table | section 6 | Shows which tests catch which injected fault and which faults only one test catches |

## 2. Tests of the regression (`env/tb/tb_dvp_controller.sv`)

Oracles: the passive checker (`env/scoreboards/dv_dvp_checker.sv`, HDS-derived model with CDC windows, qualified by 50 cases in [checker_qualification.md](checker_qualification.md)) judges every APB transfer in every test, and each test adds its own known-answer checks (`expect_eq`) and sensor data with known values (`read_expect`).

| Test | Line | Purpose | Own known-answer checks | Mutants only this test kills (matrix of section 6) |
|---|---:|---|---|---|
| t_dvp_continuous_e2e | 188 | Continuous capture, AFIFO crossing, watermark request, read once in order | level counts, data order, empty-read cycles, frame count | none (killed with others) |
| t_dvp_gated_e2e | 216 | Gated capture through the toggle bridge into the SFIFO | level counts, data order, empty-read cycles, frame count | none |
| t_dvp_apb_protocol | 241 | CSR map, reset values, read-only fields, byte strobes, unmapped addresses | **reset value of all 7 registers read before any write (new)**, readbacks, read-only version and frame count | none |
| t_dvp_timeout_boundary | 274 | Empty-read timeout, sample arriving around the terminal cycle (24 offsets x 2 modes) | cycles of every timeout value, data of the race winner | M07 |
| t_dvp_endpoint_errors | 305 | Write, misaligned and unmapped accesses to the data endpoint | error flag of each access, level unchanged, data still correct afterwards | M04, M19 |
| t_dvp_overflow | 322 | Fill beyond depth, newest dropped, W1C race | status bits, level at full, drained count | M03 |
| t_dvp_flush_handshake | 345 | Flush in both modes, 12 continuous-mode flushes with samples in flight | flush bit clears, level 0, status and frame count retained | none |
| t_dvp_flush_race | 382 | **New.** CTRL write at every offset 0..39 after a flush request, both modes | request bit reads 0 within the poll limit | M22 (the defect F-003) |
| t_dvp_dma_rearm | 399 | Request at the watermark, hold, drop on ACK, re-arm, watermark 0 and changes | request level at each step | none |
| t_dvp_frame_counter | 430 | Frame counter, capture enabled inside an active VSYNC, re-enable without a new VSYNC | count after each step, level 0 where nothing may be captured | M15, M16, M18, M29, M30, M34, MP1, MP4 |
| t_dvp_mode_guard | 483 | Mode change only when capture is off, queues empty, source quiet | mode and capture bits after each write, **including the new mode-plus-disable writes** | M11, M31 |
| t_dvp_reset_recovery | 519 | Reset during a pending read, sensor activity during reset, reset with data queued | abort flag, level after reset, post-reset data only | none |
| t_dvp_profiles | 577 | Width, edge and polarity of the elaborated build, both modes, HREF-inactive samples | level and data per pattern, HREF-qualified count | none (MP2, MP5 are also seen by others) |
| t_dvp_performance_characterization | 548 | Constrained-random producer bursts and consumer stalls, both modes | none of its own: relies on the checker | none |

Known thin spots, measured: the random test has no own known-answer check; VSYNC polarity faults (M18, MP1, MP4) are caught by `t_dvp_frame_counter` only.

## 3. Interpretations the tests depend on (please confirm or correct)

| ID | Test change | Expectation | HDS basis | Question for the owner |
|---|---|---|---|---|
| R-1 | `t_dvp_mode_guard` (lines 490, 493, 505) | A CTRL write that sets a new mode **and** clears capture, issued while capture is enabled, leaves the mode unchanged and clears capture | REQ-FUNC-004 and DEC-028: the mode is accepted only while capture is disabled | Is "capture is disabled" evaluated before the write (my reading) or after it? If after, the mode would change and these checks are wrong |
| R-2 | `env/bfm/dv_dvp_source.sv`, `gated_pixel` (line 85) | In gated mode the data pins carry the pixel only around the selected edge and the complement a half period later | REQ-FUNC-006: the source registers the pixel at the selected edge and toggles valid | Is a source whose data changes after the active edge legal? (A wrong-edge sampler is only detectable if it is) |
| R-3 | `env/bfm/dv_dvp_source.sv`, `cont_cycle` (line 68) | Same for continuous mode: data valid only around the selected edge | REQ-FUNC-005 | Same question |
| R-4 | `t_dvp_flush_race` (line 382) | A CTRL write while a flush is pending is accepted with OKAY and the request bit still clears | ERR-007, REQ-FUNC-010, DEC-033, DEC-034 | A write one cycle before the clear can start a second flush of an empty FIFO; the test does not check for it. Acceptable? |
| R-5 | `t_dvp_apb_protocol` (line 243) | Reset values: version 0x00010001, CTRL 0, watermark 0, timeout 0xFFFFFFFF, status 0x2, level 0, frame count 0 | CSR workbook v1.1 | Confirm the workbook values are the intended ones |
| R-6 | Generator 3.7 (outside this folder) | `w2c` is cleared only by a write whose strobes cover its byte lane | DEC-034 | I extended "events of one field do not affect another" to `w2c` on my own reading; veto if not wanted |

## 4. Formal harnesses (`env/formal/`)

| Harness | Result | Assumptions to check | Limit |
|---|---|---|---|
| f_apb_data | proof (k-induction) | APB4 legality; timeout bounded to N <= 6 | timeout not proven beyond 6 |
| f_dma_req | proof | none beyond reset | none known |
| f_ctrl | bounded, depth 24 | clocks tied; no reset after the first | no CDC |
| f_flush | bounded, depth 30 (kills M20; does not kill M10) | request held until the done pulse, capture and mode guards as the service enforces them, gated-sensor spacing, clocks tied | no CDC; k-induction did not converge |
| f_csr | proof (k-induction) | APB4 legality, constant protect/slverr enables | unit level: the CSR block only |

The assumptions are listed in each harness header. Please read `f_flush.sv` lines 1-12 and the assumption block, because the first counterexample the mutant M10 produced was a harness defect, not a DUT result.

## 5. Surviving mutants and why (reasoning, not proof)

| Mutant | Simulation | Formal | Reasoning |
|---|---|---|---|
| M05 pop on an empty FIFO | not detected | killed | the FIFO ignores a read when empty, so it is unobservable at the ports |
| M10 flush guard forced to 1 | not detected | not detected (bounded) | the CSR masks a flush while capture is on and the reset outlasts the in-flight pipeline; not proven equivalent |
| M20 repeated done pulse removed | not detected | killed | with the hardware-first CSR the branch cannot be reached from the bus |
| M21 CSR software-first restored | not detected | killed (f_csr, proof) | masked at system level by the repeated done pulse |

## 6. Kill table

Rows M11, MP6 and M00 were measured with the corrected testbench; every other row with the testbench before the test fixes of 2026-11-25 (a full rerun of the matrix takes hours). The control M00 detected nothing in both versions. 44 mutants, simulation only, one seed, build `base` except the `MP*` mutants (their own build).

| Test | Mutants it detects | Detected by this test alone |
|---|---:|---|
| endpoint_errors | 12 | M04, M19 |
| apb_protocol | 8 | - |
| timeout_boundary | 12 | M07 |
| overflow | 14 | M03 |
| dma_rearm | 15 | - |
| mode_guard | 10 | M11, M31 |
| flush_handshake | 10 | - |
| flush_race | 3 | M22 |
| frame_counter | 20 | M15, M16, M18, M29, M30, M34, MP1, MP4 |
| continuous_e2e | 12 | - |
| gated_e2e | 12 | - |
| reset_recovery | 14 | - |
| profiles | 12 | - |
| performance_characterization MODE=0 | 17 | - |
| performance_characterization MODE=1 | 14 | - |

In the matrix (testbench before the fixes) no simulation test detects M05, M10, M20, M21, M28 and M32. In the final mutation run, with the corrected testbench, M32 is also killed by simulation (`t_dvp_endpoint_errors`) and formal (`f_apb_data`); I did not investigate why the corrected testbench changed that, so treat the M32 row of the matrix as stale. Final result: 43 of 44 mutants killed, only M10 survives; M05, M20, M21 and M28 are killed by formal only.

## 7. How to reproduce

```powershell
python env\scripts\dvp_regress.py --out sim\final       # qualification, legality, scope, regression
python env\scripts\dvp_formal.py                          # all formal tasks
python env\scripts\dvp_mutation.py [--resume]             # mutants (simulation to the first failing test, then formal)
python env\scripts\dvp_killmatrix.py --out <dir> --only M11 MP6   # every test against the listed mutants
python env\scripts\dvp_coverage.py                        # Verilator coverage of the base regression
```
