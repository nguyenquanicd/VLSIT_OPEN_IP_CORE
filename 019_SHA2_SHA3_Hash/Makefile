# 019_SHA2_SHA3_Hash - RTL lint, rule check and regression.
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

WORK     ?= $(shell $(PY) -c "import os;print(os.environ.get('TEMP','.').replace(chr(92),'/'))")/vlsit_019_ws
SUITES   ?= main64

FLIST    := rtl/filelist.f
TOP      := m_vlsit_sha_top

.PHONY: help lint rule verify

help:
	@echo "make lint    - Verilator lint of $(FLIST)"
	@echo "make rule    - VLSIT RTL rule check (v2)"
	@echo "make verify  - Verilator regression of the suites in SUITES (default main64) in a temporary workspace WORK"

lint:
	$(PY) $(SKILL)/vlsit_lint_rtl.py lint $(FLIST) --top $(TOP) --tool verilator --log lint/lint_verilator_make.log

rule:
	$(PY) $(SKILL)/vlsit_rtl_check.py check rtl

verify:
	$(PY) verification/env/run_regress_ws.py --work $(WORK) $(SUITES)
