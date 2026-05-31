You are decomposing a Maestro mission into child task waves from a plan file.

## Inputs (read-only)

Read `.definitively/state/maestro-run.json` for paths only — **never write or overwrite this file**:
- `plan_file` — plan markdown to read
- `decompose_file` — where to write the task batch JSON

Do not read `mission_id` from this file; definitively owns mission state separately.

## Task

1. Read the plan todos / phases from `plan_file`.
2. Write a JSON array to `decompose_file`:
   `[{"title":"…","slug":"…"}, …]`
   One entry per implementation wave; slugs kebab-case; titles outcome-named.
3. Ensure slugs are unique and ordered by dependency.

Write **only** the decompose JSON file. Do not modify any other state files.

Respond JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
