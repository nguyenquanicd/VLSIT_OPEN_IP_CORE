#!/bin/sh
# Runs the two reproductions of the review of 2026-11-22 (F-021 and the NEP1/NHC decode of m_usb2_regs) and prints only the results.
# Usage: sh run_repro.sh      (Git Bash on Windows; Verilator of OSS CAD Suite and the MSYS2 ucrt64 compiler, as in verification/)
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE" || exit 1
for n in 4 15 16; do
  echo "==== F-021: m_usb2_axs, PARA_USB2_NUM_DMA_CH = $n"
  sh build_run.sh tb_repro_f021 "$HERE/tb_repro_f021.sv m_usb2_axs.sv" f021_$n +define+NCH=$n 2>&1 | grep -E "^(NUM_DMA_CH|RESULT)|%Error"
done
for cfg in "9 8" "15 16" "16 8" "9 16" "16 16"; do
  set -- $cfg
  echo "==== NEP1/NHC: m_usb2_regs, PARA_USB2_NEP1 = $1, PARA_USB2_NHC = $2"
  sh build_run.sh tb_repro_nep1 "$HERE/tb_repro_nep1.sv m_usb2_regs.sv" nep_$1_$2 +define+NEP1=$1 +define+NHC=$2 2>&1 | grep -E "^(EPI|HC_|RESULT|TIMEOUT)|%Error"
done
