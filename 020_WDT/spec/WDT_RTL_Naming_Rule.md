# WDT RTL Naming Rule

Version: 1.0 (2026-11-14)

## Purpose and scope

This rule records the naming conventions observed in the supplied WDT RTL. It governs names used by the WDT specification and its diagrams. It does not authorize or require changes to existing RTL. Existing names are preserved verbatim when identifying modules and ports.

## Naming conventions

1. **Module names:** use the lowercase prefix `m_fpt_` followed by the function, for example `m_fpt_wdt_top`, `m_fpt_wdt_counter`, and `m_fpt_lib_sync_rising_edge_async_reset_n`.
2. **RTL file names:** use the module name as the file stem, for example `m_fpt_wdt_top.sv`.
3. **Top-level wrapper ports:** inputs use `i_wdt_`; outputs use `o_wdt_`. APB ports add `apb_`, for example `i_wdt_apb_paddr` and `o_wdt_apb_pready`.
4. **Functional module ports:** inputs use `i_`; outputs use `o_`. Preserve the functional signal name and clock-domain suffix used by each module, for example `i_clk_wdog`, `i_rst_n_wdog`, `o_int_wdog`, and `o_wdogres`.
5. **Clock and reset names:** use `clk_<domain>` and active-low `rst_n_<domain>` in the functional RTL. Preserve wrapper and legacy CSR forms where present, including `i_wdt_pclk`, `i_wdt_preset_n`, `i_wdt_clk`, `i_wdt_rst_n`, `i_bus_rstn`, and `i_reg_rstn`.
6. **Parameters:** use `PARA_` followed by an uppercase identifier, for example `PARA_WD_DATA_WIDTH`.
7. **Local parameters:** preserve the supplied convention `PARA_<FUNCTION>_OFFSET` for CSR offsets, for example `PARA_WD_CNT_LD_OFFSET`.
8. **Internal signals:** use `w_<function>` for intermediate combinational nets and `reg_<function>` for stored state, for example `w_cnt_val` and `reg_timeout_seen`.
9. **Instances:** use `u_<function>`, for example `u_fpt_wdt_counter`; numbered repeated instances start at zero, for example `u_sync_0` and `u_sync_1`.
10. **Named processes:** sequential processes use `p_ff_<function>` and combinational processes use `p_com_<function>` where the source provides a process name. Older/generated RTL with unnamed processes is preserved as-is.
11. **Interrupt naming:** use the existing functional name `o_int_wdog` internally and the SoC wrapper name `o_wdt_int` at the boundary.

## Source observations and exceptions

- The wrapper uses legacy top-level signal names, while `m_fpt_wdt_top` and the core use domain-oriented names; both forms are valid for their respective module boundaries.
- The CSR generator output uses short legacy names such as `i_bus_clk`, `i_bus_rstn`, and `o_wd_cnt_ctrl_cnt_en`. Do not rename them in a specification that describes this RTL snapshot.
- The CSR offsets are declared as `localparam` but carry the `PARA_` prefix in the supplied source; preserve that observed spelling.
- The top-level integration module is `m_fpt_wdt_wrap`; it instantiates `m_fpt_wdt_top`.

## Source files reviewed

The rule was derived from the SystemVerilog files in `rtl/` of this WDT directory. It is a documentation rule for this IP and is not the default VLSIT RTL naming rule.
