# LLM nodes

```yaml
nodes:
  llm_fix_lint:
    kind: llm
    agent: cursor
    model: auto
    prompt_file: .definitively/prompts/fix-lint.md
    timeout_ms: 3600000
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
| `agent` | one of | Profile id under `.definitively/agents/` |
| `command` | one of | Raw argv prefix (mutually exclusive with `agent`) |
| `model` | no | Model hint passed to the agent profile (`{{model}}` interpolation) |
| `timeout_ms` | no | Session timeout |
| `outcome` | yes | Often uses `jq` on parsed agent output and `signal` predicates |

Exactly one of `agent` or `command` is required. Prefer `agent` — see [Agent profiles](./agent-profiles.md).

## Prompt files

Store prompts under `.definitively/prompts/`. Reference them by path in `prompt_file`.

The dev quality loop uses one prompt per fix step (`fix-lint.md`, `fix-test.md`, etc.).

## Default agent

Set `DEFINITIVELY_AGENT=cursor` (or another profile id) when nodes omit `agent`. Override the binary path via profile `executable_env` — see [Environment variables](../workspace/environment.md).

**Try it:** Copy `prompts/example.md` from templates, wire a minimal LLM node with `agent: cursor`, and run against a stub profile in dev if no agent is installed.
