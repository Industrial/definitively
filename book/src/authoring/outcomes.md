# Outcome rules

Outcome rules classify raw node results into **labels**. The engine uses the first matching label, then transitions via the state's `on:` map.

## Structure

```yaml
outcome:
  success:
    - exit_code: 0
  failure:
    - exit_code: {neq: 0}
  partial:
    - exit_code: 0
```

Each label maps to a **list of predicates**. All predicates in a clause must match (AND). The first matching label wins.

## Predicates

| Predicate | Example | Matches when |
|-----------|---------|--------------|
| `exit_code` | `0` | Exit code equals integer |
| `exit_code` | `{neq: 0}` | Exit code not equal |
| `timeout` | `true` | Subprocess timed out |
| `signal` | `fix_complete` | Named signal is truthy in result |
| `jq` | `'.status == "ok"'` | JSON field matches (LLM output) |

## Labels and status

| Label | Internal status | Typical use |
|-------|-----------------|-------------|
| `success` | `:success` | Continue happy path |
| `failure` | `:failure` | Error or fix loop |
| `partial` | `:partial` | Recoverable incomplete work |
| `retry` | `:failure` | Explicit retry transition key |

If no label matches, the outcome is **unknown** and the run may error.

**Try it:** Run a CLI node with a failing command and confirm the `failure` transition fires.
