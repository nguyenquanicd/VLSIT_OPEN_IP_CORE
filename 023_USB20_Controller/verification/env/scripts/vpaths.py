"""Single definition of the folders of the verification package after the reorganization of 2026-11-24 (IP README: verification/
has exactly docs, tests, models, env, sim, at most two directory levels below it, docs flat). Every script imports this module;
all commands run from the verification folder:  python env/scripts/<script>.py ...

  env/scripts/      runners, generators of the environment, static checks          (SCRIPTS)
  env/tb/           testbenches and BFMs, flat; filelists here list paths relative to rtl/ (TB)
  env/formal/       formal harnesses (.sby, .sv), flat                              (FORMAL)
  env/env/          resource budget, build table builds.json, replay records       (ENVCFG)
  tests/usb20/      scenario generators and their libraries, testlist.csv          (TESTS)
  tests/ops/        generated operation files                                       (OPS)
  tests/mutants/    mutated RTL copies, flat: <id>__<file>                          (MUTANTS)
  models/reference_models/  independent models (CRC model, RAM fault model)         (MODELS)
  sim/              run folders r<NNNN>_<name>/ (flat), build_<name>/, index.csv, coverage/, coverage_<kind>/
  docs/             plan, vplan, bugs, report, review records (flat)                (DOCS)
"""
import os

V = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
IP = os.path.normpath(os.path.join(V, '..'))
LIBROOT = os.path.normpath(os.path.join(IP, '..'))
RTL = os.path.join(IP, 'rtl')
FILELIST = os.path.join(RTL, 'filelist.f')
SCRIPTS = os.path.join(V, 'env', 'scripts')
TB = os.path.join(V, 'env', 'tb')
FORMAL = os.path.join(V, 'env', 'formal')
ENVCFG = os.path.join(V, 'env', 'env')
BUILDS_JSON = os.path.join(ENVCFG, 'builds.json')
TESTS = os.path.join(V, 'tests', 'usb20')
TESTLIST = os.path.join(TESTS, 'testlist.csv')
OPS = os.path.join(V, 'tests', 'ops')
MUTANTS = os.path.join(V, 'tests', 'mutants')
MODELS = os.path.join(V, 'models', 'reference_models')
SIMOUT = os.path.join(V, 'sim')
INDEX = os.path.join(SIMOUT, 'index.csv')
COV = os.path.join(SIMOUT, 'coverage')
DOCS = os.path.join(V, 'docs')
VPLAN = os.path.join(DOCS, 'plan_vplan.csv')
PLAN_MD = os.path.join(DOCS, 'plan_verification_plan.md')
BUGS = os.path.join(DOCS, 'bugs.md')
REPORT = os.path.join(DOCS, 'verification_report.md')
CSR_JSON = os.path.join(IP, 'spec', 'csr', 'regs_usb2.json')


def run_dir(rid):
    return os.path.join(SIMOUT, rid)


def build_dir(name):
    return os.path.join(SIMOUT, 'build_' + name)


def rel(p):
    """Path relative to the verification folder with forward slashes (for records)."""
    return os.path.relpath(p, V).replace(chr(92), '/')
