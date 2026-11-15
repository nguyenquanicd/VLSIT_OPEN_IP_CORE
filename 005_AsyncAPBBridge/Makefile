# 005_AsyncAPBBridge - RTL lint, rule check and regression.
# Run with GNU make (MSYS2/Git Bash on Windows). OSS CAD Suite is used for Verilator/slang/iverilog.
PY       ?= C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe
SKILL    ?= C:/Users/PC/.dsh/skills/vlsit-rtl-generator/scripts
OSSCAD   ?= C:/Tools/oss-cad-suite

# Put OSS CAD Suite bin/ and lib/ on PATH so iverilog/vvp find their DLLs.
ifneq ($(strip $(OSSCAD)),)
  ifneq ($(wildcard $(OSSCAD)/bin),)
    OSSCAD_P := $(or $(shell cygpath -u "$(OSSCAD)" 2>/dev/null),$(OSSCAD))
    PATHSEP  := $(if $(findstring ;,$(PATH)),;,:)
    export PATH := $(OSSCAD_P)/bin$(PATHSEP)$(OSSCAD_P)/lib$(PATHSEP)$(PATH)
  endif
endif

IVERILOG ?= iverilog
VVP      ?= vvp

FLIST    := rtl/filelist.f
TOP      := m_vlsit_async_apb_bridge
TB_TOP   := tb_apbcdc
TB_SRCS  := ../verification/tb_apbcdc.sv

.PHONY: help lint rule verify

help:
	@echo "make lint    - Verilator lint of $(FLIST)"
	@echo "make rule    - VLSIT RTL rule check (v2)"
	@echo "make verify  - compile + run the testbench (iverilog)"

lint:
	$(PY) $(SKILL)/vlsit_lint_rtl.py lint $(FLIST) --top $(TOP) --tool verilator

rule:
	$(PY) $(SKILL)/vlsit_rtl_check.py check rtl

verify:
	@mkdir -p build
	cd rtl && $(IVERILOG) -g2012 -s $(TB_TOP) -o ../build/sim.vvp -f filelist.f $(TB_SRCS)
	$(VVP) build/sim.vvp
