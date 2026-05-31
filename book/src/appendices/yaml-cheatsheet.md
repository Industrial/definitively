# YAML schema cheat sheet

```yaml
program:
  id: string          # required
  version: integer    # required
  initial: state_name # required

states:
  <name>:
    type: passive | active | final
    node: <node_id>   # required when type: active
    on:
      <outcome_label>: <next_state>

nodes:
  <id>:
    kind: cli | llm
    command: [argv, ...]
    cwd: path
    timeout_ms: integer
    model: string       # llm
    prompt_file: path   # llm
    outcome:
      success: [predicates]
      failure: [predicates]
      partial: [predicates]
      retry: [predicates]

# Predicates (each list item is one of):
#   exit_code: 0
#   exit_code: {neq: 0}
#   timeout: true
#   signal: name
#   jq: '.field == "value"'
```
