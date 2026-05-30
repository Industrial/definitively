# Orchestrator

FSM-based workflow runner for CLI commands, LLM sessions, and git steps.

States are implemented with OTP `:gen_statem` in `Orchestrator.Workflow.Engine`.
Node evaluators return `Orchestrator.Outcome` values (not raw exit codes).

## CLI (product)

Build the escript (devenv does this on shell enter):

```bash
cd orchestrator && mix escript.build
export PATH="$(pwd):$PATH"
```

Run a workflow by **full path** to the program YAML:

```bash
orchestrator run "$PWD/../.orchestrator/programs/dev-quality-loop.yml"
```

Workspace root is the parent of `.orchestrator/`. Override with `ORCHESTRATOR_WORKSPACE` if needed.

Set `ORCHESTRATOR_LOG_LEVEL` (`TRACE` … `ERROR`, default `INFO`) for run visibility.


## Visualize a program

Render the workflow graph (Graphviz DOT by default):

```bash
orchestrator visualize "$PWD/../.orchestrator/programs/dev-quality-loop.yml"
orchestrator visualize program.yml --format png --out /tmp/dev-quality-loop
```

Requires the `dot` binary for `--format png` or `svg`.

## Development (devenv)


From the repo root:

```bash
devenv shell
mix-setup    # first time: hex, rebar, deps
mix-test     # ExUnit
```

Inside `orchestrator/`:

```bash
mix test
mix format
iex -S mix
```

## Quality gates (moon)

From the repo root (devenv shell):

```bash
moon run orchestrator:lint orchestrator:doctor orchestrator:test orchestrator:docs orchestrator:build
```

| Task | What it checks |
|------|----------------|
| `orchestrator:lint` | Credo `--strict` |
| `orchestrator:doctor` | `@moduledoc` / `@doc` / `@spec` coverage (see `.doctor.exs`) |
| `orchestrator:test` | ExUnit + doctests |
| `orchestrator:docs` | ExDoc build with `--warnings-as-errors` |
| `orchestrator:build` | Full chain + `mix compile --warnings-as-errors` |

**Git hooks:** pre-commit runs `:format` + `orchestrator:doctor`; pre-push runs `:format` + `orchestrator:build` (tests, coverage, ExDoc, compile).

Generate HTML docs locally: `cd orchestrator && mix docs` → `doc/index.html`.

Toolchain: Erlang/OTP 27 + Elixir 1.18 (pinned in `devenv.nix`).

## Planned layout

```
lib/orchestrator/
  outcome.ex           # NodeResult / status
  workflow/engine.ex   # gen_statem FSM
  nodes/               # CLI, LLM, git evaluators (TBD)
  cli.ex               # CLI entry (escript + Mix task)
```
