# GitHub (`gh`) nodes

GitHub CLI nodes automate pull requests and Actions workflows. Like git nodes, they use structured `action` and `options` instead of raw shell commands.

## Example

```yaml
nodes:
  open_pr:
    kind: gh
    action: pr_create
    options:
      title: "Automated PR"
      body: "Opened by definitively"
    outcome:
      success:
        - exit_code: 0
      failure:
        - exit_code: {neq: 0}

  watch_ci:
    kind: gh
    action: run_watch
    options:
      workflow: definitively-ci.yml
    timeout_ms: 900000
    outcome:
      success:
        - exit_code: 0
      failure:
        - exit_code: {neq: 0}
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `kind` | yes | Must be `gh` |
| `action` | yes | GitHub CLI operation (see table below) |
| `options` | no | Action-specific parameters |
| `timeout_ms` | no | Default 900000 ms for long CI watches |
| `outcome` | yes | Outcome rules — see [Outcome rules](./outcomes.md) |

## Actions

| Action | Purpose | Key options |
|--------|---------|-------------|
| `pr_create` | Open a pull request | `title`, `body`, `base`, `head`, `draft` |
| `pr_view` | Inspect PR state | `number` or `branch` |
| `run_list` | List recent workflow runs | `workflow`, `branch`, `limit` |
| `run_watch` | Wait until CI finishes | `run_id` or `workflow` (+ optional `branch`) |
| `run_view` | Run metadata and logs | `run_id`, `log_failed` |

### `run_watch`

When `workflow` is set (without `run_id`), definitively lists the latest matching run and then invokes `gh run watch --exit-status`. Set a generous `timeout_ms` for long CI jobs.

## Structured data and jq

Gh actions that return JSON populate `data` on the raw result. Use `jq` predicates in outcome rules:

```yaml
outcome:
  success:
    - jq: '.conclusion == "success"'
  failure:
    - exit_code: {neq: 0}
```

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) on PATH
- Authenticate: `gh auth login` or set `GH_TOKEN` in the environment

## Node catalog

Copy-paste fragments from `.definitively/nodes/gh.yml` (installed via `definitively init`).

**Try it:** Wire `run_watch` after a `push` node to gate on CI green before a final state.
