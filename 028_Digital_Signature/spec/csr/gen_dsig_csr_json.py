import json

OUT = r'C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\028_Digital_Signature\spec\csr\dsig_regs.json'

ALGS = ['ed25519', 'ed25519ctx', 'ed25519ph', 'ed448', 'ed448ph', 'p256', 'p384', 'p521', 'k256',
        'mldsa44', 'mldsa65', 'mldsa87', 'slhdsa', 'lms', 'xmss']
ALGN = ['Ed25519', 'Ed25519ctx', 'Ed25519ph', 'Ed448', 'Ed448ph', 'ECDSA P-256', 'ECDSA P-384', 'ECDSA P-521',
        'ECDSA secp256k1', 'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'SLH-DSA', 'LMS/HSS', 'XMSS/XMSS^MT']


def D(title, expl, usage, values, unit='none', limits='none'):
    vs = values if isinstance(values, list) else [values]
    lines = []
    for i, v in enumerate(vs):
        lines.append(v + (';' if i < len(vs) - 1 else '.'))
    return (title + '. ' + expl + '\n\nUsage: ' + usage + '\n\nValues:\n' + '\n'.join(lines) +
            '\n\nUnit: ' + unit + '\n\nLimits: ' + limits)


def F(name, bits, typ, reset, desc):
    return {'name': name, 'bits': bits, 'type': typ, 'reset': reset, 'description': desc}


def R(name, off, desc, fields):
    return {'name': name, 'offset': off, 'description': desc, 'fields': fields}


def RES(bits):
    return {'name': 'reserved', 'bits': bits, 'type': 'ro', 'reset': '0x0', 'description': ''}


def per_alg(kind):
    out = []
    for i, (a, n) in enumerate(zip(ALGS, ALGN)):
        if kind == 'cap_alg':
            d = D(n + ' built flag', 'Reports whether the hardware of ' + n + ' exists in this build of the IP.',
                  'Read after reset to learn which algorithms the build offers, before software sets the matching bit of the algorithm enable register.',
                  ['0x0 not built', '0x1 built'], 'none',
                  'Follows the build parameter of the algorithm; the value is constant after reset.')
            t = 'ro'
        elif kind in ('cap_kgen', 'cap_sign', 'cap_vrfy'):
            op = {'cap_kgen': 'key generation', 'cap_sign': 'signing', 'cap_vrfy': 'verification'}[kind]
            d = D(n + ' ' + op + ' built flag', 'Reports whether the ' + op + ' path of ' + n + ' exists in this build of the IP.',
                  'Read before issuing a start command for this operation; a command for an operation that is not built sets the unsupported-operation error.',
                  ['0x0 not built', '0x1 built'], 'none',
                  'Constant after reset; always 0 when the algorithm itself is not built.')
            t = 'ro'
        elif kind == 'alg_en':
            d = D(n + ' run-time enable', 'Allows software to start operations of ' + n + ' when the algorithm is built.',
                  'Write 1 before the start command of this algorithm; the bit has no effect while the algorithm enable lock is set; a start command while the effective bit is 0 sets the algorithm-disabled error.',
                  ['0x0 disabled (reset value)', '0x1 enabled'], 'none',
                  'The bit is ignored and reads 0 for an algorithm that is not built.')
            t = 'rw'
        else:
            d = D(n + ' effective enable', 'Reports the enable state that the control block actually uses for ' + n + '.',
                  'Read to confirm that an enable written by software took effect; after the algorithm enable lock is set it keeps the value held at lock time.',
                  ['0x0 disabled', '0x1 enabled'], 'none', 'Reads 0 for an algorithm that is not built.')
            t = 'ro'
        out.append(F(a, '[%d]' % i, t, '0x0', d))
    out.append(RES('[31:15]'))
    return out


def irq_fields(kind):
    names = [('done', 'Operation done', 'an operation that was started by the start command finished, with or without an error'),
             ('err', 'Error', 'an operation or a command was rejected, or an error flag of the error register was set'),
             ('sec', 'Security event', 'a fault was detected by verify-after-sign, an enable write was refused while locked, or the random source failed')]
    f = []
    for i, (n, t, c) in enumerate(names):
        if kind == 'raw':
            d = D(t + ' raw event', 'Sticky flag that the hardware sets when ' + c + '.',
                  'Read the status register for the masked value; write 1 to this bit to clear the event after handling it.',
                  ['0x0 no event (reset value)', '0x1 event pending'], 'none', 'A write of 0 keeps the bit; a hardware set in the same cycle as a clear wins.')
            typ = 'w1c'
        elif kind == 'en':
            d = D(t + ' interrupt enable', 'Allows the raw event to drive the interrupt output.',
                  'Write 1 before waiting for the interrupt; clearing it hides the event from the status register and the output.',
                  ['0x0 masked (reset value)', '0x1 enabled'], 'none', 'none')
            typ = 'rw'
        elif kind == 'inj':
            d = D(t + ' interrupt injection', 'Test bit that makes the IP raise the raw event as if it had occurred.',
                  'Write 1 to test the interrupt path; the IP raises the raw event on the rising edge of this bit; write 0 and 1 again to inject another event.',
                  ['0x0 no injection (reset value)', '0x1 inject event'], 'none', 'Use only in test; it does not start any operation.')
            typ = 'rw'
        else:
            d = D(t + ' masked status', 'Raw event ANDed with its interrupt enable; this is the value that drives the interrupt output.',
                  'Read in the interrupt service routine to find the cause; clear the cause through the raw register.',
                  ['0x0 not pending', '0x1 pending'], 'none', 'Read-only; follows the raw and enable bits.')
            typ = 'ro'
        f.append(F(n, '[%d]' % i, typ, '0x0', d))
    f.append(RES('[31:3]'))
    return f


regs = []
regs.append(R('dsig_version', '0x0', 'Digital signature version register. Reports the IP major and minor version numbers.', [
    F('major', '[31:16]', 'ro', '0x1', 'Major version number of the IP. Software reads it to select compatible driver behavior.\n\nUsage: Read after reset and before any other register.\n\nValues:\n0x1 major version 1 (reset value).\n\nUnit: none\n\nLimits: none'),
    F('minor', '[15:0]', 'ro', '0x0', 'Minor version number of the IP. Software reads it to identify compatible additions.\n\nUsage: Read after reset and before any other register.\n\nValues:\n0x0 minor version 0 (reset value).\n\nUnit: none\n\nLimits: none')]))

regs.append(R('dsig_cap_alg', '0x4', 'Digital signature algorithm capability register. Reports which algorithms are built.', per_alg('cap_alg')))
regs.append(R('dsig_cap_kgen', '0x8', 'Digital signature key generation capability register. Reports which algorithms have key generation built.', per_alg('cap_kgen')))
regs.append(R('dsig_cap_sign', '0xC', 'Digital signature signing capability register. Reports which algorithms have signing built.', per_alg('cap_sign')))
regs.append(R('dsig_cap_vrfy', '0x10', 'Digital signature verification capability register. Reports which algorithms have verification built.', per_alg('cap_vrfy')))

regs.append(R('dsig_cap_slh', '0x14', 'Digital signature SLH-DSA set capability register. Reports which SLH-DSA parameter sets are built.', [
    F('sets', '[11:0]', 'ro', '0x0', D('SLH-DSA built set mask', 'Bit n is 1 when SLH-DSA parameter set number n of the table in section 10 is built.',
        'Read before programming the SLH-DSA set field of the set register.', '0x0 to 0xFFF mask of built sets', 'none',
        'Constant after reset; 0 when SLH-DSA is not built.')),
    RES('[31:12]')]))
regs.append(R('dsig_cap_lms', '0x18', 'Digital signature LMS capability register. Reports which LMS tree types are built.', [
    F('lms', '[19:0]', 'ro', '0x0', D('LMS built type mask', 'Bit n is 1 when LMS tree type number n of the table in section 10 is built.',
        'Read before programming the LMS type field of the set register.', '0x00000 to 0xFFFFF mask of built LMS types', 'none', 'Constant after reset; 0 when LMS is not built.')),
    RES('[31:20]')]))
regs.append(R('dsig_cap_lmots', '0x2C', 'Digital signature LM-OTS capability register. Reports which LM-OTS types are built.', [
    F('lmots', '[15:0]', 'ro', '0x0', D('LM-OTS built type mask', 'Bit n is 1 when LM-OTS type number n of the table in section 10 is built.',
        'Read before programming the LM-OTS type field of the set register.', '0x0000 to 0xFFFF mask of built LM-OTS types', 'none', 'Constant after reset; 0 when LMS is not built.')),
    RES('[31:16]')]))
regs.append(R('dsig_cap_xmss', '0x1C', 'Digital signature XMSS capability low register. Reports which XMSS and XMSS^MT sets 0 to 31 are built.', [
    F('sets', '[31:0]', 'ro', '0x0', D('XMSS built set mask, low part', 'Bit n is 1 when XMSS or XMSS^MT set number n of the table in section 10 is built, for n from 0 to 31.',
        'Read before programming the XMSS set field of the set register.', '0x0 to 0xFFFFFFFF mask of built sets', 'none', 'Constant after reset; 0 when XMSS is not built.'))]))
regs.append(R('dsig_cap_xmssh', '0x20', 'Digital signature XMSS capability high register. Reports which XMSS and XMSS^MT sets 32 to 43 are built.', [
    F('sets', '[11:0]', 'ro', '0x0', D('XMSS built set mask, high part', 'Bit n is 1 when XMSS or XMSS^MT set number 32 plus n of the table in section 10 is built.',
        'Read together with the low capability register.', '0x0 to 0xFFF mask of built sets', 'none', 'Constant after reset; 0 when XMSS is not built.')),
    RES('[31:12]')]))

feat = [('pure', 'Pure message form'), ('prehash', 'Prehash message form'), ('axi', 'AXI4 subordinate port'), ('dma', 'DMA request and acknowledge lines'),
        ('win', 'CSR data window'), ('keyif', 'Key input port'), ('keyreg', 'Write-only key registers'), ('vas', 'Verify-after-sign'),
        ('dpa_ec', 'Elliptic-curve masking'), ('dpa_pq', 'Lattice and hash-based masking'), ('hybrid', 'Hybrid verification'), ('log', 'Counters and lock log'),
        ('lock', 'Algorithm enable lock'), ('rngsrc', 'Internal random generator'), ('csrasync', 'Asynchronous CSR clock')]
ff = []
for i, (n, t) in enumerate(feat):
    ff.append(F(n, '[%d]' % i, 'ro', '0x0', D(t + ' built flag', 'Reports whether the optional feature "' + t + '" is built in this IP.',
        'Read after reset to learn which optional features the build offers.', ['0x0 not built', '0x1 built'], 'none', 'Constant after reset.')))
ff.append(RES('[31:15]'))
regs.append(R('dsig_cap_feat', '0x24', 'Digital signature feature capability register. Reports which optional features are built.', ff))
regs.append(R('dsig_cap_buf', '0x28', 'Digital signature buffer capability register. Reports the message buffer size and the multiplier width code.', [
    F('buf', '[16:0]', 'ro', '0x0', D('Buffer size in bytes', 'Size of the message, signature and public-key buffer that the AXI4 port and the data window address.',
        'Read before sizing the offsets of the message, signature and public key.', '0x0 to 0x10000 buffer size', 'byte', 'Constant after reset; the maximum is 65536.')),
    RES('[19:17]'),
    F('mulw', '[21:20]', 'ro', '0x0', D('Multiplier width code', 'Digit width of the field multiplier that the build uses.',
        'Read to estimate the duration of an operation.', ['0x0 32 bits', '0x1 64 bits', '0x2 128 bits'], 'code', 'Constant after reset; the code 0x3 is not used.')),
    RES('[31:22]')]))

regs.append(R('dsig_ctrl', '0x40', 'Digital signature control register. Enables the IP and selects basic operation.', [
    F('en', '[0]', 'rw', '0x0', D('IP enable', 'Master enable of the IP; when 0 the control block starts no operation and rejects commands.',
        'Write 1 after the algorithm enable bits and the operation fields are programmed; clearing it while an operation runs lets that operation finish.',
        ['0x0 disabled (reset value)', '0x1 enabled'])),
    RES('[31:1]')]))
regs.append(R('dsig_alg_en', '0x44', 'Digital signature algorithm enable register. Enables each built algorithm at run time.', per_alg('alg_en')))
regs.append(R('dsig_alg_act', '0x48', 'Digital signature effective algorithm enable register. Reports the enable state in use.', per_alg('alg_act')))
regs.append(R('dsig_lock', '0x4C', 'Digital signature lock register. Freezes the algorithm enable bits until the next reset.', [
    F('req', '[0]', 'wo', '0x0', D('Lock request', 'Command that freezes the algorithm enable bits at their current effective value until the next reset of the core.',
        'Write 1 once, after the algorithm enable register is final; hardware latches the lock and clears this bit; it reads as 0.',
        ['0x0 no request (reset value)', '0x1 request the lock'], 'none',
        'Has no effect when the lock feature is not built; a write of 0 never removes the lock.')),
    RES('[7:1]'),
    F('locked', '[8]', 'ro', '0x0', D('Lock state', 'Reports whether the algorithm enable bits are frozen.',
        'Read after writing the lock request to confirm the lock.', ['0x0 not locked (reset value)', '0x1 locked'], 'none',
        'Cleared only by a reset of the core.')),
    RES('[31:9]')]))

regs.append(R('dsig_op', '0x50', 'Digital signature operation register. Selects the algorithm, the operation and the modes of the next start command.', [
    F('alg', '[3:0]', 'rw', '0x0', D('Algorithm index', 'Selects the algorithm that the next start command runs.',
        'Program before the start command; the index is checked against the algorithm built flag and the effective enable bit.',
        ['0x0 Ed25519;', '0x1 Ed25519ctx;', '0x2 Ed25519ph;', '0x3 Ed448;', '0x4 Ed448ph;', '0x5 ECDSA P-256;', '0x6 ECDSA P-384;', '0x7 ECDSA P-521;',
         '0x8 ECDSA secp256k1;', '0x9 ML-DSA-44;', '0xA ML-DSA-65;', '0xB ML-DSA-87;', '0xC SLH-DSA;', '0xD LMS/HSS;', '0xE XMSS/XMSS^MT (0x0 reset value)'][:0] or
        ['0x0 Ed25519 (reset value)', '0x1 Ed25519ctx', '0x2 Ed25519ph', '0x3 Ed448', '0x4 Ed448ph', '0x5 ECDSA P-256', '0x6 ECDSA P-384', '0x7 ECDSA P-521',
         '0x8 ECDSA secp256k1', '0x9 ML-DSA-44', '0xA ML-DSA-65', '0xB ML-DSA-87', '0xC SLH-DSA', '0xD LMS/HSS', '0xE XMSS/XMSS^MT'],
        'code', 'The code 0xF is reserved; a reserved or not built code sets the unsupported-operation error.')),
    RES('[7:4]'),
    F('op', '[9:8]', 'rw', '0x2', D('Operation select', 'Selects key generation, signing or verification for the next start command.',
        'Program before the start command; the operation must be built for the selected algorithm.',
        ['0x0 key generation', '0x1 signing', '0x2 verification (reset value)', '0x3 reserved'], 'code',
        'SLH-DSA, LMS/HSS and XMSS/XMSS^MT accept only verification in this version.')),
    RES('[11:10]'),
    F('form', '[13:12]', 'rw', '0x0', D('Message form', 'Selects whether the message is in the buffer (pure) or only its digest is supplied (prehash).',
        'Program before the start command; the form must be built.',
        ['0x0 pure message (reset value)', '0x1 prehash digest', '0x2 and 0x3 reserved'], 'code',
        'The reserved codes set the unsupported-operation error.')),
    RES('[15:14]'),
    F('hedged', '[16]', 'rw', '0x0', D('Hedged signing', 'Selects the hedged form of ML-DSA signing, which adds random bytes, instead of the deterministic form.',
        'Program before a signing start command of ML-DSA; ignored for other algorithms.',
        ['0x0 deterministic (reset value)', '0x1 hedged'])),
    RES('[19:17]'),
    F('nonce', '[21:20]', 'rw', '0x0', D('ECDSA nonce mode', 'Selects the source of the ECDSA per-message secret number when the build allows both.',
        'Program before a signing start command of ECDSA; effective only when the nonce parameter of the build is 2.',
        ['0x0 random from the random source (reset value)', '0x1 deterministic as in RFC 6979', '0x2 and 0x3 reserved'], 'code',
        'Ignored when the build fixes the nonce mode; the reserved codes set the unsupported-operation error.')),
    RES('[23:22]'),
    F('hash', '[26:24]', 'rw', '0x0', D('Hash function select', 'Selects the hash function of ECDSA and of every prehash digest.',
        'Program before the start command of ECDSA or a prehash form; the digest length must fit the curve security.',
        ['0x0 SHA-256 (reset value)', '0x1 SHA-384', '0x2 SHA-512', '0x3 SHA3-256', '0x4 SHA3-384', '0x5 SHA3-512', '0x6 and 0x7 reserved'], 'code',
        'A pairing of curve and hash that gives less security than the curve is rejected with the bad-length error.')),
    RES('[27]'),
    F('hybpol', '[29:28]', 'rw', '0x0', D('Hybrid acceptance policy', 'Selects which signatures must be valid for the hybrid verification to accept.',
        'Program before a hybrid start command; used only when the hybrid feature is built.',
        ['0x0 Ed25519 and ML-DSA both valid (reset value)', '0x1 Ed25519 valid', '0x2 ML-DSA valid', '0x3 reserved'], 'code',
        'The reserved code sets the unsupported-operation error.')),
    RES('[31:30]')]))

regs.append(R('dsig_set', '0x54', 'Digital signature parameter-set register. Selects the SLH-DSA, LMS/HSS and XMSS parameter sets.', [
    F('slh', '[3:0]', 'rw', '0x0', D('SLH-DSA parameter set', 'Selects one of the 12 parameter sets of FIPS 205 for SLH-DSA verification.',
        'Program before a start command of SLH-DSA; the matching bit of the SLH-DSA capability register must be 1.',
        ['0x0 to 0xB set number from the table in section 10 (reset value 0x0)', '0xC to 0xF reserved'], 'code',
        'A set that is not built or reserved sets the unsupported-operation error.')),
    RES('[7:4]'),
    F('lmstype', '[12:8]', 'rw', '0x0', D('LMS tree type', 'Selects the LMS tree type of the signature.',
        'Program before a start command of LMS/HSS; the matching bit of the LMS capability register must be 1.',
        ['0x00 to 0x13 type number from the table in section 10 (reset value 0x00)', '0x14 to 0x1F reserved'], 'code',
        'A type that is not built sets the unsupported-operation error.')),
    RES('[15:13]'),
    F('lmots', '[19:16]', 'rw', '0x0', D('LM-OTS type', 'Selects the one-time signature type of the LMS signature.',
        'Program before a start command of LMS/HSS.',
        '0x0 to 0xF type number from the table in section 10 (reset value 0x0)', 'code', 'A type that is not built sets the unsupported-operation error.')),
    F('hsslvl', '[23:20]', 'rw', '0x1', D('HSS level count', 'Number of LMS trees in the HSS hierarchy of the signature.',
        'Program before a start command of LMS/HSS.',
        ['0x1 to 0x8 level count (reset value 0x1)', '0x0 and 0x9 to 0xF reserved'], 'count', 'A level count outside 1 to 8 sets the bad-length error.')),
    F('xmss', '[29:24]', 'rw', '0x0', D('XMSS set', 'Selects the XMSS or XMSS^MT parameter set of the signature.',
        'Program before a start command of XMSS/XMSS^MT; the matching bit of the XMSS capability registers must be 1.',
        ['0x00 to 0x2B set number from the table in section 10 (reset value 0x00)', '0x2C to 0x3F reserved'], 'code',
        'A set that is not built sets the unsupported-operation error.')),
    RES('[31:30]')]))

regs.append(R('dsig_len_msg', '0x58', 'Digital signature message length register. Gives the message length in bytes.', [
    F('len', '[31:0]', 'rw', '0x0', D('Message length', 'Number of message bytes in the buffer for the pure form, or the digest length for the prehash form.',
        'Program before the start command, after the data are written.', '0x0 to 0xFFFFFFFF length (reset value 0x0)', 'byte',
        'The length must fit the buffer at the message offset; a longer value sets the buffer-overflow error.'))]))
regs.append(R('dsig_len_ctx', '0x5C', 'Digital signature context length register. Gives the context length in bytes.', [
    F('len', '[7:0]', 'rw', '0x0', D('Context length', 'Number of context bytes that follow the message in the buffer for Ed25519ctx, Ed25519ph, Ed448, Ed448ph, ML-DSA and SLH-DSA.',
        'Program before the start command of an algorithm that uses a context; ignored by the other algorithms.', '0x00 to 0xFF length (reset value 0x00)', 'byte',
        'A length above the limit of the algorithm sets the bad-length error.')),
    RES('[31:8]')]))

for nm, off, t, e in [('msg', '0x60', 'Message', 'message or digest'), ('sig', '0x64', 'Signature', 'signature'),
                      ('pk', '0x68', 'Public key', 'public key'), ('res', '0x6C', 'Result', 'result (signature, public key or key-generation output)')]:
    regs.append(R('dsig_off_' + nm, off, 'Digital signature ' + t.lower() + ' offset register. Gives the buffer offset of the ' + t.lower() + '.', [
        F('off', '[16:0]', 'rw', '0x0', D(t + ' offset', 'Byte offset in the buffer where the ' + e + ' starts.',
            'Program before the start command; the output offset is read after done.', '0x00000 to 0x0FFFF offset (reset value 0x00000)', 'byte',
            'The region must lie inside the buffer; otherwise the buffer-overflow error is set.')),
        RES('[31:17]')]))

regs.append(R('dsig_cmd', '0x70', 'Digital signature command register. Starts, aborts and clears.', [
    F('start', '[0]', 'wo', '0x0', D('Start command', 'Starts the operation described by the operation, set, length and offset registers.',
        'Write 1 after the IP is enabled and the data are in the buffer; hardware clears the bit when it accepts the command; it reads as 0.',
        ['0x0 no command (reset value)', '0x1 start'], 'none', 'A start while busy, while the IP is disabled or for a disabled algorithm is rejected and sets an error.')),
    F('abort', '[1]', 'wo', '0x0', D('Abort command', 'Stops the running operation without a result and clears the secret state.',
        'Write 1 to cancel; hardware clears the bit when it takes the command.', ['0x0 no command (reset value)', '0x1 abort'], 'none', 'Has no effect when the IP is idle.')),
    F('clr', '[2]', 'wo', '0x0', D('Clear command', 'Clears the done, result and error flags and the secret state.',
        'Write 1 after reading the result; hardware clears the bit when it takes the command.', ['0x0 no command (reset value)', '0x1 clear'], 'none', 'Does not clear the enable bits or the lock.')),
    RES('[31:3]')]))

regs.append(R('dsig_sts', '0x74', 'Digital signature status register. Reports the state of the current or last operation.', [
    F('busy', '[0]', 'ro', '0x0', D('Busy', 'Reports that an operation is running.', 'Poll until 0 after a start command, or use the done interrupt.', ['0x0 idle (reset value)', '0x1 busy'])),
    RES('[7:1]'),
    F('resvld', '[8]', 'ro', '0x0', D('Result valid', 'Reports that an operation completed and its result is in the buffer or in the verify flags.',
        'Read after done; cleared by the clear command and by a new start.', ['0x0 no result (reset value)', '0x1 result valid'])),
    F('sigok', '[9]', 'ro', '0x0', D('Signature valid', 'Reports the outcome of a verification: 1 when the signature is valid under the selected policy.',
        'Read after done for a verification; meaningless for other operations.', ['0x0 invalid or not a verification (reset value)', '0x1 valid'], 'none',
        'An invalid signature is not an error flag.')),
    F('edok', '[10]', 'ro', '0x0', D('Ed25519 part valid', 'In a hybrid verification, reports that the Ed25519 signature is valid.',
        'Read after done of a hybrid verification.', ['0x0 invalid or not hybrid (reset value)', '0x1 valid'])),
    F('mlok', '[11]', 'ro', '0x0', D('ML-DSA part valid', 'In a hybrid verification, reports that the ML-DSA signature is valid.',
        'Read after done of a hybrid verification.', ['0x0 invalid or not hybrid (reset value)', '0x1 valid'])),
    RES('[31:12]')]))

errs = [('algdis', 'Algorithm disabled', 'a start command named an algorithm whose enable bit is 0 or that is not built'),
        ('opuns', 'Operation unsupported', 'a start command named an operation, mode or parameter set that is not built or is reserved'),
        ('badlen', 'Bad length', 'a length or hash pairing is not allowed'),
        ('badkey', 'Bad key', 'the private key is malformed or missing'),
        ('badpt', 'Invalid point or format', 'a public key, signature or point failed the format or on-curve check'),
        ('bufovf', 'Buffer overflow', 'a region does not fit the buffer'),
        ('buserr', 'Bus error', 'the AXI4 port answered SLVERR'),
        ('enttmo', 'Entropy timeout', 'the entropy input did not deliver words in time'),
        ('keytmo', 'Key timeout', 'the key input did not deliver a word in time'),
        ('vasmis', 'Verify-after-sign mismatch', 'the check of a new signature failed'),
        ('lockv', 'Lock violation', 'a write was refused because the enable lock is set'),
        ('busycmd', 'Access while busy', 'a start command or a window write arrived while an operation was running')]
ef = []
for i, (n, t, c) in enumerate(errs):
    ef.append(F(n, '[%d]' % i, 'w1c', '0x0', D(t + ' error', 'Sticky flag that the hardware sets when ' + c + '.',
        'Read after done or after an interrupt; write 1 to this bit to clear it.', ['0x0 not set (reset value)', '0x1 set'], 'none',
        'A write of 0 keeps the bit; a hardware set in the same cycle as a clear wins.')))
ef.append(RES('[31:12]'))
regs.append(R('dsig_err', '0x78', 'Digital signature error register. Holds the sticky error flags.', ef))

regs.append(R('dsig_irq_raw', '0x7C', 'Digital signature raw interrupt register. Holds the sticky interrupt events.', irq_fields('raw')))
regs.append(R('dsig_irq_en', '0x80', 'Digital signature interrupt enable register. Allows each event to drive the interrupt.', irq_fields('en')))
regs.append(R('dsig_irq_inj', '0x84', 'Digital signature interrupt injection register. Injects events for test.', irq_fields('inj')))
regs.append(R('dsig_irq_sts', '0x88', 'Digital signature masked interrupt status register. Reports the pending masked events.', irq_fields('sts')))

regs.append(R('dsig_alarm', '0x8C', 'Digital signature alarm register. Holds the sticky security alarm flags.', [
    F('fault', '[0]', 'w1c', '0x0', D('Fault alarm', 'Sticky flag that the hardware sets when verify-after-sign finds that a new signature does not verify.',
        'Treat as a possible fault attack; write 1 to this bit to clear it after handling.', ['0x0 not set (reset value)', '0x1 set'], 'none',
        'Drives the alarm output while set.')),
    F('lockv', '[1]', 'w1c', '0x0', D('Lock violation alarm', 'Sticky flag that the hardware sets when a write to the enable register is refused while locked.',
        'Write 1 to this bit to clear it.', ['0x0 not set (reset value)', '0x1 set'], 'none', 'Drives the alarm output while set.')),
    F('rngfail', '[2]', 'w1c', '0x0', D('Random source alarm', 'Sticky flag that the hardware sets when the random source fails its health check or times out.',
        'Write 1 to this bit to clear it.', ['0x0 not set (reset value)', '0x1 set'], 'none', 'Drives the alarm output while set.')),
    RES('[31:3]')]))

regs.append(R('dsig_win_addr', '0x90', 'Digital signature window address register. Holds the buffer byte address of the data window.', [
    F('addr', '[16:0]', 'rwi', '0x0', D('Window address', 'Byte address in the buffer that the next window write or read uses; the hardware adds 4 after each access.',
        'Program before accessing the window registers; word aligned.', '0x00000 to 0x0FFFC address (reset value 0x00000)', 'byte',
        'Bits 1:0 are written as 0; an address past the buffer end sets the buffer-overflow error.')),
    RES('[31:17]')]))
regs.append(R('dsig_win_wr', '0x94', 'Digital signature window write register. Writes one word into the buffer.', [
    F('data', '[31:0]', 'wo', '0x0', D('Window write data', 'Word that the hardware writes into the buffer at the window address when software writes this register.',
        'Write after setting the window address; each write advances the address by 4.', '0x00000000 to 0xFFFFFFFF data word', 'word', 'Reads as 0.'))]))
regs.append(R('dsig_win_rd', '0x98', 'Digital signature window read register. Reads one word from the buffer.', [
    F('data', '[31:0]', 'ro', '0x0', D('Window read data', 'Word that the buffer holds at the window address; the hardware advances the address by 4 after each software read.',
        'Read after setting the window address and after done for results.', '0x00000000 to 0xFFFFFFFF data word', 'word',
        'The window returns zero while an operation is running and while the buffer is not readable.'))]))

regs.append(R('dsig_cnt_ops', '0x9C', 'Digital signature operation counter register. Counts operations.', [
    F('cnt', '[31:0]', 'ro', '0x0', D('Operation count', 'Number of start commands accepted since reset, when the log feature is built.',
        'Read to audit use of the IP; frozen after the log lock.', '0x00000000 to 0xFFFFFFFF count (reset value 0x00000000)', 'count',
        'Saturates at 0xFFFFFFFF; reads 0 when the log feature is not built.'))]))
regs.append(R('dsig_cnt_fail', '0xA0', 'Digital signature failure counter register. Counts failed operations.', [
    F('cnt', '[31:0]', 'ro', '0x0', D('Failure count', 'Number of operations that ended with an error flag or an invalid signature, when the log feature is built.',
        'Read to audit failures; frozen after the log lock.', '0x00000000 to 0xFFFFFFFF count (reset value 0x00000000)', 'count',
        'Saturates at 0xFFFFFFFF; reads 0 when the log feature is not built.'))]))
regs.append(R('dsig_log_lock', '0xA4', 'Digital signature log lock register. Freezes the counters until the next reset.', [
    F('req', '[0]', 'wo', '0x0', D('Log lock request', 'Command that freezes the counters until the next reset of the core.',
        'Write 1 once; hardware latches the lock and clears this bit; it reads as 0.', ['0x0 no request (reset value)', '0x1 request the lock'], 'none',
        'Has no effect when the log feature is not built.')),
    RES('[7:1]'),
    F('locked', '[8]', 'ro', '0x0', D('Log lock state', 'Reports whether the counters are frozen.', 'Read after the request to confirm.',
        ['0x0 not locked (reset value)', '0x1 locked'], 'none', 'Cleared only by a reset of the core.')),
    RES('[31:9]')]))

regs.append(R('dsig_rng', '0xA8', 'Digital signature random source register. Controls and reports the random source.', [
    F('reseed', '[0]', 'wo', '0x0', D('Reseed command', 'Command that makes the internal random generator request fresh entropy and reseed.',
        'Write 1 before a series of signatures or after an alarm; hardware clears the bit when it takes the command.', ['0x0 no command (reset value)', '0x1 reseed'], 'none',
        'Has no effect when the random source is the entropy input.')),
    RES('[7:1]'),
    F('ready', '[8]', 'ro', '0x0', D('Random source ready', 'Reports that the random source can deliver bytes now.', 'Poll before a signing start command when a seed may be pending.',
        ['0x0 not ready (reset value)', '0x1 ready'])),
    F('due', '[9]', 'ro', '0x0', D('Reseed due', 'Reports that the internal generator reached its reseed limit.', 'Write the reseed command when set.',
        ['0x0 not due (reset value)', '0x1 due'], 'none', 'Reads 0 when the internal generator is not built.')),
    RES('[31:10]')]))
regs.append(R('dsig_tmo', '0xAC', 'Digital signature timeout register. Sets the entropy and key input timeouts.', [
    F('ent', '[15:0]', 'rw', '0xFFFF', D('Entropy timeout', 'Time that the IP waits for an entropy word before the entropy-timeout error.',
        'Program before the first operation that needs randomness.', '0x0001 to 0xFFFF timeout (reset value 0xFFFF)', '1024 core clock cycles',
        'A value of 0 is treated as 1.')),
    F('key', '[31:16]', 'rw', '0xFFFF', D('Key timeout', 'Time that the IP waits for a key word from the key input before the key-timeout error.',
        'Program before the first signing operation that uses the key input.', '0x0001 to 0xFFFF timeout (reset value 0xFFFF)', '1024 core clock cycles',
        'A value of 0 is treated as 1.'))]))

regs.append({'name': 'dsig_key', 'offset': '0x100', 'description': 'Digital signature private key register. Receives one 32-bit word of the private key.',
             'repeat': {'mode': 'FIXED', 'count': 17, 'stride': '0x4'}, 'fields': [
    F('data', '[31:0]', 'wo', '0x0', D('Private key word', 'One 32-bit word of the private key; word 0 holds the first four key bytes. Software cannot read it back; hardware clears it.',
        'Write all words of the key before a signing or key-generation start command when the write-only key register is built; hardware clears the words after completion, error, abort or reset.',
        '0x00000000 to 0xFFFFFFFF key word', 'word',
        'Reads as 0; 17 words give 68 bytes, enough for a 66-byte P-521 key; unused words are ignored; ML-DSA uses the first 8 words as its 32-byte seed.'))]})

doc = {'module': 'm_vlsit_csr_dsig', 'prefix': 'dsig', 'async': 1, 'ip_version': {'major': 1, 'minor': 0},
       'event_sideband': 1, 'registers': regs}
import os
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(doc, open(OUT, 'w', encoding='utf-8'), indent=1)
print('registers', len(regs))
