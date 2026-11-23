# CRC synthesis guide

Run from the repository root with Python 3 and an OSS CAD Suite installation that provides Yosys and the slang plugin. In PowerShell:

```powershell
$env:OSS_CAD_SUITE = 'C:/Tools/oss-cad-suite'
python 004_CRC/verification/tests/run_flow.py synth
```

Set the path to your local installation. To run one configuration, add `--config base0`. The runner generates the per-configuration `synth.ys` with the paths for the current checkout. Use the runner on a fresh checkout because a saved `synth.ys` can contain machine-specific paths.

Results are written under `004_CRC/verification/tests/sanity/synthesis/<configuration>/`. The directory keeps its Yosys scripts and this guide in Git. Generated synthesis logs, statistics, and Verilog/JSON netlists are local outputs.
