"""Full regression of the digital signature IP on the current RTL: every test of verification/ in one run, logs at fixed
places, then the requirement coverage matrix (docs/COVERAGE_MATRIX.md) from those logs.

Waves (at most about 12 simulator processes at a time):
  1  phase 1 (CSR, control block, buffer; three builds), hash stack, AXI4, key and random, Hash_DRBG, parameter elaboration
  2  elliptic-curve engine: all sets (with +CT for the constant-time set), then the blinded build
  3  lattice engine (ML-DSA, HashML-DSA), hash-based engine (SLH-DSA, LMS, XMSS, HashSLH-DSA)
  4  top tests
Usage: python regress_all.py [wave ...]   (default: 1 2 3 4)"""
import os
import subprocess
import sys
import time

V = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).replace(chr(92), '/')
S = V + '/sim'
PY = sys.executable
ENV0 = dict(os.environ)


def job(name, cmd, env=None):
    e = dict(ENV0)
    e.update(env or {})
    log = open('%s/final_%s.txt' % (S, name), 'w')
    return name, subprocess.Popen(cmd, cwd=V, env=e, stdout=log, stderr=subprocess.STDOUT), log, time.time()


def wait(jobs):
    rc = 0
    for name, p, log, t0 in jobs:
        r = p.wait()
        log.close()
        rc |= r
        print('%-14s exit %d  %4.0f s' % (name, r, time.time() - t0), flush=True)
    return rc


def wave1():
    ivl = dict(PATH='C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib;' + ENV0.get('PATH', ''), TMP='C:/tmp_ivl', TEMP='C:/tmp_ivl')
    os.makedirs('C:/tmp_ivl', exist_ok=True)
    subprocess.run([PY, V + '/models/hash/gen_hfeed_vec.py', S + '/hfeed_final.txt'], check=True)
    subprocess.run([PY, V + '/models/hash/gen_hseq_vec.py', S + '/hseq_final.txt'], check=True)
    subprocess.run([PY, V + '/models/rng/gen_drbg_vec.py', S + '/drbg_vec.txt'], check=True)
    jobs = [job('p1', [PY, 'env/dsig_p1/run_regress.py', '--n', '200', '--seeds', '1,2,3'], ivl),
            job('hfeed', [PY, 'env/misc/run_unit.py', 'hfeed', '+VEC=' + S + '/hfeed_final.txt'], {'UNIT_TAG': '_final'}),
            job('hseq', [PY, 'env/misc/run_unit.py', 'hseq', '+VEC=' + S + '/hseq_final.txt'], {'UNIT_TAG': '_final'}),
            job('axi', [PY, 'env/misc/run_unit.py', 'axi'], {'UNIT_TAG': '_final'}),
            job('key_rng', [PY, 'env/misc/run_unit.py', 'key_rng'], {'UNIT_TAG': '_final'}),
            job('rng_drbg', [PY, 'env/misc/run_unit.py', 'rng_drbg', '+VEC=' + S + '/drbg_vec.txt'], {'UNIT_TAG': '_final'}),
            job('rng_katfail', [PY, 'env/misc/run_unit.py', 'rng_drbg', '+VEC=' + S + '/drbg_vec.txt', '+KATFAIL'], {'UNIT_TAG': '_katfail'}),
            job('formal', [PY, 'env/misc/run_formal.py']),
            job('sdc', [PY, 'env/misc/check_sdc.py']),
            job('params', [PY, 'env/misc/run_params.py'])]
    subprocess.run([PY, V + '/models/ec/gen_mmul_vec.py', S + '/mmul_vec.txt'], check=True)
    jobs += [job('mmul%d' % w, [PY, 'env/misc/run_unit.py', 'mmul', '+VEC=' + S + '/mmul_vec.txt'],
                 {'UNIT_TAG': '_w%d' % w, 'UNIT_DEFS': '-DTB_W=%d' % w}) for w in (32, 64, 128)]
    return wait(jobs)


def wave2():
    rc = wait([job('ec', [PY, 'env/ec/run_ec.py', 'ed25519', 'ed448', 'edvar', 'det', 'ct', 'p256', 'p384', 'p521', 'k256', 'sha3', 'p384full',
                    'p521full'], {'EC_TAG': 'ec_final'})])
    rc |= wait([job('ec_dpa', [PY, 'env/ec/run_ec.py', 'ct', 'det', 'ed25519', 'ed448', 'p256', 'k256'],
                    {'EC_TAG': 'ec_final_dpa', 'EC_DPA': '1'})])
    return rc


def wave3():
    return wait([job('lat', [PY, 'env/lat/run_lat.py', 'all', 'prehash'], {'UNIT_TAG': '_final'}),
                 job('hbs', [PY, 'env/hbs/run_hbs.py', 'slh', 'lms', 'xmss', 'prehash', 'rfc8554'], {'UNIT_TAG': '_final'}),
                 job('lat_dpa', [PY, 'env/lat/run_lat.py', 'all', 'prehash'], {'UNIT_TAG': '_dpa', 'LAT_SET_TAG': '_dpa', 'UNIT_DEFS': '-DTB_DPA=1'})])


def wave4():
    t = 'env/misc/run_unit.py'
    jobs = [('top_ec_quick', [PY, t, 'top_ec', '+VEC=' + S + '/quick.hex', '+NVEC=10'], {'UNIT_TAG': '_fq'}),
            ('top_ec_edvar', [PY, t, 'top_ec', '+VEC=' + S + '/top_edvar.hex', '+NVEC=68'], {'UNIT_TAG': '_fe'}),
            ('top_ec_det', [PY, t, 'top_ec', '+VEC=' + S + '/det.hex', '+NVEC=26'],
                {'UNIT_TAG': '_fd', 'UNIT_DEFS': '-DTB_RNG_SRC=1 -DTB_DPA_EC=1'}),
            ('top_ec_dpa_ed', [PY, t, 'top_ec', '+VEC=' + S + '/top_edvar.hex', '+NVEC=20'],
                {'UNIT_TAG': '_fde', 'UNIT_DEFS': '-DTB_RNG_SRC=1 -DTB_DPA_EC=1'}),
            ('top_pq_lat', [PY, t, 'top_pq', '+DIR=' + S + '/lat_all', '+KIND=lat', '+NVEC=25'], {'UNIT_TAG': '_fl'}),
            ('top_pq_latpre', [PY, t, 'top_pq', '+DIR=' + S + '/lat_prehash', '+KIND=lat', '+NVEC=16'], {'UNIT_TAG': '_flp'}),
            ('top_pq_hbs', [PY, t, 'top_pq', '+DIR=' + S + '/hbs_quick', '+KIND=hbs', '+NVEC=19'], {'UNIT_TAG': '_fh'}),
            ('top_pq_hbspre', [PY, t, 'top_pq', '+DIR=' + S + '/hbs_prehash', '+KIND=hbs', '+NVEC=12'], {'UNIT_TAG': '_fhp'}),
            ('top_pq_lat_dpa', [PY, t, 'top_pq', '+DIR=' + S + '/lat_all', '+KIND=lat', '+NVEC=25'],
             {'UNIT_TAG': '_fld', 'UNIT_DEFS': '-DTB_DPA_PQ=1'}),
            ('top_err', [PY, t, 'top_err'], {'UNIT_TAG': '_fr'}),
            ('top_sys', [PY, t, 'top_sys', '+DIR=' + S + '/sys'], {'UNIT_TAG': '_fs'})]
    rc = 0
    for i in range(0, len(jobs), 3):      # 10 top builds at once ran out of memory: batches of 3
        rc |= wait([job(*j) for j in jobs[i:i + 3]])
    return rc


def main(waves):
    subprocess.run([PY, V + '/models/ec/gen_ec_vec.py', 'quick', S + '/quick.hex', S + '/quick.txt'], check=True)
    subprocess.run([PY, V + '/models/ec/gen_ec_vec.py', 'edvar', S + '/top_edvar.hex', S + '/top_edvar.txt'], check=True)
    subprocess.run([PY, V + '/models/ec/gen_ec_vec.py', 'det', S + '/det.hex', S + '/det.txt'], check=True)
    subprocess.run([PY, V + '/models/top/gen_sys_vec.py', S + '/sys'], check=True)
    subprocess.run([PY, V + '/models/hbs/gen_hbs_vec.py', S + '/hbs_quick', 'quick'], check=True)
    rc = 0
    for w in waves:
        print('wave', w, flush=True)
        rc |= {'1': wave1, '2': wave2, '3': wave3, '4': wave4}[w]()
    subprocess.run([PY, V + '/env/misc/coverage_matrix.py'])
    print('RESULT: %s' % ('all jobs exited 0' if rc == 0 else 'some jobs failed; see the matrix and the logs'))
    return rc


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:] or ['1', '2', '3', '4']))
