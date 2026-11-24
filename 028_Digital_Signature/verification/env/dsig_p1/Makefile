# Makefile of the phase 1 verification of the digital signature IP (CSR, control block, buffer).
# Run from verification/env/dsig_p1. Needs Python 3 and the OSS CAD Suite tools on PATH
# (iverilog, vvp, verilator); see README.md for the PATH note on Windows.
# Targets: check (rule check), lint (Verilator), regress (all runs), waveforms (evidence), mutation,
#          evidence (R-033 and R-034 check of the evidence folders), all.
PY      ?= python
RTL     := ../../../rtl
SKILL   ?= $(HOME)/.claude/skills
GEN     := $(SKILL)/vlsit-rtl-generator/scripts
SPECSK  := $(SKILL)/vlsit-asic-ip-microspec
N       ?= 200

all: check lint regress waveforms evidence

check:
	$(PY) $(GEN)/vlsit_rtl_check.py check $(RTL)

lint:
	cd $(RTL) && $(PY) $(GEN)/vlsit_lint_rtl.py lint filelist.f --top m_vlsit_dsig_ctl
	cd $(RTL) && $(PY) $(GEN)/vlsit_lint_rtl.py lint filelist.f --top m_vlsit_dsig_buf

regress:
	$(PY) run_regress.py --n $(N) --seeds 1,2,3

waveforms:
	$(PY) run_waveforms.py --skill $(SPECSK) --python $(PY)

mutation:
	$(PY) run_mutation.py --n 80 --jobs 4

evidence:
	$(PY) $(GEN)/vlsit_sim_evidence.py check ../../../spec/VLSIT_DIGITAL_SIGNATURE_HDS.md ../../sim/waveforms_sim --logs ../../sim/regress
