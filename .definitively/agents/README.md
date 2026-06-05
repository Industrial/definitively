# Agent profiles

LLM nodes resolve their subprocess from YAML files in this directory. Each profile
defines executable resolution, argv, prompt delivery, and stdout parsing.

## Authoring

1. Copy `example.yml` to `<id>.yml` (filename must match `agent.id`).
2. Set `executable` or `executable_env` for binary resolution.
3. Choose a `prompt.mode`: `argv_after_delimiter`, `flag`, or `stdin`.
4. Configure `output.format`: `stream_json`, `json`, or `text`.

Reference the shipped `cursor.yml` for a real harness profile, or use `example.yml`
as a no-agent stub for local testing.

See the book chapter [Agent profiles](https://industrial.github.io/definitively/authoring/agent-profiles.html).
