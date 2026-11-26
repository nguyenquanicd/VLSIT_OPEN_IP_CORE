# Clock and reset domain crossings of m_vlsit_dsig_top

Structural analysis of the RTL and the simulation evidence. **No commercial CDC or RDC tool (Spyglass, Questa CDC, VC CDC) was run**: the
verification environment has none. What was run instead is `verification/env/misc/check_cdc.py`: it reads the real CSR RTL with yosys
(`PARA_ASYNCHRONOUS` 1, synchronizer cells as black boxes), gives every flip-flop the domain of its clock and checks every crossing
(7 groups found: 4 synchronizer cells each fed by one flip-flop without logic, and the bundled address/data/read-data flip-flops, each
qualified by a synchronized request or acknowledge) and that every flip-flop is reset by the reset of its own clock domain (102 cells,
0 violations). Three defects put into copies of the CSR are caught (logic before a synchronizer, a register write enabled by an
APB-domain signal, a register-side flop reset by the APB reset). This is a structural check of this one block, not a sign-off: no
metastability or reconvergence analysis, no waiver flow. The integrator's CDC/RDC sign-off with a tool and the SDC
`sdc/m_vlsit_dsig_top.sdc` remains to be done.

## Clock domains

| Clock | Port | Logic |
|---|---|---|
| CLK-CORE | `i_clk_core` | engines, hash stack, buffer, AXI4 block, key and random blocks, control block, and the register side of the CSR (`i_clk_reg` of `m_vlsit_csr_dsig` is connected to `i_clk_core`) |
| CLK-APB | `i_clk_apb` | the APB4 side of the CSR only; the same clock as CLK-CORE when `PARA_CSR_ASYNC` is 0 |

All other ports (AXI4, DMA, key, entropy, interrupt, alarm) are synchronous to CLK-CORE (section 17.1.2); the IP adds no
synchronizer on them by design, the SoC drives them from CLK-CORE.

## Crossings (`PARA_CSR_ASYNC` 1)

| Signal | From | To | Kind | Mechanism |
|---|---|---|---|---|
| `reg_wr_req` | CLK-APB | CLK-CORE | level request of a 4-phase handshake | `u_wr_req_sync` (library cell `m_vlsit_afifo_cell_sync`, 2 stages); the write is done on the rising edge of the synchronized request |
| `reg_rd_req` | CLK-APB | CLK-CORE | same | `u_rd_req_sync` |
| `w_wr_ack` | CLK-CORE | CLK-APB | level acknowledge | `u_wr_ack_sync` |
| `w_rd_ack` | CLK-CORE | CLK-APB | level acknowledge | `u_rd_ack_sync` |
| address, write data, strobes | CLK-APB | CLK-CORE | bundled data | stable from the request until the acknowledge; bounded by `set_max_delay -datapath_only` (EXC-001/002) |
| read data | CLK-CORE | CLK-APB | bundled data | stable until the acknowledge is seen; same bound |
| `i_protect_en`, `i_slverr_en` | SoC | CLK-APB | static | assumed static (pins of the generated CSR) |

## Reset domains

| Reset | Port | Scope |
|---|---|---|
| RST-CORE | `i_rst_n_core` | CLK-CORE logic and the register side of the CSR |
| RST-APB | `i_rst_n_apb` | the APB side of the CSR |

RST-APB alone in the middle of a CSR write clears the request toggle; the register side writes only on a rising edge of the
synchronized request, so a reset cannot create a write, and the pending write is either complete or not done. RST-CORE alone
while the APB side waits for an acknowledge: the register side restarts with its delayed request at 0 and sees the still-high
request as a rising edge again, so the pending write completes once (a repeated write of the same bundled data is harmless).

## Evidence

- Phase 1 runs with the asynchronous CSR: the synthesis branch of the synchronizer cells and the metastability model with three
  seeds (`verification/sim/regress/syn_async1.log`, `sim_async1_seed1..3.log`).
- `tb_top_err` with `PARA_CSR_ASYNC` 1 and unrelated clocks (10 ns core, 14 ns APB), including RST-APB asserted in the
  middle of a write of `dsig_tmo` (the register holds its old or its new value, the other registers are unchanged, the
  handshake works afterwards). One reset phase was tried, not a sweep of all phases.

Not covered: a structural CDC/RDC tool run, a sweep of the reset assertion over every phase of the handshake, glitch analysis
of the combinational paths into the synchronizers (the request and acknowledge are flip-flop outputs in the RTL).
