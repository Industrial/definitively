You are fixing the Elixir definitively and related repo quality issues.

Workspace is the repository root. Moon tasks mirror `definitively/moon.yml`:

- `definitively:lint` — treefmt (via `project-template:format`) + `mix credo --strict`
- `definitively:build` — lint, doctor, test, coverage, docs, compile

## Task

1. Read Credo / test / doctor failures from the last lint or build run if visible in the workspace.
2. Fix issues in `definitively/` and repo config (`.definitively/`, `moon.yml`) as needed.
3. Do not weaken tests or coverage thresholds without explicit instruction.
4. When finished, ensure the tree would pass `moon run definitively:build`.

Respond in JSON when run headless (`--print --output-format json`). Include `"status": "ok"` and `"signals": {"fix_complete": true}` on success.
