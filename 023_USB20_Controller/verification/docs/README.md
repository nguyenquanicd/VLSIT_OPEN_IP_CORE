# USB 2.0 verification / Kiểm chứng USB 2.0

- [Approved plan](plan_verification_plan.md), [vplan](plan_vplan.csv), [bug and triage log](bugs.md), [verification report](verification_report.md).
- [Scenario generators and testlist](../tests/usb20/), [generated operation files](../tests/ops/), [mutant copies](../tests/mutants/),
  [scratch testcases](../tests/legacy_tb/), [review reproduction testcases](../tests/review_2026-11-22/).
- [Reference models](../models/reference_models/), [testbenches and BFMs](../env/tb/), [formal harnesses](../env/formal/),
  [runners and static checks](../env/scripts/), [build table](../env/env/builds.json), [simulation output](../sim/).

## Layout (2026-11-24) / Bố cục

Every folder is at most two levels below `verification/`; the folder paths are defined once in `env/scripts/vpaths.py`.

| Folder | Content |
|---|---|
| `env/tb/` | `tb_usb2_utmi_axim.sv` (generic harness), generated variants `tb_usb2_ulpi_axim.sv`, `tb_usb2_axis.sv`, `tb_usb2_ulpi_axis.sv`, `ulpi_phy_bfm.sv`, `tb_xreg.sv` and `filelist_xreg.f`, `tb_cfgchk.sv`; the `*_deep.tar` files are the bundles of the reorganization (history) |
| `env/formal/` | `fml_crc`, `fml_fifo`, `fml_ocp_irq` harnesses (`.sby`, `.sv`) |
| `env/env/builds.json` | every simulation build: top, filelist (`rtl/filelist.f`), extra files, parameters |
| `env/scripts/` | `build.py`, `rebuild_all.py`, `run.py`, `regress.py`, `mutate.py`, `run_builds.py`, `run_coverage.py`, `update_vplan.py`, `make_report.py`, TB generators, static checks `check_*.py` |
| `tests/usb20/` | `gen_*.py`, `usb2lib.py`, `devlib.py`, `hostlib.py`, `testlist.csv` |
| `tests/ops/`, `tests/mutants/` | generated operation files; mutated RTL copies `<id>__<file>` |
| `sim/` | run folders `r<NNNN>_<name>/` (no subfolder; inputs as `in__*`), builds `build_<name>/`, `index.csv`, `coverage/`, `coverage_<kind>/`, regression logs, `legacy_*.tar` (archived runs and builds before 2026-11-24) |

## Commands / Lệnh chạy

All commands run from the `verification` folder. / Mọi lệnh chạy từ thư mục `verification`.

```sh
python env/scripts/rebuild_all.py [name ...]                      # regenerate the derived testbenches, rebuild the builds of env/env/builds.json
python env/scripts/build.py <name> [--rebuild]                    # one build of builds.json into sim/build_<name>/
python env/scripts/run.py sim <test> <build> tests/ops/<file>.ops # one simulation run
python env/scripts/run.py formal <test> - <file.sby> [task ...]   # one formal run (harness in env/formal)
python env/scripts/run.py static <test> <check_*.py>              # one static check
python env/scripts/regress.py [smoke|nightly|full] [test ...]     # tests/usb20/testlist.csv; rows of tier "open" only by name
python env/scripts/mutate.py [M01 ...]                            # bug-library mutation check -> sim/coverage/mutation_report.md
python env/scripts/run_builds.py                                  # t_dir_param_builds: elaboration of the parameter configurations
python env/scripts/run_coverage.py                                # code coverage -> sim/coverage/code_coverage_*.txt
python env/scripts/update_vplan.py --since rNNNN                  # status and evidence columns of plan_vplan.csv
python env/scripts/make_report.py --since rNNNN                   # verification_report.md
```

Generators: `cd tests/usb20 && python gen_<name>.py <seed> [args]` writes `tests/ops/<name>_s<seed>.ops`.

Notes:
- `rtl/filelist.f` lists the FIFO RAM cell `000_Common/rtl_cells/VLSIT_CELL_SRAM_1W1R.sv` (added 2026-11-24); the fault build
  replaces it with `models/reference_models/sram_fault.sv` (`exclude` and `extra` in `builds.json`).
- The runs before 2026-11-24 (r0001 to r2327) are in `sim/legacy_sim_runs.tar`; `sim/index.csv` keeps their list, so new run numbers
  continue after them. Reports made with `--since` an older run need those folders restored from the archive.
- Scratch benches from RTL development: `sh env/build_legacy.sh` and `sh env/run_legacy.sh` (no evidence for the plan).
- [Historical simulation guide](sim_README.md) (status, prerequisites, resource budget; its command list is superseded by the table above).

Các lệnh trên chạy từ thư mục `verification`. Đường dẫn các thư mục được định nghĩa một lần trong `env/scripts/vpaths.py`; mọi thư mục
nằm trong giới hạn hai cấp. Run trước 2026-11-24 nằm trong `sim/legacy_sim_runs.tar`, danh sách vẫn ở `sim/index.csv`.
