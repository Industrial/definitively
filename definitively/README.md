# Definitively

FSM-based workflow runner for CLI commands, LLM sessions, and git steps.

States are implemented with OTP `:gen_statem` in `Definitively.Workflow.Engine`.
Node evaluators return `Definitively.Outcome` values (not raw exit codes).

Full distribution guide (consumer devenv, all install channels, workspace layout): [definitively-distribution.md](https://github.com/Industrial/definitively/blob/main/docs/definitively-distribution.md).

## Installation

Pick one channel. All ship the same `definitively` escript CLI.

### devenv flake input (recommended for Nix/devenv repos)

Add the repo as a flake input and import its devenv module (provides `definitively` + `graphviz` on PATH):

```yaml
# devenv.yaml
inputs:
  definitively-repo:
    url: github:OWNER/REPO  # or url: . / inputs.repo when developing in-tree
    flake: true
```

```nix
# devenv.nix
{ inputs, ... }: {
  imports = [
    inputs.definitively-repo.devenvModules.definitively
  ];
}
```

Then `devenv shell` — the `definitively` binary is on PATH.

When developing the Mix project inside this repo, set `DEFINITIVELY_FROM_SOURCE=1` before `devenv shell` to build the escript from `definitively/` on enter instead of using the flake package.

### Nix flake

From a checkout (or after adding the repo as a flake input):

```bash
nix build github:OWNER/REPO#definitively
./result/bin/definitively --help  # via usage on unknown args
```

Or from the repo root: `nix build .#definitively`.

### Hex

When published on Hex:

```bash
mix local.hex --force
mix escript.install hex definitively --force
export PATH="$(mix escript.install_path):$PATH"
```

Requires Elixir ~> 1.18 and Erlang/OTP 27+ on PATH. Add `$HOME/.mix/escripts` to `PATH` if needed.

### GitHub releases (curl installer)

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a version:

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash -s -- --version definitively-v0.1.0
```

Release tarballs are named `definitively-<version>-<platform>.tar.gz` (platforms: `linux-x86_64`, `darwin-arm64`). See [GitHub releases](https://github.com/Industrial/definitively/releases).

### Homebrew tap

```bash
brew tap idcleartomwieland/tap https://github.com/idcleartomwieland/homebrew-tap
brew install definitively
```

Or install the formula directly:

```bash
brew install --formula https://raw.githubusercontent.com/Industrial/definitively/main/homebrew-tap/Formula/definitively.rb
```

## Runtime dependencies

| Tool | Required? | Used by |
|------|-----------|---------|
| Erlang/OTP 27+ | Yes (Hex/source installs) | escript interpreter; bundled/wrapped by the Nix flake package |
| Elixir 1.18+ | Build only (Hex/source) | `mix escript.build` / `mix escript.install` |
| Graphviz `dot` | Optional | `definitively visualize` default mode (PNG output); DOT-only works without `dot` |
| `moon` | Optional | CLI nodes in programs that invoke `moon run …` |
| `cursor-agent` | Optional | LLM nodes (e.g. dev quality loop fix steps) |
| `git` | Optional | CLI nodes that run git commands in your program YAML |

The devenv module adds `definitively` and `graphviz`. Other tools are workflow-specific — see your program YAML and [`.definitively/env.example`](../.definitively/env.example).

## Workspace layout

Programs must live under a `.definitively/` directory. The workspace root is the **parent** of `.definitively/` (override with `DEFINITIVELY_WORKSPACE`).

Scaffold a new workspace from packaged templates:

```bash
cd /path/to/your/repo
definitively init              # copies into ./.definitively/ (skips existing files)
definitively init --force      # overwrite existing template files
```

Templates include `programs/example.yml`, `prompts/example.md`, `env.example`, and `visualizations/.gitkeep`.

## CLI

Set `DEFINITIVELY_LOG_LEVEL` (`TRACE` … `ERROR`, default `INFO`) for run visibility.

### Run a workflow

Pass the **full path** to a program YAML under `.definitively/`:

```bash
definitively run "$PWD/.definitively/programs/dev-quality-loop.yml"
```

On success prints `workflow finished` and exits 0. Approval gates that cannot auto-approve exit 2.

### Visualize a program

Default mode writes **both** DOT and PNG under `.definitively/visualizations/<program-basename>` and prints the output paths:

```bash
definitively visualize "$PWD/.definitively/programs/dev-quality-loop.yml"
# → .definitively/visualizations/dev-quality-loop.dot
# → .definitively/visualizations/dev-quality-loop.png
```

Single-format overrides:

```bash
definitively visualize program.yml --format dot
definitively visualize program.yml --format png --out /tmp/my-workflow
definitively visualize program.yml --format svg
```

`--format png` or `svg` requires Graphviz `dot` on PATH. If PNG compilation fails, DOT is still written when using default mode.

### Mix task (contributors)

Inside `definitively/`:

```bash
mix definitively run ../.definitively/programs/dev-quality-loop.yml
```

## Development (devenv)

From the repo root:

```bash
devenv shell
mix-setup    # first time: hex, rebar, deps
mix-test     # ExUnit
```

Inside `definitively/`:

```bash
mix test
mix format
iex -S mix
```

Build the escript locally (also run automatically when `DEFINITIVELY_FROM_SOURCE=1`):

```bash
cd definitively && mix escript.build
export PATH="$(pwd):$PATH"
```

## Quality gates (moon)

From the repo root (devenv shell):

```bash
moon run definitively:lint definitively:doctor definitively:test definitively:docs definitively:build
```

| Task | What it checks |
|------|----------------|
| `definitively:lint` | Credo `--strict` |
| `definitively:doctor` | `@moduledoc` / `@doc` / `@spec` coverage (see `.doctor.exs`) |
| `definitively:test` | ExUnit + doctests |
| `definitively:docs` | ExDoc build with `--warnings-as-errors` |
| `definitively:build` | Full chain + `mix compile --warnings-as-errors` |

**Git hooks:** pre-commit runs `:format` + `definitively:doctor`; pre-push runs `:format` + `definitively:build` (tests, coverage, ExDoc, compile).

Generate HTML docs locally: `cd definitively && mix docs` → `doc/index.html`.

Toolchain: Erlang/OTP 27 + Elixir 1.18 (pinned in `devenv.nix`).

## Module layout

```
lib/definitively/
  outcome.ex           # NodeResult / status
  workflow/engine.ex   # data-driven gen_statem FSM
  nodes/               # CLI and LLM evaluators
  init.ex              # .definitively/ workspace scaffold
  visualize.ex         # Graphviz program graphs
  cli.ex               # CLI entry (escript + Mix task)
```
