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


## v0.4.0 — agent profiles and program inputs

| Before | After |
|--------|-------|
| Inlined `cursor-agent` argv in every LLM node | `agent: cursor` + `.definitively/agents/cursor.yml` |
| `DEFINITIVELY_CURSOR_AGENT` | Profile `executable_env` (e.g. `DEFINITIVELY_AGENT_CURSOR_EXECUTABLE`) |
| `DEFINITIVELY_PLAN_FILE` env | `--plan-file` CLI flag on `definitively run` |
| `DEFINITIVELY_LLM_COMMAND` | Agent profiles or per-node `command:` |

### Steps

1. Upgrade to definitively v0.4.0+
2. Run `definitively init` (or copy `agents/cursor.yml` manually)
3. Replace LLM node `command:` blocks with `agent: cursor` (or keep raw `command:` for custom runners)
4. Add `program.inputs` and pass values via CLI flags instead of env vars
5. Remove `DEFINITIVELY_CURSOR_AGENT` from shell hooks and `.env` files
