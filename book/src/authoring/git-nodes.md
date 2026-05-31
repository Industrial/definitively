# Git nodes

Git nodes run structured git operations without shell wrappers. Declare an `action` and optional `options`; definitively builds the git argv, runs the command, and parses output into **signals** and **data**.

## Example

```yaml
nodes:
  repo_status:
    kind: git
    action: status
    outcome:
      success:
        - signal: clean
      partial:
        - signal: dirty

  ship_commit:
    kind: git
    action: commit
    options:
      message: "chore: ship"
      add: all
    outcome:
      success:
        - exit_code: 0
      failure:
        - exit_code: {neq: 0}
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `kind` | yes | Must be `git` |
| `action` | yes | Git operation (see table below) |
| `options` | no | Action-specific parameters |
| `cwd` | no | Working directory (default: workspace root) |
| `timeout_ms` | no | Subprocess timeout |
| `outcome` | yes | Outcome rules — see [Outcome rules](./outcomes.md) |

## Actions

| Action | Purpose | Options | Signals / data |
|--------|---------|---------|----------------|
| `status` | Working tree snapshot | — | `clean`, `dirty`, `ahead`, `behind` |
| `diff` | Show changes | `staged`, `stat` | `has_changes` |
| `add` | Stage files | `all: true` or `paths: [...]` | exit code |
| `commit` | Create commit | `message`, `add`, `amend`, `allow_empty` | exit code |
| `push` | Push refs | `remote`, `branch`, `tags`, `set_upstream` | exit code |
| `tag` | Create tag | `name`, `message`, `annotate`, `push` | exit code |

The `commit` action accepts `add: all` or `add: [paths]` to stage before committing in one node.

## Prerequisites

- `git` on PATH
- For `commit`/`tag`: configure `user.name` and `user.email` in the repo

## Node catalog

Copy-paste fragments from `.definitively/nodes/git.yml` (installed via `definitively init`).

**Try it:** Add a `status` node to a program and route `partial` (dirty) to a `commit` node.
