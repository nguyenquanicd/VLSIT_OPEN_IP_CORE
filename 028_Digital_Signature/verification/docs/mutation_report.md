# Mutation run of the phase 1 testbench

Bugs injected into copies of the RTL (the delivered RTL is unchanged). CAUGHT = a failed check or assertion other than an
OPEN-n check (decision of the designer pending) or a run that did not finish.

Caught 40 of 40. M03, M28 were run in a later call (pattern corrected or test added); the others come from the previous full run.

| ID | Requirement broken | Result | Failed checks | Assertion failures | First failure |
|---|---|---|---:|---:|---|
| M01 | REQ-REG-001 effective enable bit ignored | CAUGHT | 29 | 4 | ASSERT FAIL @38085000: REQ-REG-001 SVA-004 an engine starts only for an enabled algorithm |
| M02 | DEC-038 priority of the checks | CAUGHT | 8 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: err flags of a failing check (ERR table, DEC-038) got=0x00000004 expecte |
| M03 | DEC-032 curve and hash pairing | CAUGHT | 252 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: no error flag on a passing operation got=0x00000004 expected=0x00000000 |
| M04 | ERR-003 HSS level count 1 to 8 | CAUGHT | 8 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: no error flag on a passing operation got=0x00000004 expected=0x00000000 |
| M05 | ERR-006 region fits the buffer | CAUGHT | 32 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: no error flag on a passing operation got=0x00000020 expected=0x00000000 |
| M06 | DEC-031 random nonce only when selected | CAUGHT | 6 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: random block start count (DEC-031) got=0x00000001 expected=0x00000000 |
| M07 | ERR-010 mismatch sets the fault alarm | CAUGHT | 7 | 2 | ASSERT FAIL @780245000: ERR-010 verify-after-sign mismatch sets the fault alarm |
| M08 | DEC-033 cnt_ops counts accepted starts | CAUGHT | 104 | 0 | [TEST-013 REQ-REG-001 ERR-001 start with IP and algorithm enable bits]: cnt_ops unchanged by a failing check (DEC-033) got=0x00000001 expected=0x00000000 |
| M09 | REQ-SEC-006 log lock freezes the counters | CAUGHT | 2 | 3 | ASSERT FAIL @980505000: DEC-033 REQ-SEC-006 counters stop after the log lock |
| M10 | ERR-011 lock violation sets the alarm | CAUGHT | 3 | 1 | ASSERT FAIL @947115000: ERR-011 lock violation sets the error and the alarm together |
| M11 | DEC-030 hybrid policy Ed25519 valid | CAUGHT | 24 | 0 | [TEST-013 REQ-REG-001 ERR-001 start with IP and algorithm enable bits]: sts.sigok of a verification (OP-004, DEC-030) got=0x00000000 expected=0x00000001 |
| M12 | REQ-SEC-005 abort clears the secrets | CAUGHT | 2 | 1 | ASSERT FAIL @863705000: FSM-01 state transitions follow the table of section 10.1 |
| M13 | section 14.2 engine group of ML-DSA | CAUGHT | 142 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: engine group 0 start count got=0x00000001 expected=0x00000000 |
| M14 | REQ-SEC-005 CLEAR waits for the cleared level | CAUGHT | 0 | 5 | ASSERT FAIL @22585000: REQ-SEC-005 SVA-005 secrets are zero when ENUM_ST_CLEAR ends |
| M15 | ERR-009 key timeout ends the operation | CAUGHT | 4 | 0 | [TEST-030 REQ-SEC-007 ERR-008 ERR-009 key and entropy timeouts]: only keytmo is set (ERR-009) got=0x00000000 expected=0x00000100 |
| M16 | ENUM_ST_RESULT raises the done event | CAUGHT | 255 | 0 | [TEST-013 REQ-REG-001 ERR-001 start with IP and algorithm enable bits]: operation did not complete (timeout) |
| M17 | OP-004 sigok is the verification result | CAUGHT | 147 | 0 | [TEST-013 REQ-REG-001 ERR-001 start with IP and algorithm enable bits]: sts.sigok of a verification (OP-004, DEC-030) got=0x00000000 expected=0x00000001 |
| M18 | section 10.1 clear command enters ENUM_ST_CLEAR | CAUGHT | 1 | 0 | [TEST-028 REQ-SEC-005 OP-006 clearing of the secret state]: dsig_cmd.clr clears the key words within 100 clocks (S18, OP-006) |
| M19 | DEC-035 unused encoding sets the fault alarm | CAUGHT | 9 | 0 | [TEST-023 DEC-035 recovery of an unused state encoding]: alarm.fault set by an unused state encoding (DEC-035) got=0x00000000 expected=0x00000001 |
| M20 | ERR-008 entropy timeout sets rngfail | CAUGHT | 2 | 1 | ASSERT FAIL @824025000: ERR-008 entropy timeout sets the random-source alarm |
| M21 | DEC-031 random only for hedged ML-DSA | CAUGHT | 4 | 0 | [TEST-023 REQ-FUNC-001 to 008 OP-002 OP-003 OP-004 flows of the control block]: random block start count (DEC-031) got=0x00000001 expected=0x00000000 |
| M22 | ENUM_ST_VAS after signing | CAUGHT | 76 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: verify-after-sign start count (ENUM_ST_VAS) got=0x00000000 expected=0x00 |
| M23 | REQ-REG-002 lock request latches the lock | CAUGHT | 13 | 0 | [TEST-014 REQ-REG-002 ERR-011 DEC-034 lock of the algorithm enables]: dsig_lock.locked is 1 and req reads 0 got=0x00000000 expected=0x00000100 |
| M24 | section 6.4 injection acts on the rising edge | CAUGHT | 2 | 0 | [TEST-018 REQ-IF-003 interrupt mask, injection, clear, alarm]: the injection bit held at 1 does not raise the event again got=0x00000004 expected=0x00000000 |
| M25 | section 6.4 the mask of the events | CAUGHT | 3 | 5 | ASSERT FAIL @31505000: 6.4 irq_sts is the raw event masked by the enable |
| M26 | section 6.4 the alarm is not maskable | CAUGHT | 5 | 5 | ASSERT FAIL @780255000: 6.4 o_alarm high for fault or lock violation |
| M27 | ERR-002 signing not built | CAUGHT | 50 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: err flags of a failing check (ERR table, DEC-038) got=0x00000000 expecte |
| M28 | ERR-003 prehash digest length of ML-DSA | CAUGHT | 23 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: err flags of a failing check (ERR table, DEC-038) got=0x00000000 expecte |
| M29 | REQ-SEC-005 abort in ENUM_ST_RNG | CAUGHT | 7 | 0 | [TEST-028 REQ-SEC-005 S19 abort and reset during an operation]: abort in RNG: busy 0 and no result got=0x00000001 expected=0x00000000 |
| M30 | REQ-SEC-005 abort in ENUM_ST_VAS | CAUGHT | 2 | 0 | [TEST-028 REQ-SEC-005 S19 abort and reset during an operation]: abort in VAS: busy 0 and no result (signature suppressed) got=0x00000001 expected=0x00000000 |
| B01 | REQ-IF-002 byte strobes | CAUGHT | 300 | 0 | [TEST-033 TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 buffer, numbered example 1]: bus read equals the reference content |
| B02 | section 10.5 window address adds 4 | CAUGHT | 181 | 5 | ASSERT FAIL @550135000: 10.5 the window address advances by 4 after a window access |
| B03 | section 10.5 window read data are 0 while busy | CAUGHT | 1 | 0 | [TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 ERR-012 commands and writes while busy]: the window read data are 0 while busy (section 10.5) got=0x77778888 expected=0 |
| B04 | REQ-IF-002 no bus write while busy | CAUGHT | 1 | 0 | [TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 ERR-012 commands and writes while busy]: bus write while busy changed nothing |
| B05 | DEC-039 window write one cycle after the event | CAUGHT | 79 | 0 | [TEST-033 TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 buffer, numbered example 1]: example 1 step 2: bytes 28 to 31 are DD CC BB AA |
| B06 | section 10.5 window range | CAUGHT | 5 | 0 | [TEST-033 TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 buffer, numbered example 1]: example 1 step 5: window read at 0x400 returns 0 got=0x1e2d4b78 expected=0x000000 |
| B07 | section 10.5 the engines write while busy | CAUGHT | 294 | 0 | [TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check]: result word in the buffer at dsig_off_res (OP-002, OP-003) |
| B08 | ERR-012 window write while busy | CAUGHT | 1 | 0 | [TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 ERR-012 commands and writes while busy]: a window write while busy sets busycmd (ERR-012) got=0x00000000 expected=0x000 |
| B09 | ERR-006 window read outside the buffer | CAUGHT | 3 | 0 | [TEST-033 TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 buffer, numbered example 1]: example 1 step 5: bufovf set got=0x00000000 expected=0x00000020 |
| B10 | section 10.5 the address advances after a read | CAUGHT | 70 | 0 | [TEST-033 TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 buffer, numbered example 1]: example 1 step 3: window address becomes 0x1C got=0x00000018 expected=0x0000001c |
