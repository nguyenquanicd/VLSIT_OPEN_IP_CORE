# Reference material of the APB I2S IP

| File | What it is |
|---|---|
| `VLSIT_APB_I2S_HDS.md`, `I2S_CSR.xlsx`, `I2S_CSR.json`, `figures/` | First version of the specification, extracted from a vendor databook (Synopsys-style feature set, 4 stereo channels, left/right register pairs). Kept only for comparison. **Superseded** by `../spec/`. |
| `SoC_I2S_Feature_Survey.md` | Survey of the I2S controller of an MCU (ESP32-S3) and of an application processor (i.MX RT1170), with a comparison table against the IP. Source of the fused features. |

The current specification is in `../spec/` (generic frame engine, independent transmit and receive units, one ordered data register per direction, eight interrupt causes with raw/enable/injection/status registers, new register map).
