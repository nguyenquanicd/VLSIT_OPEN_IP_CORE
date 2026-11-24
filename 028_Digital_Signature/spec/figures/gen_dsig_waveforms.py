"""Generates the WaveJSON sources of the waveform plan WF-001 to WF-014 (section 10.3 of the HDS).
Every wave string has 12 cycles. Signal names follow the port list of section 6.2 and the CSR ports
listed in spec/csr/dsig_ports.txt; internal nodes use the w_ and r_ prefixes."""
import json
import os

here = os.path.dirname(os.path.abspath(__file__))
CLK = {'name': 'i_clk_core', 'wave': 'p...........'}


def s(name, wave, data=None):
    d = {'name': name, 'wave': wave}
    if data:
        d['data'] = data
    return d


STATE = ['ENUM_ST_IDLE', 'ENUM_ST_CHECK', 'ENUM_ST_RUN', 'ENUM_ST_RESULT', 'ENUM_ST_CLEAR']

W = {}

W['wf_001_axi_write_burst'] = ('OP-001, success: AXI4 INCR burst of 4 beats into the buffer window',
    [CLK, ['write address', s('i_axi_awvalid', '01.0........'), s('o_axi_awready', '0.10........'),
           s('i_axi_awaddr', 'x=.x........', ['0x040']), s('i_axi_awlen', 'x=.x........', ['3']), s('i_axi_awburst', 'x=.x........', ['INCR'])],
     ['write data', s('i_axi_wvalid', '0001...0....'), s('o_axi_wready', '0001...0....'), s('i_axi_wdata', 'xxx====x....', ['D0', 'D1', 'D2', 'D3']),
      s('i_axi_wlast', '00000010....')],
     ['write response', s('o_axi_bvalid', '000000011.0.'), s('i_axi_bready', '00000001..0.'), s('o_axi_bresp', 'xxxxxxx=.xxx', ['OKAY'])]],
    'Handshake: a transfer occurs on each rising edge where valid and ready are both 1.')

W['wf_002_axi_write_overflow'] = ('OP-001, error: burst past the window end gets SLVERR, nothing is written',
    [CLK, ['write address', s('i_axi_awvalid', '01.0........'), s('o_axi_awready', '0.10........'),
           s('i_axi_awaddr', 'x=.x........', ['0x3FC']), s('i_axi_awlen', 'x=.x........', ['3'])],
     ['write data', s('i_axi_wvalid', '0001...0....'), s('o_axi_wready', '0001...0....'), s('i_axi_wlast', '00000010....'),
      s('w_buf_wr_en', '000000000000')],
     ['response and error', s('o_axi_bvalid', '000000011.0.'), s('i_axi_bready', '00000001..0.'), s('o_axi_bresp', 'xxxxxxx=.xxx', ['SLVERR']),
      s('i_hw_we_dsig_err_bufovf', '000000100...'), s('o_dsig_err_bufovf', '0000000.1...')]],
    'The buffer is 1 KiB (default); the burst starts at 0x3FC and needs 16 bytes, so it does not fit.')

W['wf_003_verify_start_done'] = ('OP-004, success: verification from start command to done',
    [CLK, ['command', s('o_dsig_cmd_start', '0110........'), s('i_hw_clr_dsig_cmd_start', '0010........')],
     ['control block', s('reg_fsm_ctl_current_state', '=.=.......=.', ['ENUM_ST_IDLE', 'ENUM_ST_RUN', 'ENUM_ST_CLEAR']), s('i_dsig_sts_busy', '00111111110.')],
     ['result', s('i_dsig_sts_resvld', '000000011111'), s('i_dsig_sts_sigok', '000000011111'), s('o_irq', '000000001111')]],
    'The state ENUM_ST_CHECK and ENUM_ST_RESULT last one cycle each and are not drawn; busy covers them.')

W['wf_004_sign_key_input'] = ('OP-003, success: signing with the key taken from the key input port',
    [CLK, ['key request', s('o_key_req', '001.1.1.1...'), s('o_key_idx', 'xx=.=.=.=...', ['0', '1', '2', '3']),
           s('i_key_valid', '0001.01.01..'), s('i_key_data', 'xxx=x=x=x=x.', ['K0', 'K1', 'K2', 'K3'])],
     ['control block', s('reg_fsm_ctl_current_state', '=.=.=...=...', ['ENUM_ST_IDLE', 'ENUM_ST_CHECK', 'ENUM_ST_RUN']), s('i_dsig_sts_busy', '01111111111.')]],
    'The key word index is requested one word at a time; a key of 4 words is shown for brevity.')

W['wf_005_start_disabled'] = ('Error: start command for an algorithm whose enable bit is 0',
    [CLK, ['command', s('o_dsig_cmd_start', '0110........'), s('i_hw_clr_dsig_cmd_start', '0010........')],
     ['control block', s('reg_fsm_ctl_current_state', '=.=.=.=.....', ['ENUM_ST_IDLE', 'ENUM_ST_CHECK', 'ENUM_ST_ERR', 'ENUM_ST_CLEAR'])],
     ['error', s('i_hw_we_dsig_err_algdis', '000010......'), s('o_dsig_err_algdis', '0000011.....'), s('o_irq', '00000001....')]],
    'No engine is started; the error flag is set and the interrupt follows the raw event and the mask.')

W['wf_006_entropy_timeout'] = ('Error: no entropy word arrives within the entropy timeout',
    [CLK, ['entropy', s('o_ent_req', '0011111110..'), s('i_ent_valid', '000000000...')],
     ['control block', s('reg_fsm_ctl_current_state', '=.=...=.=...', ['ENUM_ST_CHECK', 'ENUM_ST_ERR', 'ENUM_ST_CLEAR']), s('w_ent_timeout', '00000001....')],
     ['error', s('i_hw_we_dsig_err_enttmo', '000000010...'), s('o_dsig_err_enttmo', '0000000.11..'), s('o_alarm', '0000000.11..')]],
    'The timeout is drawn short; the real value is dsig_tmo.ent in units of 1024 core clock cycles.')

W['wf_007_abort'] = ('Corner: abort during a running operation clears the key',
    [CLK, ['command', s('o_dsig_cmd_abort', '0001........'), s('i_hw_clr_dsig_cmd_abort', '0000100.....')],
     ['control block', s('reg_fsm_ctl_current_state', '=..=..=.....', ['ENUM_ST_RUN', 'ENUM_ST_CLEAR', 'ENUM_ST_IDLE']), s('i_dsig_sts_busy', '1111110.....')],
     ['secret state', s('w_key_nonzero', '1111100.....'), s('i_dsig_sts_resvld', '000000000000')]],
    'No result is produced; the key registers are zero within 100 core clock cycles (drawn short).')

W['wf_008_window_access'] = ('OP-001 through the CSR window: write words, then read words with auto-increment',
    [CLK, ['write', s('o_reg_wr_en', '0101.0......'), s('o_reg_wr_addr', 'x=x=.x......', ['WIN_WR', 'WIN_WR']),
           s('o_dsig_win_wr_data', 'x=x=.x......', ['W0', 'W1'])],
     ['address register', s('o_dsig_win_addr_addr', '=.=.=.=.=...', ['0x000', '0x004', '0x008', '0x004', '0x008']),
      s('i_hw_we_dsig_win_addr_addr', '0101.010....')],
     ['read', s('o_reg_rd_en', '0000.0101...'), s('i_dsig_win_rd_data', 'xxxxxxx=x=x.', ['W1', 'W2'])]],
    'After each window access hardware adds 4 to the address; software writes the address first (0x000) and later 0x004.')

W['wf_009_vas_mismatch'] = ('Error: verify-after-sign finds a mismatch, the signature is suppressed',
    [CLK, ['control block', s('reg_fsm_ctl_current_state', '=.=.=.=.=...', ['ENUM_ST_RUN', 'ENUM_ST_VAS', 'ENUM_ST_ERR', 'ENUM_ST_CLEAR', 'ENUM_ST_IDLE']),
           s('w_vas_ok', '000000000000')],
     ['flags', s('i_hw_we_dsig_err_vasmis', '000001......'), s('i_hw_we_dsig_alarm_fault', '000001......'),
      s('o_dsig_alarm_fault', '0000001.....'), s('o_alarm', '0000001.....')],
     ['result', s('i_dsig_sts_resvld', '000000000000')]],
    'No result is written (resvld stays 0); alarm stays until software writes 1 to dsig_alarm.fault.')

W['wf_010_keygen'] = ('OP-002, success: key generation with entropy and key seed',
    [CLK, ['command', s('o_dsig_cmd_start', '0110........')],
     ['inputs', s('o_key_req', '0011.1.1.0..'), s('i_key_valid', '00010.1.1...'), s('o_ent_req', '0000011111..'), s('i_ent_valid', '000000.1.1..')],
     ['result', s('i_dsig_sts_busy', '011111111110'), s('i_dsig_sts_resvld', '000000000111')]],
    'The public key is written at dsig_off_res.off; the private key and the working registers are then cleared.')

W['wf_011_hybrid_verify'] = ('OP-005, success then one part invalid: hybrid verification as two verifications, policy both valid',
    [CLK, ['command', s('o_dsig_cmd_start', '010001000000'), s('o_dsig_op_alg', '=....=......', ['0x0', '0xA']),
           s('o_dsig_op_hybpol', '=...........', ['0x0'])],
     ['control block', s('reg_fsm_ctl_current_state', '=.=...=.=...', ['ENUM_ST_IDLE', 'ENUM_ST_RUN', 'ENUM_ST_IDLE', 'ENUM_ST_RUN']),
      s('i_dsig_sts_busy', '011100011100')],
     ['latched results', s('i_dsig_sts_edok', '000001111111'), s('i_dsig_sts_mlok', '000000000111'), s('i_dsig_sts_sigok', '000000000111')]],
    'Ed25519 verifies valid (edok 1, sigok 0 under policy both valid); the ML-DSA verification then sets mlok and sigok.')

W['wf_012_secret_clearing'] = ('OP-006, corner: secret clearing after completion',
    [CLK, ['control block', s('reg_fsm_ctl_current_state', '=..=..=.....', ['ENUM_ST_RESULT', 'ENUM_ST_CLEAR', 'ENUM_ST_IDLE']), s('i_dsig_sts_busy', '1111110.....')],
     ['secret state', s('w_key_nonzero', '1111100.....'), s('i_hw_clr_dsig_key_0_data', '0001100.....'), s('w_work_nonzero', '1111000.....')]],
    'Clearing finishes within 100 core clock cycles of entering ENUM_ST_CLEAR (drawn short).')

W['wf_013_random_request'] = ('OP-007, success: random request served by the internal generator',
    [CLK, ['request', s('o_ent_req', '0011.0......'), s('i_ent_valid', '00001.1.....'), s('i_ent_data', 'xxxx=x=x....', ['E0', 'E1'])],
     ['generator', s('i_dsig_rng_ready', '000000.1111.'), s('w_rng_valid', '000000011..0')]],
    'The generator is reseeded from the entropy words and then delivers bytes to the engine.')

W['wf_014_hash_request'] = ('OP-008, success: arbiter grant, absorb and continuous SHAKE squeeze',
    [CLK, ['arbiter', s('w_hreq', '0111111.....'), s('w_hgrant', '00111111....')],
     ['stream', s('w_hin_valid', '0011.0......'), s('w_hin_last', '00010.......'), s('w_perm_start', '000100100...'),
      s('w_hout_valid', '0000011.1.0.'), s('w_hout_last', '00000000010.')],
     ['engine', s('w_eng_done', '0000100100..')]],
    'The squeeze repeats the permutation for each further block of output; request and grant end after the last output.')


W['wf_015_apb_write_read'] = ('APB4 CSR write then read, success (one wait state)',
    [CLK, ['request', s('i_apb_psel', '011101110000'), s('i_apb_penable', '001100110000'), s('i_apb_pwrite', '011100000000'),
           s('i_apb_paddr', 'x=..x=..xxxx', ['0x044', '0x074']), s('i_apb_pwdata', 'x=..xxxxxxxx', ['0x1'])],
     ['response', s('o_apb_pready', '000100010000'), s('o_apb_pslverr', '000000000000'), s('o_apb_prdata', 'xxxxxxx=xxxx', ['0x0'])]],
    'The write goes to dsig_alg_en and the read to dsig_sts; PREADY rises one cycle after the first access cycle (section 11.4).')

W['wf_016_apb_nonsecure_error'] = ('APB4 CSR access with PPROT[1] = 1 while the protection check is on: PSLVERR, no change',
    [CLK, ['control inputs', s('i_protect_en', '111111111111'), s('i_slverr_en', '111111111111')],
     ['request', s('i_apb_psel', '011000000000'), s('i_apb_penable', '001000000000'), s('i_apb_pwrite', '011000000000'),
      s('i_apb_pprot', 'x==xxxxxxxxx', ['0x2', '0x2']), s('i_apb_paddr', 'x=.xxxxxxxxx', ['0x044'])],
     ['response', s('o_apb_pready', '001000000000'), s('o_apb_pslverr', '001000000000'), s('o_dsig_alg_en_ed25519', '000000000000')]],
    'An error answers in the first access cycle (no wait state); the write is ignored, so the enable bit stays 0.')

W['wf_017_dma_request_ack'] = ('DMA request and acknowledge: the request stays asserted until the acknowledge',
    [CLK, ['input request', s('o_dma_in_req', '001111000000'), s('i_dma_in_ack', '000001000000')],
     ['data', s('i_axi_wvalid', '000000111000'), s('o_axi_wready', '000000111000')],
     ['output request', s('i_dsig_sts_resvld', '000000000111'), s('o_dma_out_req', '000000000110'), s('i_dma_out_ack', '000000000001')]],
    'The input request is raised when the buffer can take data; the acknowledge is a one-cycle pulse that ends the request.')

W['wf_018_key_timeout'] = ('Error: the key store does not answer within the key timeout',
    [CLK, ['key request', s('o_key_req', '0011111110..'), s('o_key_idx', 'xx=.....xxxx', ['0']), s('i_key_valid', '000000000000')],
     ['control block', s('reg_fsm_ctl_current_state', '=.=...=.=...', ['ENUM_ST_CHECK', 'ENUM_ST_KEY', 'ENUM_ST_ERR']), s('w_key_timeout', '00000001....')],
     ['error', s('i_hw_we_dsig_err_keytmo', '000000010...'), s('o_dsig_err_keytmo', '0000000.11..'), s('o_irq', '0000000..11.')]],
    'The timeout is drawn short; the real value is dsig_tmo.key in units of 1024 core clock cycles; the key is cleared afterwards.')

# These figures are generated from the simulation by make_sim_figures.py (designer decision 2026-11-24); the
# schematic versions below are kept as the record of the former figures.
SIMULATED = {'wf_003_verify_start_done', 'wf_005_start_disabled', 'wf_007_abort', 'wf_008_window_access',
             'wf_009_vas_mismatch', 'wf_011_hybrid_verify', 'wf_012_secret_clearing', 'wf_016_apb_nonsecure_error'}

for name, (title, signal, foot) in W.items():
    if name in SIMULATED:
        continue
    hs = 2 if any('ENUM_ST_' in str(x) or 'WIN_WR' in str(x) for x in json.dumps(signal).split(',')) else 1
    doc = {'signal': signal, 'head': {'text': title}, 'foot': {'text': foot}, 'config': {'hscale': hs}}
    json.dump(doc, open(os.path.join(here, name + '.json'), 'w', encoding='utf-8'), indent=1)
print(len(W), 'waveforms')
