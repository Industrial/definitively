# Commands and flags

```text
definitively version
definitively --version
  # or: definitively -V
definitively init [--force]
definitively run </full/path/to/program.yml> [--input-flag value ...]
definitively run --help </full/path/to/program.yml>
definitively visualize </full/path/to/program.yml> [--format dot|png|svg] [--out <basename>]
```


## `version`

Prints the installed package version (from `mix.exs` / OTP application spec).

```bash
definitively version
definitively --version   # same output
definitively -V           # same output
```

Example output: `definitively 0.5.0`

## `init`

Copies packaged templates into `.definitively/` under the workspace.

| Flag | Description |
|------|-------------|
| `--force` | Overwrite existing template files |

Workspace root: current directory or `DEFINITIVELY_WORKSPACE`.

## `run`

Executes a program synchronously.

| Requirement | Detail |
|-------------|--------|
| Program path | Full path to YAML under `.definitively/` |
| Input flags | Declared under `program.inputs` (e.g. `--plan-file path`) |
| Success output | Prints `workflow finished` |
| Exit 0 | Run reached a final state successfully |
| Exit 1 | Load error, execution error, or workflow failure |
| Exit 2 | Stuck at approval gate without auto label |

Use `definitively run --help <program.yml>` to list declared inputs without executing.

## `visualize`

Renders program structure as Graphviz. See [Visualizing workflows](../patterns/visualizing.md).

## Mix task (contributors)

Inside `definitively/`:

```bash
mix definitively run ../.definitively/programs/example.yml
```

## Environment

See [Environment variables](../workspace/environment.md).
