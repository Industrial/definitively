# Definitively distribution guide

How to install the `definitively` CLI in consumer projects and set up a `.definitively/` workspace.

Product overview and contributor docs: [`definitively/README.md`](../definitively/README.md).

Replace `OWNER/REPO` below with the GitHub repository that publishes definitively (e.g. `github:your-org/test-haskell-web`).

## Consumer devenv setup

Add the definitively repo as a **flake input**, then import its devenv module. The module puts `definitively` and Graphviz on PATH.

### `devenv.yaml`

Using a GitHub URL:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  definitively-repo:
    url: github:OWNER/REPO
    flake: true
```

When definitively lives in the same monorepo you are developing (this repository's pattern):

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
    inputs.definitively-repo.devenvModules.definitively
  ];

  # Optional: pin workspace for definitively runs from this repo root
  enterShell = ''
    export DEFINITIVELY_WORKSPACE="$DEVENV_ROOT"
  '';
}
```

In-tree (same repo as definitively):

```nix
{ inputs, pkgs, ... }: {
  imports = [
    inputs.repo.devenvModules.definitively
  ];

  enterShell = ''
    export DEFINITIVELY_WORKSPACE="$DEVENV_ROOT"
  '';
}
```

Run `devenv shell` (or `direnv allow`) and verify:

```bash
which definitively
definitively init
```

### Building from source inside devenv

Contributors working on the Mix app can force a local escript build on shell enter:

```bash
export DEFINITIVELY_FROM_SOURCE=1
devenv shell
```

This runs `mix escript.build` in `definitively/` and prepends that directory to `PATH` instead of using the flake-built package.

## Install channels

All channels install the same escript entrypoint (`Definitively.CLI`). Pick one.

| Channel | Best for | Notes |
|---------|----------|-------|
| **devenv module** | Teams already on devenv/Nix | `inputs.<repo>.devenvModules.definitively`; includes `graphviz` |
| **Nix flake** | CI, reproducible installs | `nix build github:OWNER/REPO#definitively`; wraps Erlang on PATH |
| **Hex** | Elixir developers | `mix escript.install hex definitively --force` |
| **GitHub releases** | Quick download, no Nix/Hex | Platform escript artifacts attached to release tags |
| **Homebrew tap** | macOS/Linux Homebrew users | Third-party or org tap formula |

### devenv flake input

See [Consumer devenv setup](#consumer-devenv-setup) above.

The module definition lives at `nix/devenv-module.nix` and exposes:

- `inputs.repo.packages.${system}.definitively` (flake package)
- `pkgs.graphviz` (`dot` for visualize PNG/SVG)

### Nix flake

Build and run from a checkout:

```bash
nix build .#definitively
./result/bin/definitively init
```

Build from a pinned GitHub flake (no local checkout):

```bash
nix build github:OWNER/REPO#definitively
```

The derivation is defined in `nix/definitively.nix` (Elixir 1.18 / OTP 27, prod escript, Erlang wrapped on PATH).

### Hex

When the `:definitively` package is published:

```bash
mix local.hex --force
mix escript.install hex definitively --force
export PATH="$(mix escript.install_path):$PATH"
```

Requires Elixir ~> 1.18 and Erlang/OTP 27+ installed locally.

### GitHub releases (curl installer)

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a release:

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash -s -- --version definitively-v0.1.0
```

Tarball layout (tag `definitively-v<version>`):

```text
definitively-<version>-linux-x86_64.tar.gz
definitively-<version>-darwin-arm64.tar.gz
```

Each tarball contains `bin/definitively`, `install.sh`, `LICENSE`, and `README.md`. The root [install.sh](https://github.com/Industrial/definitively/blob/main/install.sh) downloads the matching tarball, verifies SHA256 when `checksums.txt` is present, and installs to `~/.local/bin` by default (`PREFIX`, `BINDIR`).

### Homebrew tap

Example third-party tap workflow:

```bash
brew tap idcleartomwieland/tap https://github.com/idcleartomwieland/homebrew-tap
brew install definitively
```

Formula should install the escript and depend on Erlang/OTP 27+ (or bundle a wrapped escript like the Nix derivation).

## `.definitively/` layout

The workspace root is the directory **containing** `.definitively/` (not the folder itself). Program YAML paths must sit under `.definitively/` so `Definitively.Workspace` can resolve the layout.

```text
<workspace-root>/
  .definitively/
    env.example          # ORCHESTRATOR_* env hints (copy/rename as needed)
    programs/
      *.yml              # workflow program definitions
    prompts/
      *.md               # LLM prompt files referenced by program YAML
    visualizations/
      .gitkeep           # default output dir for `definitively visualize`
      *.dot / *.png      # generated graphs (gitignored in consumer repos)
```

### Scaffold with `definitively init`

From your workspace root:

```bash
cd /path/to/your/repo
definitively init
```

- Copies packaged templates from `priv/templates/definitively/` in the installed package
- Skips files that already exist
- Use `definitively init --force` to overwrite

Templates shipped today:

| Path | Purpose |
|------|---------|
| `programs/example.yml` | Minimal passive → active → final workflow |
| `prompts/example.md` | Sample LLM prompt |
| `env.example` | `ORCHESTRATOR_LOG_LEVEL`, `DEFINITIVELY_WORKSPACE` hints |
| `visualizations/.gitkeep` | Ensures visualize output directory exists |

Override workspace root when cwd is not the repo root:

```bash
export DEFINITIVELY_WORKSPACE=/path/to/repo
definitively init
```

### Run and visualize

```bash
definitively run "$PWD/.definitively/programs/example.yml"
definitively visualize "$PWD/.definitively/programs/example.yml"
```

## Visualize defaults

`definitively visualize <program.yml>` with **no extra flags** (default mode):

1. Resolves workspace root from the program path (parent of `.definitively/`)
2. Writes **DOT** and **PNG** to:

   ```text
   .definitively/visualizations/<program-basename>.dot
   .definitively/visualizations/<program-basename>.png
   ```

3. Prints both output paths to stdout

If Graphviz `dot` is missing, DOT is still written and the command exits non-zero with a message to install `dot` or use `--format dot`.

### Flag reference

```text
definitively visualize <program.yml> [--format dot|png|svg] [--out <basename>]
```

| Invocation | Output |
|------------|--------|
| `(default)` | DOT + PNG under `.definitively/visualizations/` |
| `--format dot` | Single `.dot` in default dir |
| `--format png` | Single `.png` (needs `dot`) |
| `--format svg` | Single `.svg` (needs `dot`) |
| `--out /tmp/foo` | Writes `/tmp/foo.dot` (or `.png`/`.svg` with `--format`) |

Omit `--out` with `--format` to keep using `.definitively/visualizations/<basename>`.

## Release (maintainers)

Push tag `definitively-vX.Y.Z` (must match `definitively/mix.exs` `version`). Workflow [release-definitively.yml](../.github/workflows/release-definitively.yml) runs:

1. **validate** — tag/version check, `mix test --cover`, `mix hex.build`
2. **build** — portable escript tarballs (linux-x86_64, darwin-arm64)
3. **github-release** — attach assets + `install.sh`
4. **hex-publish** — `mix hex.publish --yes` (`HEX_API_KEY` secret)
5. **homebrew-tap-bump** — update `idcleartomwieland/homebrew-tap` (`HOMEBREW_TAP_TOKEN` secret)

Re-run a failed publish without re-tagging: Actions → Release definitively → Run workflow → enter the tag.

Required GitHub secrets: `HEX_API_KEY`, `HOMEBREW_TAP_TOKEN` (optional until Homebrew automation is enabled).

## Optional workflow tools

These are **not** required to install or run the definitively binary itself. Programs reference them in YAML node `command` lists.

| Tool | When you need it |
|------|------------------|
| **Graphviz** (`dot`) | Default `visualize` (PNG); also `--format png` / `svg` |
| **moon** | CLI nodes such as `moon run definitively:lint` (see repo dogfood program) |
| **cursor-agent** | LLM nodes that invoke Cursor Agent (`command: [cursor-agent, agent, …]`) |
| **git** | CLI nodes that commit or inspect the repo |

This repository's devenv shell includes `moon` and documents `cursor-agent` in `.definitively/env.example`. The definitively devenv module adds `graphviz`; install `moon` and `cursor-agent` separately or extend your consumer `devenv.nix` `packages` list.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEFINITIVELY_WORKSPACE` | Parent of `.definitively/` from program path | Workspace root for runs, init, and visualize |
| `ORCHESTRATOR_LOG_LEVEL` | `INFO` | `TRACE` … `ERROR` logging verbosity |
| `ORCHESTRATOR_LLM_COMMAND` | Stub JSON in dev | Override default LLM runner command (space-separated argv) |
| `DEFINITIVELY_FROM_SOURCE` | unset | When `1`, devenv builds escript from `definitively/` on enter |

See `.definitively/env.example` after `definitively init`.
