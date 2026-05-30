# definitively

FSM-based workflow orchestrator for CLI commands, LLM sessions, and git steps. Programs are YAML state machines backed by OTP `:gen_statem`; nodes run shell commands or LLM agents and return typed outcomes.

[![Orchestrator CI](https://github.com/Industrial/definitively/actions/workflows/orchestrator-ci.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/orchestrator-ci.yml)
[![Release](https://github.com/Industrial/definitively/actions/workflows/release-orchestrator.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/release-orchestrator.yml)
[![codecov](https://codecov.io/gh/Industrial/definitively/branch/main/graph/badge.svg)](https://codecov.io/gh/Industrial/definitively)
[![Hex.pm](https://img.shields.io/hexpm/v/orchestrator.svg)](https://hex.pm/packages/orchestrator)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](orchestrator/LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-~%3E%201.18-purple.svg)](https://elixir-lang.org)
[![GitHub Stars](https://img.shields.io/github/stars/Industrial/definitively?style=social)](https://github.com/Industrial/definitively/stargazers)

**CLI usage:** [orchestrator/README.md](orchestrator/README.md)

**All install channels:** [docs/orchestrator-distribution.md](docs/orchestrator-distribution.md)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a release: append `bash -s -- --version orchestrator-v0.1.0`. Installs to `~/.local/bin` by default (`PREFIX` / `BINDIR` override). Requires a published release for your platform (`linux-x86_64` or `darwin-arm64`).

## Develop

```bash
git clone --recurse-submodules git@github.com:Industrial/definitively.git
cd definitively
devenv shell
```

`devenv shell` installs git hooks (prek), syncs moon, and puts Elixir, the orchestrator escript, and graphviz on PATH. Set `ORCHESTRATOR_FROM_SOURCE=1` before entering the shell to build the CLI from `orchestrator/` instead of the flake package.

Run the full quality pipeline locally:

```bash
moon run orchestrator:build
```

Or step through tasks: `project-template:format`, then `orchestrator:lint`, `:doctor`, `:test`, `:coverage`, `:docs`, `:build`.

## Git hooks

Hooks are defined in `.pre-commit-config.yaml` and installed on `devenv shell`.

| Hook | Runs |
|------|------|
| **pre-commit** | `moon run :format :lint :doctor :test :coverage :docs :build` |
| **pre-push** | same as pre-commit |
| **commit-msg** | conventional commits (`scripts/commit-msg.sh`) |

`:format` is workspace treefmt; the rest are orchestrator Mix tasks (credo, doctor, tests, coverage ≥ 90%, ExDoc, compile).

## CI

GitHub Actions runs on changes under `orchestrator/`:

- **test** — `mix test --cover`, uploaded to Codecov when `CODECOV_TOKEN` is set
- **hex-dry-run** — `mix hex.build` and `mix hex.publish --dry-run` when `HEX_API_KEY` is set

Releases are tagged `orchestrator-v*` and built by `release-orchestrator.yml`.

There is no separate Rust or devenv CI job; local hooks are the gate for formatting and the orchestrator build chain.

## Moon tasks

| Target | What it does |
|--------|----------------|
| `project-template:format` | treefmt over tracked files (Rust, Nix, shell, JS/TS, YAML, TOML) |
| `orchestrator:lint` | credo `--strict` (depends on format) |
| `orchestrator:doctor` | doc + `@spec` coverage |
| `orchestrator:test` | `mix test` |
| `orchestrator:coverage` | `mix test --cover` (≥ 90% threshold) |
| `orchestrator:docs` | `mix docs --warnings-as-errors` |
| `orchestrator:build` | `mix compile --warnings-as-errors` |

## Submodules

`.cursor/agency-agents` and `.cursor/microsoft-rust-training` are git submodules. Clone with `--recurse-submodules`, or run `git submodule update --init --recursive` after the fact.

## Coverage

[![codecov](https://codecov.io/gh/Industrial/definitively/branch/main/graph/badge.svg)](https://codecov.io/gh/Industrial/definitively)

![Coverage sunburst](https://codecov.io/gh/Industrial/definitively/branch/main/graphs/sunburst.svg)

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=Industrial/definitively&type=Date)](https://star-history.com/#Industrial/definitively&Date)

## Contributors

[![Contributors](https://contrib.rocks/image?repo=Industrial/definitively)](https://github.com/Industrial/definitively/graphs/contributors)

## License

[MIT](orchestrator/LICENSE)
