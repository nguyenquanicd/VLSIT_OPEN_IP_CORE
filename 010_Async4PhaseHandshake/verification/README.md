# Verification workspace

This directory is the home for the complete verification environment, reusable testcases, independent models, plans, and run evidence for 010_Async4PhaseHandshake.

## Standard contents

- plan/: detailed, specification-derived verification plan. Each row should cite a requirement or protocol clause, scenario, expected result, testcase, and coverage evidence.
- tests/: reusable testcase sources and testcase generators.
- models/: independent reference models and expected-value helpers.
- Other directories may contain testbenches, BFMs, scripts, setup, logs, and run records.
- A path-coupled legacy package is kept intact under sim/ when splitting it would invalidate commands or recorded evidence.

Existing historical logs and coverage reports are not new sign-off. Read each report for its run ID, configuration, tools, and limits.
