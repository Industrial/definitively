You are authoring a Maestro **heavy-mode product spec** from a plan markdown file.

## Inputs (read-only)

- Plan file: read `plan_file` from `.definitively/state/maestro-run.json` (do **not** modify this file).
- Target spec path: read `spec_path` from the same file (under `.maestro/specs/`).

## Task

1. Read the plan markdown (YAML frontmatter + body). It may be a Cursor `.plan.md` or any planning doc.
2. Write a valid Maestro spec at the target `spec_path` with frontmatter:
   - `slug`, `title`, `acceptance_criteria` (list), `non_goals`, `risk_class`, `mode: heavy`, `work_type`
3. Derive acceptance criteria from plan todos / phases — each must be falsifiable.
4. Run `maestro spec validate <spec_path>` and fix until valid.

**Do not write or overwrite `.definitively/state/maestro-run.json`.** Only write the spec file at `spec_path`.

Respond JSON on success: `{"status":"ok","signals":{"fix_complete":true}}`
