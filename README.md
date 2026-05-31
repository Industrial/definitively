# definitively

FSM-based workflow runner for CLI commands, LLM sessions, and git steps. Programs are YAML state machines backed by OTP `:gen_statem`; nodes run shell commands or LLM agents and return typed outcomes.

**[Read the Book](https://industrial.github.io/definitively/)** — install, first program, YAML reference, patterns, and CLI.

[![Book](https://img.shields.io/badge/docs-book-blue)](https://industrial.github.io/definitively/)
[![Definitively CI](https://github.com/Industrial/definitively/actions/workflows/definitively-ci.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/definitively-ci.yml)
[![Release](https://github.com/Industrial/definitively/actions/workflows/release-definitively.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/release-definitively.yml)
[![codecov](https://codecov.io/gh/Industrial/definitively/branch/main/graph/badge.svg)](https://codecov.io/gh/Industrial/definitively)
[![Hex.pm](https://img.shields.io/hexpm/v/definitively.svg)](https://hex.pm/packages/definitively)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](definitively/LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-~%3E%201.18-purple.svg)](https://elixir-lang.org)
[![GitHub Stars](https://img.shields.io/github/stars/Industrial/definitively?style=social)](https://github.com/Industrial/definitively/stargazers)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a release: `bash -s -- --version definitively-v0.2.0`. See the [Install channels](https://industrial.github.io/definitively/install/index.html) chapter for Hex, Nix, Homebrew, and devenv.

## Learn

| Topic | Book chapter |
|-------|----------------|
| First run | [Quick start](https://industrial.github.io/definitively/quick-start.html) |
| Workspace setup | [`.definitively/` layout](https://industrial.github.io/definitively/workspace/layout.html) |
| Write programs | [Authoring programs](https://industrial.github.io/definitively/authoring/structure.html) |
| Quality loop example | [Dev quality loop](https://industrial.github.io/definitively/patterns/dev-quality-loop.html) |
| CLI reference | [Commands and flags](https://industrial.github.io/definitively/cli/reference.html) |
| Contribute | [Developing definitively](https://industrial.github.io/definitively/appendices/developing.html) |

## Develop

```bash
git clone --recurse-submodules git@github.com:Industrial/definitively.git
cd definitively
devenv shell
```

`devenv shell` installs git hooks, syncs moon, and puts Elixir, definitively, and graphviz on PATH. Set `DEFINITIVELY_FROM_SOURCE=1` to build the CLI from source on shell enter.

```bash
moon run definitively:build
mdbook serve book    # preview the book locally
```

Contributor details: [Developing definitively](https://industrial.github.io/definitively/appendices/developing.html) in the book.

## Coverage

[![codecov](https://codecov.io/gh/Industrial/definitively/branch/main/graph/badge.svg)](https://codecov.io/gh/Industrial/definitively)

![Coverage sunburst](https://codecov.io/gh/Industrial/definitively/branch/main/graphs/sunburst.svg)

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=Industrial/definitively&type=Date)](https://star-history.com/#Industrial/definitively&Date)

## Contributors

[![Contributors](https://contrib.rocks/image?repo=Industrial/definitively)](https://github.com/Industrial/definitively/graphs/contributors)

## License

[MIT](definitively/LICENSE)
