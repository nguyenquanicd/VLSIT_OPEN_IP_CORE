# RTL rule check

Files: m_vlsit_csr_dvp.sv, m_vlsit_csr_sync.sv, m_dvp_afifo.sv, m_dvp_afifo_rd.sv, m_dvp_apb_data.sv, m_dvp_apb_decode.sv, m_dvp_apb_service.sv, m_dvp_buffer.sv, m_dvp_capture.sv, m_dvp_controller.sv, m_dvp_dma_req.sv, m_dvp_gate_bridge.sv

| Level | Rule | File:line | Finding |
|---|---|---|---|
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:175 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:232 | no functional comment before this process |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:251 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:253 | no functional comment before this process |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:272 | no functional comment before this process |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:278 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:290 | no functional comment before this process |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:296 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:301 | no functional comment before this process |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:307 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:327 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:333 | no functional comment before this process |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:339 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:502 | no functional comment before this assign group |
| WARN | CMT-01 | m_vlsit_csr_dvp.sv:511 | no functional comment before this assign group |
| WARN | HIE-02 | m_dvp_afifo.sv:12 | module has instances and also logic; a structural top should contain instances only (HIE-02) |
| WARN | HIE-02 | m_dvp_afifo_rd.sv:17 | module has instances and also logic; a structural top should contain instances only (HIE-02) |
| WARN | HIE-02 | m_dvp_apb_service.sv:11 | module has instances and also logic; a structural top should contain instances only (HIE-02) |
| WARN | HIE-02 | m_dvp_buffer.sv:12 | module has instances and also logic; a structural top should contain instances only (HIE-02) |
| WARN | HIE-02 | m_vlsit_csr_dvp.sv:14 | module has instances and also logic; a structural top should contain instances only (HIE-02) |
| WARN | PAR-03 | m_vlsit_csr_dvp.sv:175 | literal 8 may be a magic number (P10); name it with a parameter, localparam or enum member |

Rules failed: none
Rules warned: CMT-01, HIE-02, PAR-03
Rules clean: ARI-04, CMT-05, COM-02, COM-03, COM-04, COM-06, COM-07, COM-09, COM-10, COM-11, ENM-01, ENM-03, ENM-04, ENM-05, ENM-06, FIL-01, FIL-02, FIL-03, FIL-04, FIL-05, FIL-06, HIE-01, HIE-03, HIE-05, NAM-07, NAM-08, NAM-09, NAM-TBL, P1, P11, P12, P13, P14, P17, P18, P19, P2, P20, P21, P22, P24, P25, P26, P27, P29, P3, P30, P31, P32, P33, P4, P6, P7, PAR-01, PAR-02, R-019, R-027, R-032, R-035, R-036, R-038, R-071, R-072, SCP-01, SEC-8.1, SEQ-01, TYP-02, TYP-06, TYP-07
