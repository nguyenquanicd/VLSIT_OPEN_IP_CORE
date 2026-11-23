| Area | Weight | Score | Justification |
|---|---:|---:|---|
| clock_reset_cdc | 1.5 | 1 | CSR stale update protection missing. §7.2 CDC-002, §11.3 REQ-REG-003 |
| sdc_timing | 1.5 | 1 | CDC constraints do not identify the actual Gray endpoints. §7.2 CDC-001/002/004/007, §17.1.3 EXC-001/002 |
| interfaces | 1.5 | 2 | AXI3 reference cannot establish the AXI4 subordinate contract. §2.1–2.3 REF-010, §6.2–6.3 REQ-IF-006/007 |
| features | 1.0 | 2 | Double buffering has incompatible software contracts. §3 REQ-FUNC-029, §8, §10.4, §15.2 TEST-023, §20 DEC-040 |
| functions | 1.5 | 2 | SOF phase cannot be guaranteed when its clock stops. §3 REQ-FUNC-037, §7.4, §15.2 TEST-034 |
| security_ras | 1.0 | 2 | DMA range comparison uses a low-word aperture. §3 REQ-IF-014, §8, §18, TEST-035 |
| parameters | 1.0 | 2 | RAM organization and legal width combinations conflict. §8, §10.4–10.5, §17.2, §20 DEC-006/010/041 |
| performance | 1.5 | 2 | Throughput has a no-stall premise and no product margin. §13 PERF-001/002, §15.2 TEST-017, §20 DEC-025/032 |
| verification_quality | 1.5 | 2 | Traceability is present but closure is incomplete. §15.3–15.4, §19, REQ-VER-003 |
| software_ease | 1.0 | 2 | Scatter-gather interrupt estimate exceeds the programmed feature set. §1.4 FEAT-023, §9, §11.5, §20 DEC-013/039/042 |
| asic_feasibility | 1.5 | 2 | FreePDK45 estimate leaves macro and timing implementation open. §10.5 MEM-001, §14.3, §17.2, §20 DEC-034/035 |
| area_power | 1.0 | 3 | Storage and mapped logic are available but product power is open. §13 area/power, §20 DEC-034 |
| dft | 1.0 | 3 | DFT responsibilities are named without insertion evidence. §16, §17.2, DEP-004 |
| application_fit | 1.0 | 3 | Drone product operating point is still a proposal. §1.2–1.4 FEAT-012/016/021, §13 PERF-001 |
| integration_effort | 1.0 | 2 | PHY bring-up depends on unresolved vendor timing. §6.3 REQ-IF-011, §7.3, §14.4, §20 DEC-025/TBD-007/TBD-015 |
| documentation | 0.5 | 3 | The release-status language mixes incompatible evidence. Front matter, §15, §19, §20 TBD-016 |
| data_representation | 0.5 | 3 | FIFO capacity alternates between 32-bit words and physical rows. §8, §9, §10.5 |
| market_position | 1.0 | 3 | Feature breadth is credible, integration effort is higher. §1.3–1.4, §2.1 REF-011/012, §11.5 |
| **Weighted** | **20.5** | **2.10** | **Verdict: Conditional** |
