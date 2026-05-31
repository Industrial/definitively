# Program structure

Every program YAML has three top-level keys:

```yaml
program:
  id: my_workflow
  version: 1
  initial: idle

states:
  # state_name: { type, node?, on: { label: next_state } }

nodes:
  # node_id: { kind, command?, outcome: { ... } }
```

## `program` block

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Stable identifier (atom in Elixir) |
| `version` | yes | Integer schema version |
| `initial` | yes | Name of the starting state |

## `states` block

Map of state names to definitions. See [States and transitions](./states.md).

## `nodes` block

Map of node IDs to definitions. Active states reference nodes by ID. See [CLI nodes](./cli-nodes.md) and [LLM nodes](./llm-nodes.md).

## Minimal example

```yaml
program:
  id: example
  version: 1
  initial: idle
states:
  idle:
    type: passive
    on:
      start: run
  run:
    type: active
    node: echo
    on:
      success: done
  done:
    type: final
nodes:
  echo:
    kind: cli
    command: ["sh", "-c", "exit 0"]
    outcome:
      success:
        - exit_code: 0
      failure:
        - exit_code: {neq: 0}
```

**Try it:** Validate structure by running `definitively run` — load errors print before execution starts.
