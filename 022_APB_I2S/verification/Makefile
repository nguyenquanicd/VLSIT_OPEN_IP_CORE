# APB I2S testbench (verification only). Run from this folder with GNU make (C:\Users\PC\Tools\msys64\usr\bin\make.exe)
# or run the scripts directly with sh. PY is a Python 3 with only the standard library.
#
#   make quick      one build, the synthesis branch and three metastability seeds of the full configuration
#   make regress    quick plus the configuration matrix (logs/cdc, logs/matrix, logs/summary.txt)
#   make wf         the 17 waveform scenarios, WaveJSON/SVG and the comparison with the figures (waveforms_sim)
#   make cov        build with coverage, three seeds, merged report (logs/coverage_report.md)
#   make mutants    17 injected-bug copies of the RTL and the suite against each (logs/mutants.txt)
#   make evidence   vlsit_sim_evidence.py check of the waveform evidence and the CDC logs
#   make clean      remove build/ and the generated logs

SH        ?= sh
PY        ?= C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe
SKILL     ?= C:/Users/PC/.claude/skills/vlsit-rtl-generator/scripts
SPEC      ?= ../spec/VLSIT_APB_I2S_HDS.md
COVTOOLS  ?= C:/Tools/oss-cad-suite/bin

.PHONY: quick regress wf cov mutants evidence clean

quick:
	$(SH) ./regress.sh quick

regress:
	$(SH) ./regress.sh

wf:
	PY="$(PY)" $(SH) ./run_wf.sh
	$(PY) tools/wf_report.py
	for f in waveforms_sim/wf_*.json; do $(PY) C:/Users/PC/.claude/skills/vlsit-asic-ip-microspec/scripts/vlsit_waveform_svg.py render $$f --out waveforms_sim/$$(basename $$f .json).svg --force; done

cov:
	$(SH) ./build.sh cov --cov
	mkdir -p logs/cov
	cd logs/cov && for s in 1 2 3; do ../../build/cov/Vtb_i2s.exe +TEST=ALL +SEED=$$s +N=40 +AFIFO_MSYNC_SEED=$$s +AFIFO_MSYNC_EN=1 +RSTSYNC_MSYNC_SEED=$$s > cov_run_s$$s.log 2>&1; cp coverage.dat coverage_s$$s.dat; done
	cd logs/cov && $(COVTOOLS)/verilator_coverage_bin.exe --write merged.dat coverage_s1.dat coverage_s2.dat coverage_s3.dat
	$(PY) tools/cov_report.py logs/cov/merged.dat > logs/coverage_report.md

mutants:
	$(PY) tools/mutate.py make
	$(SH) ./run_mutants.sh

evidence:
	$(PY) $(SKILL)/vlsit_sim_evidence.py check $(SPEC) waveforms_sim --logs logs/cdc

clean:
	rm -rf build mutants logs/cdc logs/matrix logs/wf logs/mutants logs/cov logs/summary.txt
