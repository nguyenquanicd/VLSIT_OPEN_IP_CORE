# ---------------------------------------------------------------------------
# File     : chacha_top.sdc
# Function : timing-constraint skeleton of m_chacha_top (027_ChaCha)
# Status   : DRAFT. Every number is a Tcl variable that the integrator sets; no value
#            here is a measured or agreed timing. Source of the contract: HDS section 17
#            (spec/VLSIT_CHACHA_HDS.md). Tool and version are not chosen (TBD-002).
# Usage    : set the variables below (or pass them from the flow), then source this file.
# ---------------------------------------------------------------------------

# ----- values supplied by the integrator (clock periods in the unit of the library)
foreach v {CORE_PERIOD AXI_PERIOD APB_PERIOD} {
    if {![info exists $v]} { error "chacha_top.sdc: set $v before sourcing this file" }
}
# 1 when the clock is the same net as i_clk_core, 0 when asynchronous (PARA_SYNC_AXI_CORE, PARA_SYNC_APB_CORE)
if {![info exists SYNC_AXI_CORE]} { set SYNC_AXI_CORE 0 }
if {![info exists SYNC_APB_CORE]} { set SYNC_APB_CORE 0 }
# external delay share of the period (ASM-008: 60 percent, a starting proposal)
if {![info exists EXT_SHARE]} { set EXT_SHARE 0.6 }
# skew budget of the datapath-only bounds, as a share of the smaller clock period (ASM-008: 10 percent)
if {![info exists CDC_SKEW_SHARE]} { set CDC_SKEW_SHARE 0.1 }
# optional: collections that name the crossing registers of the instantiated library blocks
if {![info exists GRAY_PTR_PINS]}   { set GRAY_PTR_PINS   "" }   ;# EXC-002 source pins of the Gray pointers
if {![info exists GRAY_SYNC_PINS]}  { set GRAY_SYNC_PINS  "" }   ;# EXC-002 first synchronizer flop pins
if {![info exists CSR_HS_SRC_PINS]} { set CSR_HS_SRC_PINS "" }   ;# EXC-003 toggle and data source pins
if {![info exists CSR_HS_DST_PINS]} { set CSR_HS_DST_PINS "" }   ;# EXC-003 destination pins
if {![info exists QS_SRC_PINS]}     { set QS_SRC_PINS     "" }   ;# EXC-004 quasi-static parameter registers
if {![info exists QS_DST_PINS]}     { set QS_DST_PINS     "" }   ;# EXC-004 capture registers

# ----- 17.1.1 clocks (primary clocks on the ports, 50 percent duty assumed)
create_clock -name CLK_CORE -period $CORE_PERIOD [get_ports i_clk_core]
create_clock -name CLK_AXI  -period $AXI_PERIOD  [get_ports i_clk_axi]
create_clock -name CLK_APB  -period $APB_PERIOD  [get_ports i_clk_apb]

# EXC-001: clock groups by configuration. A synchronous pair is the same clock net and
# needs no group; an asynchronous pair is declared asynchronous. Crossings are proved by CDC analysis.
if {$SYNC_AXI_CORE == 0 && $SYNC_APB_CORE == 0} {
    set_clock_groups -asynchronous -group [get_clocks CLK_APB] -group [get_clocks CLK_AXI] -group [get_clocks CLK_CORE]
} elseif {$SYNC_AXI_CORE == 1 && $SYNC_APB_CORE == 0} {
    set_clock_groups -asynchronous -group [get_clocks CLK_APB] -group [get_clocks {CLK_AXI CLK_CORE}]
} elseif {$SYNC_AXI_CORE == 0 && $SYNC_APB_CORE == 1} {
    set_clock_groups -asynchronous -group [get_clocks CLK_AXI] -group [get_clocks {CLK_APB CLK_CORE}]
}
# a synchronous pair is given the same period by the integrator and no group is declared, so STA treats the two
# clocks as synchronous; with both parameters 1 all three clocks have one period and no group is declared.

# ----- 17.1.2 interface budgets (external delay = EXT_SHARE of the period, minimum 0)
proc chacha_io {clk period in_ports out_ports share} {
    set mx [expr {$share * $period}]
    if {[llength $in_ports]}  { set_input_delay  -clock $clk -max $mx $in_ports;  set_input_delay  -clock $clk -min 0 $in_ports }
    if {[llength $out_ports]} { set_output_delay -clock $clk -max $mx $out_ports; set_output_delay -clock $clk -min 0 $out_ports }
}
chacha_io CLK_APB $APB_PERIOD [get_ports {i_apb_* i_protect_en i_slverr_en}] [get_ports {o_apb_* o_int_cha}] $EXT_SHARE
chacha_io CLK_AXI $AXI_PERIOD [get_ports {i_axi_* i_dma_ack_*}]              [get_ports {o_axi_* o_dma_req_*}] $EXT_SHARE
chacha_io CLK_CORE $CORE_PERIOD [get_ports {i_key_data i_key_vld i_key_err}] [get_ports {o_key_req o_key_slot}]  $EXT_SHARE

# ----- 17.1.3 exceptions
# EXC-005: static inputs, constant after reset or in functional mode
set_false_path -from [get_ports {i_protect_en i_slverr_en i_dft_test_en i_dft_rst_n}]

# EXC-002, EXC-003, EXC-004: datapath-only bounds on asynchronous crossings. The value is the smaller of the
# two clock periods less the skew budget (a Gray pointer or a toggle must arrive within one period of the
# faster clock, HDS section 17.1.3); a stricter constraint supplied by the library block replaces it.
proc chacha_cdc_bound {src dst src_period dst_period} {
    if {[llength $src] && [llength $dst]} {
        set_max_delay -datapath_only [expr {min($src_period, $dst_period) * (1.0 - $::CDC_SKEW_SHARE)}] -from $src -to $dst
    }
}
if {$SYNC_AXI_CORE == 0} {
    chacha_cdc_bound $GRAY_PTR_PINS $GRAY_SYNC_PINS $AXI_PERIOD $CORE_PERIOD
    chacha_cdc_bound $QS_SRC_PINS $QS_DST_PINS $CORE_PERIOD $AXI_PERIOD
}
if {$SYNC_APB_CORE == 0} {
    chacha_cdc_bound $CSR_HS_SRC_PINS $CSR_HS_DST_PINS $APB_PERIOD $CORE_PERIOD
}
# The reset inputs are constrained by recovery and removal against the clock of their domain by the integrator.
# Scan-mode timing (i_dft_test_en high) belongs to the DFT flow and is not constrained here.
