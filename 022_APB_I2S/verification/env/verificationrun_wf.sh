#!/bin/sh
# Waveform evidence: builds the synthesis-branch design with VCD tracing, runs the 17 scenarios of section 10.3
# (one VCD per scenario), then writes the simulated WaveJSON and the comparison data (tools/wf_tool.py).
HERE=$(cd "$(dirname "$0")" && pwd)
export PATH="/c/Users/PC/Tools/msys64/ucrt64/bin:/c/Users/PC/Tools/msys64/usr/bin:/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
PY=${PY:-python}
sh "$HERE/build.sh" wf --syn --wave || exit 1
mkdir -p "$HERE/waveforms_sim" "$HERE/logs/wf"
i=0
for st in wf_001_apb_rw wf_002_apb_error wf_003_i2s_tx_master wf_004_i2s_rx_slave wf_005_fmt_i2s_lj wf_006_pcm_tdm_mask \
          wf_007_mask_change wf_008_unit_start wf_009_tx_underrun_auto wf_010_rx_overrun_err wf_011_ondemand wf_012_sync_hung \
          wf_013_dma_burst wf_014_dma_single wf_015_irq_four wf_016_stop_flush wf_017_reset; do
  i=$((i+1))
  "$HERE/build/wf/Vtb_i2s.exe" +WF=$i +VCD="$HERE/waveforms_sim/$st.vcd" > "$HERE/logs/wf/$st.log" 2>&1
  echo "$st: $(grep -E '^assertion failures' "$HERE/logs/wf/$st.log")"
done
"$PY" "$HERE/tools/wf_tool.py" build
