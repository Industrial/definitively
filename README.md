# definitively

FSM-based workflow definitively for CLI commands, LLM sessions, and git steps. Programs are YAML state machines backed by OTP `:gen_statem`; nodes run shell commands or LLM agents and return typed outcomes.

[![Definitively CI](https://github.com/Industrial/definitively/actions/workflows/definitively-ci.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/definitively-ci.yml)
[![Release](https://github.com/Industrial/definitively/actions/workflows/release-definitively.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/release-definitively.yml)
[![codecov](https://codecov.io/gh/Industrial/definitively/branch/main/graph/badge.svg)](https://codecov.io/gh/Industrial/definitively)
[![Hex.pm](https://img.shields.io/hexpm/v/definitively.svg)](https://hex.pm/packages/definitively)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](definitively/LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-~%3E%201.18-purple.svg)](https://elixir-lang.org)
[![GitHub Stars](https://img.shields.io/github/stars/Industrial/definitively?style=social)](https://github.com/Industrial/definitively/stargazers)

**CLI usage:** [definitively/README.md](definitively/README.md)

**All install channels:** [docs/definitively-distribution.md](docs/definitively-distribution.md)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a release: append `bash -s -- --version definitively-v0.1.0`. Installs to `~/.local/bin` by default (`PREFIX` / `BINDIR` override). Requires a published release for your platform (`linux-x86_64` or `darwin-arm64`).

## Develop

```bash
git clone --recurse-submodules git@github.com:Industrial/definitively.git
cd definitively
devenv shell
```

`devenv shell` installs git hooks (prek), syncs moon, and puts Elixir, the definitively escript, and graphviz on PATH. Set `DEFINITIVELY_FROM_SOURCE=1` before entering the shell to build the CLI from `definitively/` instead of the flake package.

Run the full quality pipeline locally:

```bash
moon run definitively:build
```

Or step through tasks: `project-template:format`, then `definitively:lint`, `:doctor`, `:test`, `:coverage`, `:docs`, `:build`.

## Git hooks

Hooks are defined in `.pre-commit-config.yaml` and installed on `devenv shell`.

| Hook | Runs |
|------|------|
| **pre-commit** | `moon run :format :lint :doctor :test :coverage :docs :build` |
| **pre-push** | same as pre-commit |
| **commit-msg** | conventional commits (`scripts/commit-msg.sh`) |

`:format` is workspace treefmt; the rest are definitively Mix tasks (credo, doctor, tests, coverage ≥ 90%, ExDoc, compile).

## CI

GitHub Actions runs on changes under `definitively/`:

- **test** — `mix test --cover` → Codecov (`definitively/cover/lcov.info`, `CODECOV_TOKEN`)
- **hex-dry-run** — `mix hex.build` and `mix hex.publish --dry-run` when `HEX_API_KEY` is set

Releases (tag `definitively-v*`) publish to GitHub Releases, Hex, and Homebrew tap via `release-definitively.yml`. See [docs/definitively-distribution.md](docs/definitively-distribution.md#release-maintainers).

There is no separate Rust or devenv CI job; local hooks are the gate for formatting and the definitively build chain.

## Moon tasks

| Target | What it does |
|--------|----------------|
| `project-template:format` | treefmt over tracked files (Rust, Nix, shell, JS/TS, YAML, TOML) |
| `definitively:lint` | credo `--strict` (depends on format) |
| `definitively:doctor` | doc + `@spec` coverage |
| `definitively:test` | `mix test` |
| `definitively:coverage` | `mix test --cover` (≥ 90% threshold) |
| `definitively:docs` | `mix docs --warnings-as-errors` |
| `definitively:build` | `mix compile --warnings-as-errors` |

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

[MIT](definitively/LICENSE)
