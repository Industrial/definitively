# Migrating from orchestrator

The product was renamed from **orchestrator** to **definitively** in v0.2.0.

| Before | After |
|--------|-------|
| CLI `orchestrator` | `definitively` |
| `.orchestrator/` | `.definitively/` |
| Hex `orchestrator` | `definitively` |
| Tags `orchestrator-v*` | `definitively-v*` |
| `ORCHESTRATOR_WORKSPACE` | `DEFINITIVELY_WORKSPACE` |
| Moon `orchestrator:*` | `definitively:*` |

## Steps

1. Install definitively v0.2.0+
2. Rename `.orchestrator/` → `.definitively/`
3. Update program YAML paths and any scripts referencing the old CLI name
4. Update CI/release tags to `definitively-v*`
