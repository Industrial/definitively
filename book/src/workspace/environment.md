# Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEFINITIVELY_WORKSPACE` | Parent of `.definitively/` from program path | Workspace root for runs, init, and visualize |
| `DEFINITIVELY_LOG_LEVEL` | `INFO` | Logging verbosity: `TRACE`, `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `DEFINITIVELY_LLM_COMMAND` | Stub in dev | Override default LLM runner (space-separated argv prefix) |
| `DEFINITIVELY_FROM_SOURCE` | unset | When `1`, devenv builds escript from `definitively/` on shell enter |

Copy hints from `.definitively/env.example` after `definitively init`.

## Logging

Set log level before running workflows:

```bash
export DEFINITIVELY_LOG_LEVEL=DEBUG
definitively run "$PWD/.definitively/programs/example.yml"
```

Trace-level logs show validation, node execution, and transition details.
