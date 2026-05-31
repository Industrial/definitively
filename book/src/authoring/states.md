# States and transitions

## State types

| Type | Behavior |
|------|----------|
| `passive` | Waits for an external transition label (e.g. approval) |
| `active` | Runs the referenced **node** when entered |
| `final` | Terminal state; ends the run |

## Active states

Must declare `node: <node_id>` matching a key in `nodes:`.

```yaml
lint:
  type: active
  node: moon_lint
  on:
    success: doctor
    failure: fix_lint
    partial: fix_lint
```

## Transitions (`on:`)

Each key is an **outcome label** from the node's outcome rules. Each value is the **next state name**.

Common labels:

- `success` — primary happy path
- `failure` — hard failure
- `partial` — incomplete but recoverable (often routes to a fix state)
- `retry` — explicit retry loop (classified as failure internally, but used as transition key)

## Initial and final states

- `program.initial` must name an existing state.
- At least one `type: final` state is required.
- At least one final state must be reachable from `initial` (validated at load time).

## Passive states

Used for approval gates or manual triggers. The engine transitions when a label is supplied (e.g. auto-approve in tests).

**Try it:** Draw your state graph with `definitively visualize program.yml`.
