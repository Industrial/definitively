You are implementing one Maestro mission wave (child task).

## Inputs (read-only)

Read `.definitively/state/maestro-run.json` for context (`task_id`, `task_slug`, `spec_path`). **Do not write or overwrite this file.**

- Contract: `maestro contract show --task <task_id>`
- Spec: path from run state

## Task

1. `maestro task claim` is already done — implement the wave per contract intent and scope.
2. Match repo conventions in `AGENTS.md`.
3. Run `.maestro/bootstrap/validation/verify-fast.sh` if helpful during work.

Respond JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
