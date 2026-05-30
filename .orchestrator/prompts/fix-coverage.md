The `moon run orchestrator:coverage` gate failed.

See [orchestrator/moon.yml](../../orchestrator/moon.yml) for what this task runs and its dependencies.

Fix the failure in `orchestrator/` (and repo config if needed). Target passing `moon run orchestrator:coverage`.

Respond with JSON: `{"status":"ok","signals":{"fix_complete":true}}` on success.
