# LLM nodes

```yaml
nodes:
  llm_fix_lint:
    kind: llm
    model: auto
    prompt_file: .definitively/prompts/fix-lint.md
    timeout_ms: 3600000
    command:
      - cursor-agent
      - agent
      - --force
      - --workspace
      - "."
      - --print
      - --output-format
      - stream-json
      - --
    outcome:
      success:
        - jq: '.status == "ok"'
        - signal: fix_complete
      failure:
        - timeout: true
        - signal: refused
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `kind` | yes | Must be `llm` |
| `prompt_file` | yes | Path to markdown prompt (relative to workspace root) |
| `command` | yes | argv prefix for the LLM runner; prompt appended after `--` |
| `model` | no | Model hint passed to runner |
| `timeout_ms` | no | Session timeout |
| `outcome` | yes | Often uses `jq` on stream JSON and `signal` predicates |

## Prompt files

Store prompts under `.definitively/prompts/`. Reference them by path in `prompt_file`.

The dev quality loop uses one prompt per fix step (`fix-lint.md`, `fix-test.md`, etc.).

**Try it:** Copy `prompts/example.md` from templates and wire a minimal LLM node (use stub runner in dev if no agent installed).
