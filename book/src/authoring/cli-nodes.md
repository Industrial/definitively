# CLI nodes

```yaml
nodes:
  moon_lint:
    kind: cli
    command: ["moon", "run", "definitively:lint"]
    timeout_ms: 300000
    outcome:
      success:
        - exit_code: 0
      failure:
        - exit_code: {neq: 0}
      partial:
        - exit_code: 0
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `kind` | yes | Must be `cli` |
| `command` | yes | argv list (no shell unless you invoke `sh -c`) |
| `timeout_ms` | no | Kill subprocess after this many milliseconds |
| `cwd` | no | Working directory (default: workspace root) |
| `outcome` | yes | Outcome rules — see [Outcome rules](./outcomes.md) |

## Tips

- Prefer argv lists over shell strings for clarity and safety.
- Set `timeout_ms` on long-running commands (tests, builds).
- Map both `failure` and `partial` when you want fix loops on non-zero exits.

**Try it:** Add a CLI node that runs `git status` and routes on exit code.
