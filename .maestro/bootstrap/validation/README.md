# Validation Scripts

Reusable verification entry points for maestro agents.

| Script | Program | When |
|--------|---------|------|
| `verify-fast.sh` | `pre-commit-gate.yml` | During iteration; matches pre-commit hook |
| `verify-gate.sh` | `pre-push-gate.yml` | Pre-ship; matches pre-push hook + CI parity |

Both set `DEFINITIVELY_WORKSPACE` to the git root and invoke `definitively run`.

Record evidence after a successful full gate:

```bash
maestro evidence record --task <id> --command ".maestro/bootstrap/validation/verify-gate.sh" --exit 0
```

See `.maestro/docs/VALIDATION_LADDER.md` and `.maestro/docs/DEFINITIVELY_INTEGRATION.md`.
