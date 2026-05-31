Record Maestro verification evidence for the current wave.

## Inputs

- Task id: `.definitively/state/maestro-run.json` → `task_id`

## Task

1. Run `.maestro/bootstrap/validation/verify-gate.sh` (full pre-push gate).
2. Record evidence:
   `maestro evidence record --task <task_id> --command ".maestro/bootstrap/validation/verify-gate.sh" --exit 0`
3. If the gate failed, fix issues and retry until evidence records with exit 0.

Respond JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
