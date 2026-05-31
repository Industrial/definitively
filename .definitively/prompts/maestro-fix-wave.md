The pre-push quality gate failed after implementing a Maestro wave.

## Inputs

- Run state: `.definitively/state/maestro-run.json`
- Re-run `.maestro/bootstrap/validation/verify-gate.sh` to see failures.

## Task

Fix the codebase until the gate would pass. Do not skip failing checks.

Respond JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
