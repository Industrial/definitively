# Orchestrator

FSM-based workflow runner for CLI commands, LLM sessions, and git steps.

States are implemented with OTP `:gen_statem` in `Orchestrator.Workflow.Engine`.
Node evaluators return `Orchestrator.Outcome` values (not raw exit codes).

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

## Quality gates (moon)

From the repo root (devenv shell):

```bash
moon run orchestrator:format orchestrator:compile orchestrator:lint orchestrator:test
```

These run on `git commit` (pre-commit) and `git push` (pre-push) with the Rust workspace gates.
iex -S mix
```

Toolchain: Erlang/OTP 27 + Elixir 1.18 (pinned in `devenv.nix`).

## Planned layout

```
lib/orchestrator/
  outcome.ex           # NodeResult / status
  workflow/engine.ex   # gen_statem FSM
  nodes/               # CLI, LLM, git evaluators (TBD)
  cli.ex               # escript / main entry (TBD)
```
