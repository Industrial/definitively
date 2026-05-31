# Program inputs

Programs can declare named CLI inputs under `program.inputs`. At run start, definitively parses flags like `--plan-file` and stores values in `RunContext.inputs` before the FSM starts.

## Declaring inputs

```yaml
program:
  id: plan_mission
  version: 1
  initial: idle
  inputs:
    plan_file:
      type: path
      required: true
      description: Plan markdown (Cursor .plan.md or any planning doc)
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | `path` or `string` |
| `required` | no | Default `false` |
| `default` | no | Value when flag omitted |
| `description` | no | Shown in `--help` output |

Input keys use snake_case; CLI flags derive automatically (`plan_file` → `--plan-file`).

## Running with inputs

```bash
definitively run "$PWD/.definitively/programs/plan-mission.yml" \
  --plan-file .cursor/plans/my.plan.md
```

## Discovering inputs

List declared inputs without executing:

```bash
definitively run --help "$PWD/.definitively/programs/plan-mission.yml"
```

## Validation

- **Missing required inputs** fail before the FSM starts.
- **Unknown flags** error with a hint to run `--help`.
- **Positional args** are not supported in v1 (flags only).

## Consumption in nodes

Maestro nodes read `inputs["plan_file"]` from run context (see `RunState.init_plan/2`). Other node kinds can access inputs via workflow context as programs evolve.

## Deprecated env vars

`DEFINITIVELY_PLAN_FILE` still works for one release but logs a deprecation warning. Prefer `--plan-file` on the CLI.

**Try it:** Add a required `branch_name` input to a scratch program and pass `--branch-name feature/foo`.
