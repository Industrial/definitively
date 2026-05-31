# Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEFINITIVELY_WORKSPACE` | Parent of `.definitively/` from program path | Workspace root for runs, init, and visualize |
| `DEFINITIVELY_LOG_LEVEL` | `INFO` | Logging verbosity: `TRACE`, `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `DEFINITIVELY_AGENT` | unset | Default agent profile id for LLM nodes (e.g. `cursor`) |
| `DEFINITIVELY_AGENT_<ID>_EXECUTABLE` | unset | Override executable for profile `<id>` (uppercase, underscores) |
| `DEFINITIVELY_FROM_SOURCE` | unset | When `1`, devenv builds escript from `definitively/` on shell enter |

Copy hints from `.definitively/env.example` after `definitively init`.

## Agent profiles

LLM nodes resolve their subprocess from YAML profiles in `.definitively/agents/`. The `cursor` profile uses `DEFINITIVELY_AGENT_CURSOR_EXECUTABLE` when you need an absolute path (common on NixOS).

Set the default profile for all LLM nodes:

```bash
export DEFINITIVELY_AGENT=cursor
```

## Program inputs vs env vars

Prefer CLI flags declared in `program.inputs` (e.g. `--plan-file`) over ad-hoc env vars. See [Program inputs](../authoring/program-inputs.md).

`DEFINITIVELY_PLAN_FILE` is deprecated in v0.4.0 — use `--plan-file` instead.

## Logging

Set log level before running workflows:

```bash
export DEFINITIVELY_LOG_LEVEL=DEBUG
definitively run "$PWD/.definitively/programs/example.yml"
```

Trace-level logs show validation, node execution, and transition details.
