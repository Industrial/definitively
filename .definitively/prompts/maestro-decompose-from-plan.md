You are decomposing a Maestro mission into child task waves from a plan file.

## Inputs

- Plan file: `DEFINITIVELY_PLAN_FILE` or `maestro-run.json` → `plan_file`
- Decompose output: `maestro-run.json` → `decompose_file` (JSON array for `maestro mission decompose --file`)
- Mission id: `maestro-run.json` → `mission_id`

## Task

1. Read the plan todos / phases.
2. Write a JSON array to `decompose_file`:
   `[{"title":"…","slug":"…"}, …]`
   One entry per implementation wave; slugs kebab-case; titles outcome-named.
3. Ensure slugs are unique and ordered by dependency.

Respond JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
