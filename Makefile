# Repository-wide entry points. Run with GNU make from MSYS2/Git Bash on Windows.
SHELL := /usr/bin/sh
.DEFAULT_GOAL := help

PY ?= C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe
PYTHON ?= $(PY)
SKILL ?= C:/Users/PC/.codex/skills/vlsit-rtl-generator/scripts
OSSCAD ?= C:/Tools/oss-cad-suite

OSSCAD_P := $(or $(shell cygpath -u "$(OSSCAD)" 2>/dev/null),$(OSSCAD))
export PATH := $(OSSCAD_P)/bin:$(OSSCAD_P)/lib:$(PATH)
export PYTHON

IP_DIRS := \
  001_AsyncGrayFIFO \
  002_SyncFIFO \
  003_AsyncAXI4Bridge \
  004_CRC \
  005_AsyncAPBBridge \
  006_AHB2AXI_Bridge \
  007_AXI2APB_Bridge \
  008_AXI2TLUL_Bridge \
  009_APB2TLUL_Bridge \
  010_Async4PhaseHandshake \
  011_Async2PhaseHandshake \
  012_HyperRAM_Controller \
  013_AsyncGrayCodeSync \
  014_AXI4_Upsizer \
  015_Timer \
  016_CAN_Controller \
  017_QSPI_Controller \
  018_MKV_Block_Cipher \
  019_SHA2_SHA3_Hash \
  020_WDT \
  021_UART

.PHONY: help all lint check regression

help:
	@echo "make lint        - lint the default RTL top in each IP Makefile"
	@echo "make check       - run each IP's VLSIT RTL rule check"
	@echo "make regression  - run available self-checking IP regressions"
	@echo "make all         - run check, lint and regression"
	@echo "Override PY, PYTHON, SKILL or OSSCAD for local tool installations."

all: check lint regression

lint:
	@set +e; failed=0; \
	for ip in $(IP_DIRS); do \
	  echo "== Lint $$ip =="; \
	  $(MAKE) --no-print-directory -C "$$ip" lint; rc=$$?; \
	  if test $$rc -ne 0; then echo "FAIL lint $$ip"; failed=1; else echo "PASS lint $$ip"; fi; \
	done; \
	if test $$failed -ne 0; then exit 1; fi

check:
	@set +e; failed=0; \
	for ip in $(IP_DIRS); do \
	  echo "== RTL rule check $$ip =="; \
	  $(MAKE) --no-print-directory -C "$$ip" rule; rc=$$?; \
	  if test $$rc -ne 0; then echo "FAIL rule check $$ip"; failed=1; else echo "PASS rule check $$ip"; fi; \
	done; \
	if test $$failed -ne 0; then exit 1; fi

regression:
	@set +e; failed=0; \
	run() { label=$$1; shift; echo "== $$label =="; "$$@"; rc=$$?; \
	  if test $$rc -ne 0; then echo "FAIL $$label (exit $$rc)"; failed=1; else echo "PASS $$label"; fi; }; \
	run "Common basic-cell tests" "$(PYTHON)" 000_Common/cell_tests/run_cell_tests.py; \
	run "Common library-wrapper tests" "$(PYTHON)" 000_Common/lib_tests/run_lib_tests.py; \
	run "Sync FIFO regression" $(MAKE) --no-print-directory -C 002_SyncFIFO verify; \
	run "Async AXI bridge regression" $(MAKE) --no-print-directory -C 003_AsyncAXI4Bridge/verification test; \
	run "CRC engine regression" $(MAKE) --no-print-directory -C 004_CRC verify; \
	run "Async APB quick matrix" sh -c 'cd 005_AsyncAPBBridge/verification && "$(PYTHON)" vlsit_run_sim.py quick'; \
	run "AHB-to-AXI regression cases" $(MAKE) --no-print-directory -C 006_AHB2AXI_Bridge/verification sim; \
	run "AXI-to-TL-UL regression matrix" sh -c 'cd 008_AXI2TLUL_Bridge/verification && "$(PYTHON)" vlsit_run_sim.py regress --seeds 1,2,3'; \
	run "APB-to-TL-UL default simulation" $(MAKE) --no-print-directory -C 009_APB2TLUL_Bridge -f verification/Makefile sim; \
	run "APB-to-TL-UL narrow simulation" $(MAKE) --no-print-directory -C 009_APB2TLUL_Bridge -f verification/Makefile sim-narrow; \
	run "Two-phase handshake regression" $(MAKE) --no-print-directory -C 011_Async2PhaseHandshake verify; \
	run "HyperRAM x8 smoke" sh 012_HyperRAM_Controller/verification/run_smoke.sh 4; \
	run "HyperRAM x16 smoke" sh 012_HyperRAM_Controller/verification/run_smoke.sh 4 x16; \
	run "Gray-code synchronizer regression" $(MAKE) --no-print-directory -C 013_AsyncGrayCodeSync verify; \
	run "AXI upsizer regression matrix" sh -c 'cd 014_AXI4_Upsizer/verification && "$(PYTHON)" vlsit_run_sim.py regress --seeds 1,2,3'; \
	run "Timer DMA regression" $(MAKE) --no-print-directory -C 015_Timer/verification all; \
	run "CAN FD regression" $(MAKE) --no-print-directory -C 016_CAN_Controller/verification all; \
	run "MKV block-cipher regression" $(MAKE) --no-print-directory -C 018_MKV_Block_Cipher/verification regression; \
	run "SHA-2/SHA-3 full regression" sh -c 'cd 019_SHA2_SHA3_Hash/verification/scripts && "$(PYTHON)" run_all.py'; \
	if command -v vcs >/dev/null 2>&1; then \
	  run "UART VCS simulation" $(MAKE) --no-print-directory -C 021_UART/verification sim; \
	else echo "SKIP UART VCS simulation: Synopsys VCS is not on PATH"; fi; \
	if test $$failed -ne 0; then echo "One or more regression suites failed."; exit 1; fi
