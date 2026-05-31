You are implementing one Maestro mission wave (child task).

## Inputs

- Task context: read `.definitively/state/maestro-run.json` (`task_id`, `task_slug`, `mission_id`, `spec_path`).
- Contract: `maestro contract show --task <task_id>`
- Spec: path from run state.

## Task

1. `maestro task claim` is already done — implement the wave per contract intent and scope.
2. Match repo conventions in `AGENTS.md`.
3. Make surgical edits only; run `.maestro/bootstrap/validation/verify-fast.sh` if helpful during work.

Respond JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
