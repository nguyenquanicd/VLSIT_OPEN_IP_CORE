## Test to function matrix

Order: combined tests first, the test with the most functions first (R-246).

| Order | Test | Kind | Test type | Priority | Functions exercised | Count | Interaction checked | Requirements |
|---:|---|---|---|---|---|---:|---|---|
| 1 | t_host_enum_bulk_dma | combined | combined | high, medium | data_toggle; connect_detect; port_reset; hs_chirp; host_sof; host_sched; crc; fifo_mgr; axi_master_dma; interrupt; utmi_if; turnaround; suspend_resume; lpm | 14 | Channels compete for the frame budget while SOF must stay periodic and the DMA refills channel FIFOs; a scheduler or FIFO fault shows as a late SOF, a lost packet or a wrong toggle. | REQ-FUNC-004; REQ-FUNC-010; REQ-FUNC-011; REQ-FUNC-012; REQ-FUNC-014; REQ-FUNC-015; REQ-FUNC-016; REQ-FUNC-020; REQ-FUNC-021; REQ-FUNC-037; REQ-IF-001; REQ-IF-008; REQ-IF-012 |
| 2 | t_dev_enum_bulk_dma | combined | combined | high | dev_token_addr; hs_chirp; crc; data_toggle; ping_nyet; fifo_mgr; axi_master_dma; interrupt; csr_apb; utmi_if; cdc; turnaround | 12 | Chirp, control transfers and bulk data share the FIFO RAM, the register crossing and the DMA; a toggle, credit or crossing fault shows as a data mismatch or a wrong handshake. | REQ-FUNC-001; REQ-FUNC-003; REQ-FUNC-004; REQ-FUNC-005; REQ-FUNC-006; REQ-FUNC-007; REQ-FUNC-013; REQ-FUNC-024; REQ-FUNC-027; REQ-IF-001; REQ-IF-005; REQ-IF-006; REQ-IF-008; REQ-CLK-001 |
| 3 | t_dev_iso_int_mix | combined | combined | high, medium | packet_size; hb_iso; zlp_short; fifo_mgr; axi_master_dma; turnaround; interrupt | 7 | Isochronous packets without retry share RAM regions and DMA bandwidth with retried transfers; starvation or a wrong data PID order shows as iso_inc or a payload mismatch. | REQ-FUNC-008; REQ-FUNC-009; REQ-FUNC-029; REQ-FUNC-030; REQ-FUNC-031; REQ-FUNC-033 |
| 4 | t_dev_suspend_lpm_reset | combined | combined | high, medium | hs_chirp; suspend_resume; lpm; cdc; reset; utmi_if | 6 | Power states change the PHY mode pins while register commands cross clock domains; a lost command or a mode change outside idle shows on the PHY pins. | REQ-FUNC-013; REQ-FUNC-018; REQ-FUNC-019; REQ-FUNC-021; REQ-IF-012; REQ-CLK-003; REQ-RESET-001; REQ-RESET-002; REQ-REG-003 |
| 5 | t_dev_axis_win | combined | combined | high | fifo_mgr; axi_slave; dev_token_addr; data_toggle; interrupt | 5 | Bus-side credits and packet events cross to the FIFO manager while the USB side reads and writes the same regions; a credit fault shows as a lost or duplicated row. | REQ-FUNC-027; REQ-IF-007; REQ-IF-009 |
| 6 | t_dev_pipe_equiv | combined | combined | high | turnaround; dev_token_addr; data_toggle; fifo_mgr; cdc | 5 | Pipeline stages add latency on receive, CRC and register paths; a stage that changes behavior shows as a response outside the turn-around window or a data mismatch. | REQ-FUNC-006 |
| 7 | t_dev_ulpi_traffic | combined | combined | high | turnaround; ulpi_if; dev_token_addr; data_toggle; suspend_resume | 5 | RX CMD bytes and register accesses interleave with packet data on the same bus; a turn-around or abort fault shows as a corrupted packet or a late response. | REQ-FUNC-006; REQ-IF-003; REQ-IF-004; REQ-IF-011 |
| 8 | t_dual_role_switch | combined | combined | high, medium | dual_role; port_reset; hs_chirp; connect_detect; dev_token_addr | 5 | Both engines share the link, the FIFO RAM and the PHY mode outputs; a role change before session end shows as two drivers of the mode pins or stale FIFO data. | REQ-FUNC-023; REQ-FUNC-024 |
| 9 | t_host_split_poll | combined | combined | high | host_sched; split; host_sof; data_toggle; fifo_mgr | 5 | Start-split and complete-split phases are spread over microframes and share the periodic schedule with polled channels; a phase or retry-count fault shows as a wrong token in a microframe. | REQ-FUNC-015; REQ-FUNC-017; REQ-FUNC-032; REQ-FUNC-038; REQ-FUNC-039 |
| 10 | t_host_ulpi_ocp | combined | combined | high, medium | connect_detect; ulpi_if; ocp; port_reset; dual_role | 5 | The power-off command travels from CLK-BUS to a ULPI register write while the port state machine runs; a lost command leaves VBUS driven. | REQ-FUNC-016; REQ-FUNC-041; REQ-IF-003; REQ-IF-013 |
| 11 | t_dev_sg_dma | combined | combined | high | zlp_short; sg_dma; axi_master_dma; interrupt | 4 | Descriptor fetch, data bursts and status writeback share the AXI channels; an arbitration or length fault shows in the memory image or the descriptor status. | REQ-FUNC-030; REQ-FUNC-031; REQ-FUNC-036; REQ-IF-014 |
| 12 | t_fi_host_bus_errors | single | fault_injection | high, medium | data_toggle; turnaround; hb_iso; split; interrupt; babble | 6 | - | REQ-FUNC-004; REQ-FUNC-025; REQ-FUNC-033; REQ-FUNC-039; REQ-ERR-001; REQ-ERR-002 |
| 13 | t_fi_bus_errors | single | fault_injection | high | dev_token_addr; crc; data_toggle; turnaround; interrupt | 5 | - | REQ-FUNC-002; REQ-FUNC-003; REQ-FUNC-004; REQ-FUNC-025; REQ-ERR-001 |
| 14 | t_dir_timing_ts1 | single | directed | high, medium | port_reset; hs_chirp; suspend_resume; process | 4 | - | REQ-FUNC-011; REQ-FUNC-012; REQ-FUNC-013; REQ-FUNC-018; REQ-FUNC-020; REQ-VER-002 |
| 15 | t_fml_ocp_irq_rst | single | formal | high | ocp; interrupt; reset | 3 | - | REQ-FUNC-034; REQ-IF-008; REQ-RESET-001 |
| 16 | t_rand_dev_traffic | single | constrained_random | high, medium | packet_size; fifo_mgr; axi_master_dma | 3 | - | REQ-FUNC-008; REQ-FUNC-026; REQ-IF-006 |
| 17 | t_dir_csr_regs | single | directed | high, medium | csr_apb; param_cfg | 2 | - | REQ-IF-005; REQ-PARAM-003; REQ-REG-001 |
| 18 | t_dir_param_builds | single | directed | high, medium | dev_token_addr; param_cfg | 2 | - | REQ-FUNC-007; REQ-FUNC-028; REQ-PARAM-001; REQ-PARAM-002; REQ-PARAM-003; REQ-PARAM-004 |
| 19 | t_fi_axi_err | single | fault_injection | high | axi_master_dma; interrupt | 2 | - | REQ-IF-006; REQ-IF-014; REQ-ERR-001 |
| 20 | t_dir_clk_ratio | single | directed | high | cdc | 1 | - | REQ-CLK-001 |
| 21 | t_dir_reset_midxfer | single | directed | high | reset | 1 | - | REQ-RESET-001 |
| 22 | t_fi_axis_err | single | fault_injection | high | axi_slave | 1 | - | REQ-IF-007 |
| 23 | t_fi_csr_access | single | fault_injection | high | csr_apb | 1 | - | REQ-IF-005 |
| 24 | t_fi_ocp | single | fault_injection | high | ocp | 1 | - | REQ-FUNC-034; REQ-FUNC-041; REQ-IF-010 |
| 25 | t_fi_ram_parity | single | fault_injection | high | ram_parity | 1 | - | REQ-FUNC-040 |
| 26 | t_fi_ulpi_abort | single | fault_injection | high | ulpi_if | 1 | - | REQ-IF-003 |
| 27 | t_fi_xq_full | single | fault_injection | high | cdc | 1 | - | REQ-REG-002 |
| 28 | t_fml_cdc_xreg | single | formal | high | cdc | 1 | - | REQ-CLK-002; REQ-CLK-003; REQ-REG-002; REQ-REG-003 |
| 29 | t_fml_crc | single | formal | high | crc | 1 | - | REQ-FUNC-003 |
| 30 | t_fml_fifo | single | formal | high | fifo_mgr | 1 | - | REQ-FUNC-027; REQ-FUNC-029 |
| 31 | t_perf_iso_in | single | stress | high | axi_master_dma | 1 | - | REQ-PERF-001 |
| 32 | t_rand_dev16_traffic | single | constrained_random | high | utmi_if | 1 | - | REQ-IF-002 |
| 33 | t_rand_host_traffic | single | constrained_random | high | fifo_mgr | 1 | - | REQ-FUNC-026 |
| 34 | t_dir_test_mode | single | directed | medium | test_mode | 1 | - | REQ-FUNC-022 |
| 35 | t_rev_process | single | directed | medium | process | 1 | - | REQ-RTL-001; REQ-VER-001; REQ-VER-002; REQ-VER-003; REQ-DFT-001 |
| 36 | t_dir_loopback | single | directed | low | loopback | 1 | - | REQ-FUNC-035 |

## Function to test matrix

| Function | Combined tests | Single-function tests | Status |
|---|---|---|---|
| test_mode | - | t_dir_test_mode | no combination: test modes stop normal traffic by definition |
| param_cfg | - | t_dir_param_builds; t_dir_csr_regs | no combination: elaboration check, not a run-time function |
| loopback | - | t_dir_loopback | no combination: loopback isolates the PHY, no bus traffic can run with it |
| ram_parity | - | t_fi_ram_parity | no combination: fault injection test |
| babble | - | t_fi_host_bus_errors | no combination: fault injection test |
| process | - | t_dir_timing_ts1; t_rev_process | no combination: review requirement |
| dev_token_addr | t_dev_enum_bulk_dma; t_dev_pipe_equiv; t_dev_ulpi_traffic; t_dual_role_switch; t_dev_axis_win | t_fi_bus_errors; t_dir_param_builds | combined covered |
| hs_chirp | t_dev_enum_bulk_dma; t_host_enum_bulk_dma; t_dev_suspend_lpm_reset; t_dual_role_switch | t_dir_timing_ts1 | combined covered |
| crc | t_dev_enum_bulk_dma; t_host_enum_bulk_dma | t_fi_bus_errors; t_fml_crc | combined covered |
| data_toggle | t_dev_enum_bulk_dma; t_host_enum_bulk_dma; t_dev_pipe_equiv; t_dev_ulpi_traffic; t_host_split_poll; t_dev_axis_win | t_fi_bus_errors; t_fi_host_bus_errors | combined covered |
| ping_nyet | t_dev_enum_bulk_dma | - | combined covered |
| fifo_mgr | t_dev_enum_bulk_dma; t_host_enum_bulk_dma; t_dev_pipe_equiv; t_dev_iso_int_mix; t_host_split_poll; t_dev_axis_win | t_rand_dev_traffic; t_rand_host_traffic; t_fml_fifo | combined covered |
| axi_master_dma | t_dev_enum_bulk_dma; t_host_enum_bulk_dma; t_dev_iso_int_mix; t_dev_sg_dma | t_rand_dev_traffic; t_fi_axi_err; t_perf_iso_in | combined covered |
| interrupt | t_dev_enum_bulk_dma; t_host_enum_bulk_dma; t_dev_iso_int_mix; t_dev_axis_win; t_dev_sg_dma | t_fi_bus_errors; t_fi_host_bus_errors; t_fml_ocp_irq_rst; t_fi_axi_err | combined covered |
| csr_apb | t_dev_enum_bulk_dma | t_dir_csr_regs; t_fi_csr_access | combined covered |
| utmi_if | t_dev_enum_bulk_dma; t_host_enum_bulk_dma; t_dev_suspend_lpm_reset | t_rand_dev16_traffic | combined covered |
| cdc | t_dev_enum_bulk_dma; t_dev_pipe_equiv; t_dev_suspend_lpm_reset | t_dir_clk_ratio; t_fml_cdc_xreg; t_fi_xq_full | combined covered |
| turnaround | t_dev_enum_bulk_dma; t_host_enum_bulk_dma; t_dev_pipe_equiv; t_dev_ulpi_traffic; t_dev_iso_int_mix | t_fi_bus_errors; t_fi_host_bus_errors | combined covered |
| connect_detect | t_host_enum_bulk_dma; t_host_ulpi_ocp; t_dual_role_switch | - | combined covered |
| port_reset | t_host_enum_bulk_dma; t_host_ulpi_ocp; t_dual_role_switch | t_dir_timing_ts1 | combined covered |
| host_sof | t_host_enum_bulk_dma; t_host_split_poll | - | combined covered |
| host_sched | t_host_enum_bulk_dma; t_host_split_poll | - | combined covered |
| suspend_resume | t_host_enum_bulk_dma; t_dev_ulpi_traffic; t_dev_suspend_lpm_reset | t_dir_timing_ts1 | combined covered |
| lpm | t_host_enum_bulk_dma; t_dev_suspend_lpm_reset | - | combined covered |
| hb_iso | t_dev_iso_int_mix | t_fi_host_bus_errors | combined covered |
| split | t_host_split_poll | t_fi_host_bus_errors | combined covered |
| ulpi_if | t_dev_ulpi_traffic; t_host_ulpi_ocp | t_fi_ulpi_abort | combined covered |
| packet_size | t_dev_iso_int_mix | t_rand_dev_traffic | combined covered |
| zlp_short | t_dev_iso_int_mix; t_dev_sg_dma | - | combined covered |
| reset | t_dev_suspend_lpm_reset | t_fml_ocp_irq_rst; t_dir_reset_midxfer | combined covered |
| ocp | t_host_ulpi_ocp | t_fi_ocp; t_fml_ocp_irq_rst | combined covered |
| dual_role | t_host_ulpi_ocp; t_dual_role_switch | - | combined covered |
| axi_slave | t_dev_axis_win | t_fi_axis_err | combined covered |
| sg_dma | t_dev_sg_dma | - | combined covered |
