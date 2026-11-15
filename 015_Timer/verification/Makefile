# Timer DMA req/ack simulation. Run from this directory with GNU make.
PYTHON := C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe
VERILATOR := C:/Tools/oss-cad-suite/bin/verilator_bin.exe
VERILATOR_ROOT := C:/Tools/oss-cad-suite/share/verilator
RTL_RULES := -Wno-fatal -Wno-lint -Wno-style
BUILD := build
UNAME_S := $(shell uname -s 2>/dev/null)
EXE_SUFFIX :=
ifneq ($(findstring Windows_NT,$(OS))$(findstring MINGW,$(UNAME_S))$(findstring MSYS,$(UNAME_S))$(findstring CYGWIN,$(UNAME_S)),)
  EXE_SUFFIX := .exe
endif
EXE := $(BUILD)/dma/Vtb_timer_dma_reqack$(EXE_SUFFIX)

export VERILATOR_ROOT

.PHONY: all dma clean

all: dma

# 32-bit counter record: capture and compare/update 4-phase req/ack, error and clear recovery.
dma:
	@mkdir -p $(BUILD)/dma
	$(VERILATOR) --binary --timing --top-module tb_timer_dma_reqack --Mdir $(BUILD)/dma -MAKEFLAGS 'PYTHON3=$(PYTHON)' -CFLAGS '-D_GLIBCXX_USE_CXX11_ABI=0' $(RTL_RULES) ../rtl/m_vlsit_timer_dma.sv tb_timer_dma_reqack.sv
	$(PYTHON) -c "import os,subprocess,sys; sys.exit(subprocess.run([os.path.abspath(sys.argv[1])]).returncode)" $(EXE)

clean:
	rm -rf $(BUILD)
