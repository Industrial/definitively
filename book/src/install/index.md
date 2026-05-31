# Install channels

All channels install the same escript (`Definitively.CLI`).

| Channel | Best for | Command |
|---------|----------|---------|
| **curl** | Quick install | See below |
| **Hex** | Elixir developers | `mix escript.install hex definitively --force` |
| **Nix flake** | Reproducible CI | `nix build github:Industrial/definitively#definitively` |
| **devenv module** | Nix/devenv teams | Import `devenvModules.definitively` |
| **Homebrew** | macOS/Linux brew users | `brew tap idcleartomwieland/tap && brew install definitively` |

## curl (GitHub releases)

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash
```

Pin a version:

```bash
curl -fsSL https://raw.githubusercontent.com/Industrial/definitively/main/install.sh | bash -s -- --version definitively-v0.2.0
```

Tarballs: `definitively-<version>-{linux-x86_64,darwin-arm64}.tar.gz`

## Hex

```bash
mix local.hex --force
mix escript.install hex definitively --force
export PATH="$(mix escript.install_path):$PATH"
```

Requires Elixir ~> 1.18 and Erlang/OTP 27+.

## Nix flake

```bash
nix build github:Industrial/definitively#definitively
./result/bin/definitively init
```

From a checkout: `nix build .#definitively`

## devenv module

```yaml
# devenv.yaml
inputs:
  definitively-repo:
    url: github:Industrial/definitively
    flake: true
```

```nix
# devenv.nix
{ inputs, ... }: {
  imports = [ inputs.definitively-repo.devenvModules.definitively ];
}
```

Provides `definitively` and `graphviz` on PATH.

## Homebrew

```bash
brew tap idcleartomwieland/tap https://github.com/idcleartomwieland/homebrew-tap
brew install definitively
```

## Runtime dependencies

| Tool | Required? | Used by |
|------|-----------|---------|
| Erlang/OTP 27+ | Yes (Hex/source) | escript interpreter |
| Graphviz `dot` | Optional | `visualize` PNG/SVG |
| moon | Optional | Programs with moon CLI nodes |
| cursor-agent (or other agent CLI) | Optional | LLM nodes via [agent profiles](../authoring/agent-profiles.md) |
| git | Optional | Programs with git CLI nodes |
