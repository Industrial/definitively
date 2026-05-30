# Orchestrator distribution guide

How to install the `orchestrator` CLI in consumer projects and set up a `.orchestrator/` workspace.

Product overview and contributor docs: [`orchestrator/README.md`](../orchestrator/README.md).

Replace `OWNER/REPO` below with the GitHub repository that publishes orchestrator (e.g. `github:your-org/test-haskell-web`).

## Consumer devenv setup

Add the orchestrator repo as a **flake input**, then import its devenv module. The module puts `orchestrator` and Graphviz on PATH.

### `devenv.yaml`

Using a GitHub URL:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  orchestrator-repo:
    url: github:OWNER/REPO
    flake: true
```

When orchestrator lives in the same monorepo you are developing (this repository's pattern):

```yaml
inputs:
  repo:
    url: .
    flake: true
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
```

### `devenv.nix`

External consumer:

```nix
{ inputs, pkgs, ... }: {
  imports = [
    inputs.orchestrator-repo.devenvModules.orchestrator
  ];

  # Optional: pin workspace for orchestrator runs from this repo root
  enterShell = ''
    export ORCHESTRATOR_WORKSPACE="$DEVENV_ROOT"
  '';
}
```

In-tree (same repo as orchestrator):

```nix
{ inputs, pkgs, ... }: {
  imports = [
    inputs.repo.devenvModules.orchestrator
  ];

  enterShell = ''
    export ORCHESTRATOR_WORKSPACE="$DEVENV_ROOT"
  '';
}
```

Run `devenv shell` (or `direnv allow`) and verify:

```bash
which orchestrator
orchestrator init
```

### Building from source inside devenv

Contributors working on the Mix app can force a local escript build on shell enter:

```bash
export ORCHESTRATOR_FROM_SOURCE=1
devenv shell
```

This runs `mix escript.build` in `orchestrator/` and prepends that directory to `PATH` instead of using the flake-built package.

## Install channels

All channels install the same escript entrypoint (`Orchestrator.CLI`). Pick one.

| Channel | Best for | Notes |
|---------|----------|-------|
| **devenv module** | Teams already on devenv/Nix | `inputs.<repo>.devenvModules.orchestrator`; includes `graphviz` |
| **Nix flake** | CI, reproducible installs | `nix build github:OWNER/REPO#orchestrator`; wraps Erlang on PATH |
| **Hex** | Elixir developers | `mix escript.install hex orchestrator --force` |
| **GitHub releases** | Quick download, no Nix/Hex | Platform escript artifacts attached to release tags |
| **Homebrew tap** | macOS/Linux Homebrew users | Third-party or org tap formula |

### devenv flake input

See [Consumer devenv setup](#consumer-devenv-setup) above.

The module definition lives at `nix/devenv-module.nix` and exposes:

- `inputs.repo.packages.${system}.orchestrator` (flake package)
- `pkgs.graphviz` (`dot` for visualize PNG/SVG)

### Nix flake

Build and run from a checkout:

```bash
nix build .#orchestrator
./result/bin/orchestrator init
```

Build from a pinned GitHub flake (no local checkout):

```bash
nix build github:OWNER/REPO#orchestrator
```

The derivation is defined in `nix/orchestrator.nix` (Elixir 1.18 / OTP 27, prod escript, Erlang wrapped on PATH).

### Hex

When the `:orchestrator` package is published:

```bash
mix local.hex --force
mix escript.install hex orchestrator --force
export PATH="$(mix escript.install_path):$PATH"
```

Requires Elixir ~> 1.18 and Erlang/OTP 27+ installed locally.

### GitHub releases (curl installer)

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a release:

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash -s -- --version orchestrator-v0.1.0
```

Tarball layout (tag `orchestrator-v<version>`):

```text
orchestrator-<version>-linux-x86_64.tar.gz
orchestrator-<version>-darwin-arm64.tar.gz
```

Each tarball contains `bin/orchestrator`, `install.sh`, `LICENSE`, and `README.md`. The root [install.sh](https://github.com/Industrial/definitively/blob/main/install.sh) downloads the matching tarball, verifies SHA256 when `checksums.txt` is present, and installs to `~/.local/bin` by default (`PREFIX`, `BINDIR`).

### Homebrew tap

Example third-party tap workflow:

```bash
brew tap OWNER/tap https://github.com/OWNER/homebrew-tap
brew install orchestrator
```

Formula should install the escript and depend on Erlang/OTP 27+ (or bundle a wrapped escript like the Nix derivation).

## `.orchestrator/` layout

The workspace root is the directory **containing** `.orchestrator/` (not the folder itself). Program YAML paths must sit under `.orchestrator/` so `Orchestrator.Workspace` can resolve the layout.

```text
<workspace-root>/
  .orchestrator/
    env.example          # ORCHESTRATOR_* env hints (copy/rename as needed)
    programs/
      *.yml              # workflow program definitions
    prompts/
      *.md               # LLM prompt files referenced by program YAML
    visualizations/
      .gitkeep           # default output dir for `orchestrator visualize`
      *.dot / *.png      # generated graphs (gitignored in consumer repos)
```

### Scaffold with `orchestrator init`

From your workspace root:

```bash
cd /path/to/your/repo
orchestrator init
```

- Copies packaged templates from `priv/templates/orchestrator/` in the installed package
- Skips files that already exist
- Use `orchestrator init --force` to overwrite

Templates shipped today:

| Path | Purpose |
|------|---------|
| `programs/example.yml` | Minimal passive → active → final workflow |
| `prompts/example.md` | Sample LLM prompt |
| `env.example` | `ORCHESTRATOR_LOG_LEVEL`, `ORCHESTRATOR_WORKSPACE` hints |
| `visualizations/.gitkeep` | Ensures visualize output directory exists |

Override workspace root when cwd is not the repo root:

```bash
export ORCHESTRATOR_WORKSPACE=/path/to/repo
orchestrator init
```

### Run and visualize

```bash
orchestrator run "$PWD/.orchestrator/programs/example.yml"
orchestrator visualize "$PWD/.orchestrator/programs/example.yml"
```

## Visualize defaults

`orchestrator visualize <program.yml>` with **no extra flags** (default mode):

1. Resolves workspace root from the program path (parent of `.orchestrator/`)
2. Writes **DOT** and **PNG** to:

   ```text
   .orchestrator/visualizations/<program-basename>.dot
   .orchestrator/visualizations/<program-basename>.png
   ```

3. Prints both output paths to stdout

If Graphviz `dot` is missing, DOT is still written and the command exits non-zero with a message to install `dot` or use `--format dot`.

### Flag reference

```text
orchestrator visualize <program.yml> [--format dot|png|svg] [--out <basename>]
```

| Invocation | Output |
|------------|--------|
| `(default)` | DOT + PNG under `.orchestrator/visualizations/` |
| `--format dot` | Single `.dot` in default dir |
| `--format png` | Single `.png` (needs `dot`) |
| `--format svg` | Single `.svg` (needs `dot`) |
| `--out /tmp/foo` | Writes `/tmp/foo.dot` (or `.png`/`.svg` with `--format`) |

Omit `--out` with `--format` to keep using `.orchestrator/visualizations/<basename>`.

## Optional workflow tools

These are **not** required to install or run the orchestrator binary itself. Programs reference them in YAML node `command` lists.

| Tool | When you need it |
|------|------------------|
| **Graphviz** (`dot`) | Default `visualize` (PNG); also `--format png` / `svg` |
| **moon** | CLI nodes such as `moon run orchestrator:lint` (see repo dogfood program) |
| **cursor-agent** | LLM nodes that invoke Cursor Agent (`command: [cursor-agent, agent, …]`) |
| **git** | CLI nodes that commit or inspect the repo |

This repository's devenv shell includes `moon` and documents `cursor-agent` in `.orchestrator/env.example`. The orchestrator devenv module adds `graphviz`; install `moon` and `cursor-agent` separately or extend your consumer `devenv.nix` `packages` list.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ORCHESTRATOR_WORKSPACE` | Parent of `.orchestrator/` from program path | Workspace root for runs, init, and visualize |
| `ORCHESTRATOR_LOG_LEVEL` | `INFO` | `TRACE` … `ERROR` logging verbosity |
| `ORCHESTRATOR_LLM_COMMAND` | Stub JSON in dev | Override default LLM runner command (space-separated argv) |
| `ORCHESTRATOR_FROM_SOURCE` | unset | When `1`, devenv builds escript from `orchestrator/` on enter |

See `.orchestrator/env.example` after `orchestrator init`.
