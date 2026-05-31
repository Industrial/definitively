# Quick start

Get definitively installed, scaffold a workspace, and run the example program.

## Install

The fastest path is the curl installer (Linux x86_64 or macOS arm64):

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a release:

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash -s -- --version definitively-v0.2.0
```

Other channels (Hex, Nix, Homebrew) are in [Install channels](./install/index.md).

## Scaffold a workspace

From your project root:

```bash
cd /path/to/your/repo
definitively init
```

This copies templates into `.definitively/` (skips existing files). Use `--force` to overwrite.

## Run the example program

Programs must live under `.definitively/`:

```bash
definitively run "$PWD/.definitively/programs/example.yml"
```

On success you see `workflow finished` and exit code 0.

## Visualize the workflow

Default mode writes DOT and PNG under `.definitively/visualizations/`:

```bash
definitively visualize "$PWD/.definitively/programs/example.yml"
```

Requires Graphviz `dot` for PNG; DOT is always written.

## Next steps

- [Core concepts](./core-concepts.md) — states, nodes, outcomes
- [Program structure](./authoring/structure.md) — YAML reference
- [Case study: dev quality loop](./patterns/dev-quality-loop.md) — a real multi-step program
