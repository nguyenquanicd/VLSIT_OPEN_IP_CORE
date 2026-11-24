# DVP Controller build, lint and verification entry points.
# Run with GNU make from MSYS2/Git Bash on Windows.
SHELL := /usr/bin/sh
.DEFAULT_GOAL := help

PYTHON ?= python3
SKILL_ROOT ?= $(HOME)/.agents/skills
RTL_SKILL := $(SKILL_ROOT)/vlsit-rtl-generator/scripts
MICROSPEC_SKILL := $(SKILL_ROOT)/vlsit-asic-ip-microspec/scripts
WAVEDROM_SKILL := $(SKILL_ROOT)/vlsit-wavedrom-waveform/scripts

OSSCAD ?=
OSSCAD_P := $(or $(shell cygpath -u "$(OSSCAD)" 2>/dev/null),$(OSSCAD))
PATHSEP := $(if $(findstring ;,$(PATH)),;,:)
export PATH := $(OSSCAD_P)/bin$(PATHSEP)$(OSSCAD_P)/lib$(PATHSEP)$(PATH)
export OSS_CAD_SUITE := $(OSSCAD)

TOP ?= m_dvp_controller
RUN ?= final
HDS := spec/VLSIT_DVP_CONTROLLER_HDS.md
CSR_JSON := spec/VLSIT_DVP_CONTROLLER_CSR.json
WAVEFORM_DIR := spec/figures/waveforms

.PHONY: help all rule lint lint-verilator lint-slang spec-check wavejson-check check regress regression verify

help:
	@echo "DVP Controller targets:"
	@echo "  make rule             VLSIT RTL rule check"
	@echo "  make lint             rule check + Verilator and Slang lint"
	@echo "  make lint-verilator   Verilator lint (warnings are reported separately)"
	@echo "  make lint-slang       Slang lint"
	@echo "  make spec-check       HDS, specification-gap and CSR validation"
	@echo "  make wavejson-check   lint all specification WaveJSON files"
	@echo "  make regress          checker qualification, parameter legality, scope review and the regression matrix"
	@echo "                        (Verilator; writes a new verification/sim/$(RUN)/, refuses an existing one: make regress RUN=name)"
	@echo "  make regression       lint + check + regress"
	@echo "Override PYTHON, SKILL_ROOT, OSSCAD, RUN or TOP as needed. Tool paths for the driver are at the top of verification/env/scripts/dvp_regress.py."

all: regression

rule:
	@set -eu; $(PYTHON) "$(RTL_SKILL)/vlsit_rtl_check.py" check rtl > lint/make_rtl_rule.log 2>&1 || { cat lint/make_rtl_rule.log; exit 1; }; cat lint/make_rtl_rule.log

lint-verilator:
	$(PYTHON) "$(RTL_SKILL)/vlsit_lint_rtl.py" lint rtl/filelist.f --top $(TOP) --tool verilator --log lint/make_verilator.log

lint-slang:
	$(PYTHON) "$(RTL_SKILL)/vlsit_lint_rtl.py" lint rtl/filelist.f --top $(TOP) --tool slang --log lint/make_slang.log

lint: rule lint-verilator lint-slang

spec-check:
	@set -eu; \
	$(PYTHON) "$(MICROSPEC_SKILL)/vlsit_spec_tool.py" check "$(HDS)" --naming default > spec/validation_logs/make_spec_check_2026-11-23.log 2>&1 || { cat spec/validation_logs/make_spec_check_2026-11-23.log; exit 1; }; \
	$(PYTHON) "$(RTL_SKILL)/vlsit_spec_gaps.py" gaps "$(HDS)" >> spec/validation_logs/make_spec_check_2026-11-23.log 2>&1 || { cat spec/validation_logs/make_spec_check_2026-11-23.log; exit 1; }; \
	$(PYTHON) "$(MICROSPEC_SKILL)/vlsit_csr_tool.py" validate "$(CSR_JSON)" >> spec/validation_logs/make_spec_check_2026-11-23.log 2>&1 || { cat spec/validation_logs/make_spec_check_2026-11-23.log; exit 1; }; \
	cat spec/validation_logs/make_spec_check_2026-11-23.log

wavejson-check:
	@set -eu; : > spec/validation_logs/make_wavejson_2026-11-23.log; \
	for wave in $(WAVEFORM_DIR)/*.json; do \
	  test -f "$${wave}" || { echo "No WaveJSON files found in $(WAVEFORM_DIR)"; exit 1; }; \
	  $(PYTHON) "$(WAVEDROM_SKILL)/vlsit_wavedrom_waveform.py" lint "$${wave}" >> spec/validation_logs/make_wavejson_2026-11-23.log 2>&1 || { cat spec/validation_logs/make_wavejson_2026-11-23.log; exit 1; }; \
	done; \
	cat spec/validation_logs/make_wavejson_2026-11-23.log

check: rule spec-check wavejson-check

regress:
	$(PYTHON) -X utf8 verification/env/scripts/dvp_regress.py --out verification/sim/$(RUN)

regression verify: lint check regress
