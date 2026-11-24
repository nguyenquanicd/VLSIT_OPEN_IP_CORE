| Area | Weight | Score | Justification |
|---|---:|---:|---|
| application_fit | 1.0 | 3 | Product class and neighbours are named, but all numbers are assumptions (F-001). |
| features | 1.0 | 4 | Nine FEAT rows with conditions; only a Minor mapping gap (F-002). |
| functions | 1.5 | 3 | FSM, 8 operations and 12 waveforms exist; two Major open points (F-004, F-005). |
| interfaces | 1.5 | 2 | Two Major findings: DMA handshake contract and AXI4 profile are not closed (F-006, F-007). |
| clock_reset_cdc | 1.5 | 3 | Three-domain table with 8 crossings, but event-crossing structure and single-domain reset are open (F-008, F-009). |
| parameters | 1.0 | 3 | Ranges and illegal-combination rules exist; defaults contradict the application (F-010). |
| data_representation | 0.5 | 4 | Complete table from RFC 8439; only an unconfirmed byte-order assumption (F-012). |
| asic_feasibility | 1.5 | 3 | Structure is synthesizable, but no critical-path statement for the fast options (F-013). |
| sdc_timing | 1.5 | 2 | Contract and exceptions are written, but no SDC file exists (F-014). |
| area_power | 1.0 | 4 | Proxies are labelled as proxies; no mapped number yet (F-016). |
| performance | 1.5 | 3 | ChaCha20 bound is stated; Poly1305 and per-message cost are unquantified (F-017, F-018). |
| software_ease | 1.0 | 4 | Register model, 14-step flow and capability register; only an Observation (F-019). |
| dft | 1.0 | 2 | Only the clock-gate test enable; no scan or reset controllability (F-020). |
| security_ras | 1.0 | 2 | Explicit boundary, but no data-window access control and no nonce guard (F-021, F-022). |
| verification_quality | 1.5 | 4 | Every requirement has a test; plan not yet implemented (F-025). |
| documentation | 0.5 | 3 | Stable IDs and traceability, but 38 open items with eight blocking (F-026). |
| integration_effort | 1.0 | 3 | Dependencies are listed but unresolved (F-028). |
| market_position | 1.0 | 3 | Positioning is argued from vendor sources only (F-029, F-030). |
| **Weighted** | **20.5** | **3.00** | **Verdict: Conditional** |
