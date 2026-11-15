SHELL         := /bin/bash
FLIST         ?= filelist.f
FLIST_TB      ?= ../sim/filelist_tb.f
BUILD_DIR     ?= ../sim
VCS           ?= vcs
VERDI         ?= verdi
SIMV       := $(BUILD_DIR)/simv
# export UART_PATH=/home/lamctv/fu3/hw/rtl/ip/uart
# export VCS_HOME=/opt/synopsys/vcs/X-2025.06
SPYGLASS      ?= spyglass
LINT_DIR      ?= ../lint
LINT_PRJ      ?= lint.prj
LINT_GOALS    ?= lint/lint_rtl
TOP_MODULE    ?= m_fpt_uart_wrap
TOP_MODULE_TB ?= tb_uart_rx_resync
DC            ?= dc_shell
FORMALITY     ?= /opt/synopsys/fm/X-2025.06-SP4/bin/fm_shell
LEC_SCRIPT    ?= ../lec/uart_apb_lec.tcl
LEC_LOG       ?= ../lec/uart_apb_lec.log
SYN_DIR       ?= ../syn
SYN_SCRIPT    ?= script/uart_syn.tcl
SYN_LOG       ?= logs/uart_syn_dc.log
PDK_ROOT      ?= $(abspath /home/shared/PDK/22FDX-EXT/IP/v-logic_in_gf22fdx_sc7p5t_116cpp_base_csc28sl/GF22FDX_SC7P5T_116CPP_BASE_CSC28SL_FDK_RELV03R80/model/timing/db)
ROOT          := $(shell pwd)

VCS_OPTS      ?= -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb
RUN_OPTS      ?= +vcs+lic+wait

.PHONY: all prep compile run sim rx_compare verdi lint syn lec clean del_w build_w all_w

all: run
prep:
	@mkdir -p $(BUILD_DIR)

compile: prep
	@echo "--- Compiling SystemVerilog & Elaborating ---"
	$(VCS) $(VCS_OPTS) -f $(FLIST_TB) -top $(TOP_MODULE_TB) -l $(BUILD_DIR)/compile.log -o $(SIMV)

run: compile
	cd $(BUILD_DIR) && ./simv $(RUN_OPTS) | tee run.log

sim: run

rx_compare:
	VCS="$(VCS)" bash ../sim/run_rx_compare.sh $(RUN_OPTS)

verdi:
	cd $(BUILD_DIR) && $(VERDI) -ssf simv.fsdb &

lint:
	cd $(LINT_DIR) && $(SPYGLASS) -project $(LINT_PRJ) -batch -goals "$(LINT_GOALS)" | tee spyglass.log
syn:
	@echo "[SYN] PDK_ROOT=$(PDK_ROOT)"
	mkdir -p $(SYN_DIR)/logs
	set -o pipefail; cd $(SYN_DIR) && PDK_ROOT="$(PDK_ROOT)" $(DC) -f $(SYN_SCRIPT) | tee $(SYN_LOG)

lec:
	$(FORMALITY) -file $(LEC_SCRIPT) -output_log_file $(LEC_LOG) -overwrite

del_w:
	cp -rf ./emacs/m_fpt_uart_wrap.sv .
	emacs --batch ./m_fpt_uart_wrap.sv -f verilog-batch-delete-auto

build_w:
	emacs --batch \
		--eval "(require 'verilog-mode)" \
		--eval "(setq verilog-library-directories '(\".\" \"$(UART_PATH)/logical\"))" \
		--eval "(setq verilog-library-files '(\"$(UART_PATH)/logical/apb_uart.sv\"))" \
		--eval "(setq verilog-library-extensions '(\".v\" \".sv\" \".svh\"))" \
		--eval "(setq verilog-auto-read-includes t)" \
		./m_fpt_uart_wrap.sv -f verilog-batch-auto

all_w: del_w build_w

clean:
	@echo "[CLEAN] Removing previous UART simulation outputs from $(BUILD_DIR)..."
	rm -rf "$(BUILD_DIR)/csrc" \
	       "$(BUILD_DIR)/simv" \
	       "$(BUILD_DIR)/simv.daidir" \
	       "$(BUILD_DIR)/ucli.key" \
	       "$(BUILD_DIR)/DVEfiles" \
	       "$(BUILD_DIR)/AN.DB" \
	       "$(BUILD_DIR)/64" \
	       "$(BUILD_DIR)"/novas* \
	       "$(BUILD_DIR)"/*.fsdb* \
	       "$(BUILD_DIR)"/*.vcd \
	       "$(BUILD_DIR)"/*.vpd \
	       "$(BUILD_DIR)"/*.log \
	       "$(BUILD_DIR)/verdiLog"
