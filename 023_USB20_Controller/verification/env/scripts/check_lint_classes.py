"""a_lint_classes (2026-11-24): Verilator lint (-Wall) of rtl/filelist.f for each of the four wrapper tops; FAIL when a warning of a
class that is a design defect under the VLSIT RTL rules appears: MULTIDRIVEN (a variable written by more than one process, e.g.
two always_ff blocks: not synthesizable as one register), LATCH / NOLATCH (latch inferred in always_comb), COMBDLY (blocking
delay in combinational logic), BLKANDNBLK (blocking and nonblocking writes of one variable). Every other warning class is only
counted (the full list stays in the lint logs). Found the multi-driven reg_tok_efld of m_usb2_lnkrx (fixed 2026-11-24), which was
hidden among about 340 warnings of the plain lint runs.
    python env/scripts/check_lint_classes.py        exit 0 = none of the defect classes in any top"""
import collections
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402

DEFECT = ('MULTIDRIVEN', 'LATCH', 'NOLATCH', 'COMBDLY', 'BLKANDNBLK')
TOPS = ['m_usb2_top_utmi_axim', 'm_usb2_top_utmi_axis', 'm_usb2_top_ulpi_axim', 'm_usb2_top_ulpi_axis']
VL = 'C:/Tools/oss-cad-suite/bin/verilator_bin.exe'


def main():
    files = [ln.strip() for ln in open(P.FILELIST) if ln.strip() and not ln.strip().startswith(('#', '//'))]
    env = dict(os.environ)
    env['PATH'] = 'C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib;' + env['PATH']
    env['VERILATOR_ROOT'] = 'C:/Tools/oss-cad-suite/share/verilator'
    bad = 0
    for top in TOPS:
        r = subprocess.run([VL, '--lint-only', '-Wall', '-Wno-fatal', '-Werror-USERERROR', '-Werror-USERFATAL', '--top-module', top] + files, cwd=P.RTL, capture_output=True, text=True, env=env)
        out = r.stdout + r.stderr
        cls = collections.Counter(re.findall(r'%Warning-(\w+):', out))
        errs = len(re.findall(r'^%Error', out, re.M))
        hits = [ln for ln in out.split('\n') if re.match('%Warning-(' + '|'.join(DEFECT) + '):', ln)]
        for h in hits:
            print('VIOLATION %s: %s' % (top, h[:200]))
        bad += len(hits) + errs
        print('%s: errors %d, defect-class warnings %d, other warnings %d (%s)' % (
            top, errs, len(hits), sum(v for k, v in cls.items() if k not in DEFECT),
            ', '.join('%s %d' % kv for kv in cls.most_common(6) if kv[0] not in DEFECT)))
    print('tops: %d, violations: %d' % (len(TOPS), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
