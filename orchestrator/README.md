# Orchestrator

FSM-based workflow runner for CLI commands, LLM sessions, and git steps.

States are implemented with OTP `:gen_statem` in `Orchestrator.Workflow.Engine`.
Node evaluators return `Orchestrator.Outcome` values (not raw exit codes).

Full distribution guide (consumer devenv, all install channels, workspace layout): [orchestrator-distribution.md](https://github.com/Industrial/definitively/blob/main/docs/orchestrator-distribution.md).

## Installation

Pick one channel. All ship the same `orchestrator` escript CLI.

### devenv flake input (recommended for Nix/devenv repos)

Add the repo as a flake input and import its devenv module (provides `orchestrator` + `graphviz` on PATH):

```yaml
# devenv.yaml
inputs:
  orchestrator-repo:
    url: github:OWNER/REPO  # or url: . / inputs.repo when developing in-tree
    flake: true
```

```nix
# devenv.nix
{ inputs, ... }: {
  imports = [
    inputs.orchestrator-repo.devenvModules.orchestrator
  ];
}
```

Then `devenv shell` — the `orchestrator` binary is on PATH.

When developing the Mix project inside this repo, set `ORCHESTRATOR_FROM_SOURCE=1` before `devenv shell` to build the escript from `orchestrator/` on enter instead of using the flake package.

### Nix flake

From a checkout (or after adding the repo as a flake input):

```bash
nix build github:OWNER/REPO#orchestrator
./result/bin/orchestrator --help  # via usage on unknown args
```

Or from the repo root: `nix build .#orchestrator`.

### Hex

When published on Hex:

```bash
mix local.hex --force
mix escript.install hex orchestrator --force
export PATH="$(mix escript.install_path):$PATH"
```

Requires Elixir ~> 1.18 and Erlang/OTP 27+ on PATH. Add `$HOME/.mix/escripts` to `PATH` if needed.

### GitHub releases (curl installer)

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a version:

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash -s -- --version orchestrator-v0.1.0
```

Release tarballs are named `orchestrator-<version>-<platform>.tar.gz` (platforms: `linux-x86_64`, `darwin-arm64`). See [GitHub releases](https://github.com/Industrial/definitively/releases).

### Homebrew tap

```bash
brew tap idcleartomwieland/tap https://github.com/idcleartomwieland/homebrew-tap
brew install orchestrator
```

Or install the formula directly:

```bash
brew install --formula https://raw.githubusercontent.com/Industrial/definitively/main/homebrew-tap/Formula/orchestrator.rb
```

## Runtime dependencies

| Tool | Required? | Used by |
|------|-----------|---------|
| Erlang/OTP 27+ | Yes (Hex/source installs) | escript interpreter; bundled/wrapped by the Nix flake package |
| Elixir 1.18+ | Build only (Hex/source) | `mix escript.build` / `mix escript.install` |
| Graphviz `dot` | Optional | `orchestrator visualize` default mode (PNG output); DOT-only works without `dot` |
| `moon` | Optional | CLI nodes in programs that invoke `moon run …` |
| `cursor-agent` | Optional | LLM nodes (e.g. dev quality loop fix steps) |
| `git` | Optional | CLI nodes that run git commands in your program YAML |

The devenv module adds `orchestrator` and `graphviz`. Other tools are workflow-specific — see your program YAML and [`.orchestrator/env.example`](../.orchestrator/env.example).

## Workspace layout

Programs must live under a `.orchestrator/` directory. The workspace root is the **parent** of `.orchestrator/` (override with `ORCHESTRATOR_WORKSPACE`).

Scaffold a new workspace from packaged templates:

```bash
cd /path/to/your/repo
orchestrator init              # copies into ./.orchestrator/ (skips existing files)
orchestrator init --force      # overwrite existing template files
```

Templates include `programs/example.yml`, `prompts/example.md`, `env.example`, and `visualizations/.gitkeep`.

## CLI

Set `ORCHESTRATOR_LOG_LEVEL` (`TRACE` … `ERROR`, default `INFO`) for run visibility.

### Run a workflow

Pass the **full path** to a program YAML under `.orchestrator/`:

```bash
orchestrator run "$PWD/.orchestrator/programs/dev-quality-loop.yml"
```

On success prints `workflow finished` and exits 0. Approval gates that cannot auto-approve exit 2.

### Visualize a program

Default mode writes **both** DOT and PNG under `.orchestrator/visualizations/<program-basename>` and prints the output paths:

```bash
orchestrator visualize "$PWD/.orchestrator/programs/dev-quality-loop.yml"
# → .orchestrator/visualizations/dev-quality-loop.dot
# → .orchestrator/visualizations/dev-quality-loop.png
```

Single-format overrides:

```bash
orchestrator visualize program.yml --format dot
orchestrator visualize program.yml --format png --out /tmp/my-workflow
orchestrator visualize program.yml --format svg
```

`--format png` or `svg` requires Graphviz `dot` on PATH. If PNG compilation fails, DOT is still written when using default mode.

### Mix task (contributors)

Inside `orchestrator/`:

```bash
mix orchestrator run ../.orchestrator/programs/dev-quality-loop.yml
```

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

Build the escript locally (also run automatically when `ORCHESTRATOR_FROM_SOURCE=1`):

```bash
cd orchestrator && mix escript.build
export PATH="$(pwd):$PATH"
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

## Module layout

```
lib/orchestrator/
  outcome.ex           # NodeResult / status
  workflow/engine.ex   # data-driven gen_statem FSM
  nodes/               # CLI and LLM evaluators
  init.ex              # .orchestrator/ workspace scaffold
  visualize.ex         # Graphviz program graphs
  cli.ex               # CLI entry (escript + Mix task)
```
