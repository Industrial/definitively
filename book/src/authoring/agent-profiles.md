# Agent profiles

LLM nodes invoke an external agent CLI (Cursor, OpenCode, a stub runner, etc.). Instead of inlining a long `command` argv in every program, definitively loads **agent profiles** from `.definitively/agents/<id>.yml`.

## Profile selection

Each LLM node declares exactly one of:

| Field | Description |
|-------|-------------|
| `agent: cursor` | Load `.definitively/agents/cursor.yml` |
| `command: [argv, …]` | Raw argv prefix (legacy / custom runners) |

When a node omits `agent`, the default profile id comes from `DEFINITIVELY_AGENT` (commonly `cursor`).

## Example profile

```yaml
agent:
  id: cursor
  executable: cursor-agent
  executable_env: DEFINITIVELY_AGENT_CURSOR_EXECUTABLE
  argv:
    - agent
    - --force
    - --model
    - "{{model}}"
    - --workspace
    - "."
    - --print
    - --output-format
    - stream-json
    - --
  prompt:
    mode: argv_after_delimiter
  output:
    format: stream_json
    extract: last_json_line
    envelope_path: result
    success_status: ok
```

## Schema (v1)

| Field | Required | Description |
|-------|----------|-------------|
| `agent.id` | yes | Profile id (matches filename) |
| `executable` | one of | Binary name on PATH |
| `executable_env` | one of | Env var holding absolute path to binary |
| `argv` | no | Fixed argv prefix before the prompt |
| `prompt.mode` | yes | `argv_after_delimiter`, `flag`, or `stdin` |
| `prompt.flag` | when `flag` | Flag name before prompt text |
| `output.format` | yes | `stream_json`, `json`, or `text` |
| `output.extract` | yes | `last_json_line` or `whole_stdout` |
| `output.envelope_path` | no | Dot-path to unwrap JSON envelope (e.g. `result`) |
| `output.success_status` | no | Expected `status` field in parsed JSON (default `ok`) |

The builder interpolates `{{model}}` in argv from the node's `model` field (default `auto`).

## Prompt delivery

| Mode | Behavior |
|------|----------|
| `argv_after_delimiter` | Append prompt after `--` (or replace trailing `--`) |
| `flag` | Append `[flag, prompt]` to argv |
| `stdin` | Pass prompt on subprocess stdin |

## Output parsing

The executor reads stdout and parses it according to `output.format`:

- **stream_json** — NDJSON lines; take the last JSON object (or unwrap via `envelope_path`)
- **json** — whole stdout is one JSON object
- **text** — raw stdout string

Outcome rules on the node (e.g. `jq: '.status == "ok"'`) run against the parsed value.

## Scaffolding

`definitively init` copies `agents/cursor.yml` into your workspace. Customize or add profiles for other harnesses.

**Try it:** Copy the example above to `.definitively/agents/stub.yml`, set `DEFINITIVELY_AGENT=stub`, and point `executable` at a test script.
