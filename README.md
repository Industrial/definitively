# definitively

FSM-based workflow orchestrator for CLI commands, LLM sessions, and git steps. Programs are YAML state machines (`:gen_statem`); nodes run shell commands or LLM agents with typed outcomes.

See [orchestrator/README.md](orchestrator/README.md) for CLI usage and [docs/orchestrator-distribution.md](docs/orchestrator-distribution.md) for install channels (devenv, Nix flake, Hex, GitHub releases, Homebrew).

<!-- Badge row 1: CI & quality -->
[![Orchestrator CI](https://github.com/Industrial/definitively/actions/workflows/orchestrator-ci.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/orchestrator-ci.yml)
[![Release](https://github.com/Industrial/definitively/actions/workflows/release-orchestrator.yml/badge.svg)](https://github.com/Industrial/definitively/actions/workflows/release-orchestrator.yml)
[![codecov](https://codecov.io/gh/Industrial/definitively/branch/main/graph/badge.svg)](https://codecov.io/gh/Industrial/definitively)

<!-- Badge row 2: package & docs -->
[![Hex.pm](https://img.shields.io/hexpm/v/orchestrator.svg)](https://hex.pm/packages/orchestrator)
[![Documentation](https://img.shields.io/badge/docs-orchestrator-blue.svg)](https://github.com/Industrial/definitively/tree/main/orchestrator#readme)

<!-- Badge row 3: repository health -->
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](orchestrator/LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-~%3E%201.18-purple.svg)](https://elixir-lang.org)
[![GitHub Stars](https://img.shields.io/github/stars/Industrial/definitively?style=social)](https://github.com/Industrial/definitively/stargazers)

This repository also contains a Rust + Bun/TypeScript workspace template (devenv, moon, treefmt, prek hooks) used to develop and ship the orchestrator CLI.

---

## Clone (with submodules)

This repo uses git submodules under `.cursor/` (`agency-agents`, `microsoft-rust-training`). Clone with submodules in one go:

```bash
git clone --recurse-submodules git@github.com:Industrial/definitively.git
cd definitively
```

If you already cloned without submodules, init and update them:

```bash
git submodule update --init --recursive
```

---

## Overview

- **Runtimes:** Rust (stable), JavaScript/TypeScript (Bun).
- **Environment:** Nix via [devenv](https://devenv.sh); reproducible toolchain and scripts.
- **Tasks:** [moon](https://moonrepo.dev) for format, check, lint, build, test, docs, audit, coverage, etc.
- **Git hooks:** [prek](https://github.com/j178/prek) (pre-commit–compatible): pre-commit runs fast moon gates (Rust + `orchestrator/`); pre-push runs the full moon pipeline; commit-msg enforces conventional commits (commitizen).
- **Formatting:** [treefmt](https://github.com/numtide/treefmt) over Rust, Nix, shell, JS/TS, YAML, TOML.
- **Rust quality:** cargo-deny (advisories/licenses), cargo-audit, clippy, nextest, optional llvm-cov.

---

## Tooling

| Tool | Purpose | Config |
|------|--------|--------|
| **devenv** | Nix dev shell: languages (Rust, Bun, TS), packages, env vars, scripts. Enter with `devenv shell`. | `devenv.nix`, `devenv.yaml` |
| **moon** | Task runner: format, check, lint, build, test, docs, fix, bench, audit, coverage, ci-format. | `moon.yml` |
| **prek** | Git hooks (no Python). Installs from `.pre-commit-config.yaml` on `devenv shell`. | `.pre-commit-config.yaml` |
| **treefmt** | Single CLI to format all supported files (only tracked files by default). | `treefmt.toml`, `treefmt.ci.toml` |
| **rustfmt** | Rust formatter (invoked by treefmt). | `rustfmt.toml` |
| **cargo-deny** | Rust: advisories, licenses, duplicate deps. Run manually or in CI. | `deny.toml` |
| **cargo-audit** | Rust security advisories. Used in moon `:audit` and pre-push. | — |
| **cargo-nextest** | Fast Rust test runner. Used in moon `:test` and `:coverage`. | `nextest.toml` |
| **sccache** | Shared compilation cache for Rust (and C/C++) across builds. | env `RUSTC_WRAPPER=sccache` |
| **mold** | Fast linker for Rust on Linux. | — |
| **commitizen** | Validates commit messages (conventional commits). Prek hook on commit-msg. | — |
| **Cachix** | Optional Nix binary cache; pull/push configured in `devenv.nix`. | `cachix.pull` / `cachix.push` |

### Treefmt formatters (by file type)

- **Nix:** deadnix, alejandra  
- **GitHub Actions:** actionlint  
- **Bash:** beautysh  
- **JS/TS/JSON:** biome  
- **YAML:** yamlfmt  
- **TOML:** taplo  
- **Rust:** rustfmt (edition 2024)

---

## Cachix (with devenv and CI)

[Cachix](https://cachix.org) is a Nix binary cache. It stores build results (e.g. devenv shell closure, Nix packages) so you and CI can **pull** instead of rebuilding. Optionally, CI can **push** new build results to the cache so the next run is fast.

### In devenv.nix

In `devenv.nix` the cache is configured as:

```nix
cachix = {
  pull = ["project-template"];
  push = "project-template";
};
```

- **pull** — When you run `devenv shell` or any Nix command, Nix will try to fetch store paths from the `project-template` cache (if you’ve trusted it; see below). No account needed for pull.
- **push** — When a build runs with push enabled and Cachix auth, new store paths can be uploaded to the `project-template` cache. Pushing is typically done only in CI (e.g. on the main branch).

Replace `project-template` with your own cache name if you create one at [cachix.org](https://cachix.org).

### Local use (pull only)

1. **Trust the cache** so Nix uses it when building the dev shell:

   ```bash
   cachix use project-template
   ```

   (Use your cache name if different.) This adds the cache to your Nix config and lets `devenv shell` pull binaries instead of building everything.

2. **Enter the shell as usual:** `devenv shell`. If the closure is already on the cache, it will download instead of build.

You do **not** need a Cachix account or auth for pulling. For pushing (e.g. from CI) you need a Cachix auth token.

### CI pipeline

In GitHub Actions (or similar) you want to:

1. **Use the cache on every run** (pull) so CI benefits from previous builds.
2. **Push to the cache only on selected events** (e.g. push to `main`), so the cache stays up to date and you avoid push failures on PRs.

Example pattern:

1. **Install Nix** (e.g. `DeterminateSystems/nix-installer-action`).
2. **Configure Cachix** with [cachix/cachix-action](https://github.com/cachix/cachix-action):
   - `name`: your cache name (e.g. `project-template`).
   - **Pull:** always enabled when `name` is set.
   - **Push:** only when you want to update the cache. Pass the auth token only then and set `skipPush: true` otherwise, so the action doesn’t try to start the push daemon on PRs.

   Example (conceptual):

   ```yaml
   env:
     CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
   steps:
     - uses: cachix/cachix-action@v16
       with:
         name: project-template
         authToken: ${{ github.ref == 'refs/heads/main' && secrets.CACHIX_AUTH_TOKEN }}
         skipPush: ${{ github.ref != 'refs/heads/main' }}
   ```

   So: on `main`, push if the token is set; on PRs or other branches, only pull.

3. **Install devenv** and run your pipeline (e.g. `devenv shell -- moon run :ci-format` and the rest of your checks).

Add the Cachix auth token as a repository secret (`CACHIX_AUTH_TOKEN`) if you want CI to push to your cache. If you only want to pull (e.g. from a public cache), you can omit the token and always use `skipPush: true`.

---

## Lifecycle: what happens when

### 1. Clone the repo

```bash
git clone --recurse-submodules git@github.com:Industrial/definitively.git
cd definitively
```

- `.cursor/agency-agents` and `.cursor/microsoft-rust-training` are **git submodules**; `--recurse-submodules` pulls them. Without it, run `git submodule update --init --recursive` later.

### 2. Enter the dev shell (first time and daily)

```bash
devenv shell
```

**On enter, devenv runs:**

1. **prek-install** — Installs git hooks from `.pre-commit-config.yaml` (pre-commit, pre-push, commit-msg) into `.git/hooks`. Overwrites existing hook files so the repo’s config is always in use.
2. **moon-sync** — Runs `moon sync` so moon’s toolchain and project graph are up to date.
3. **sccache** — Ensures `$HOME/.cache/sccache` exists so the Rust compiler cache can be used.

**You get:**

- Rust (stable), clippy, rustfmt, rust-analyzer, cargo-nextest, cargo-llvm-cov, cargo-audit  
- Bun + TypeScript  
- moon, treefmt, and all formatters (alejandra, beautysh, biome, taplo, yamlfmt, etc.)  
- prek, git, gh, direnv  
- Env: `RUST_BACKTRACE=1`, `CARGO_TERM_COLOR=always`, `RUSTC_WRAPPER=sccache`, `MOON_TOOLCHAIN_FORCE_GLOBALS=rust`  
- Elixir 1.18 / OTP 27, `orchestrator/` Mix app (`mix-setup`, `mix-test`)
- Scripts: `prek-install`, `moon-sync`, `pre-commit`, `pre-push` (used by git hooks)

Optional: if you use [direnv](https://direnv.net), `direnv allow` in the repo will enter the devenv shell automatically when you `cd` in.

### 3. Develop

- **Format:** `moon run :format` (writes changes) or `moon run :ci-format` (CI-style; fails if anything would change).
- **Orchestrator (Elixir):** `moon run orchestrator:format`, `:compile`, `:lint` (credo), `:test` — or `cd orchestrator && mix test`.
- **Check / lint / build / test:**  
  `moon run :check`, `:lint`, `:build`, `:test`  
  Fast gate: `devenv shell -- pre-commit` (same as the pre-commit hook).  
  Full gate: `devenv shell -- pre-push` (same as the pre-push hook).
- **Fix auto-fixable issues:** `moon run :fix`
- **Docs:** `moon run :docs` or `:check-docs`
- **Security:** `moon run :audit`; run `cargo deny check` manually for full deny checks.
- **Coverage:** `moon run :coverage` (nextest under llvm-cov).

All of these use the tools and configs from the dev shell (rustfmt, nextest.toml, etc.).

### 4. Commit

- When you run `git commit`, the **pre-commit** hook runs moon gates (Rust format/check/lint + orchestrator format/compile/credo).
- The **commit-msg** hook (prek + commitizen) runs on the same commit.
- It validates that the commit message follows conventional commits (e.g. `feat: add X`, `fix: Y`). If not, the commit is rejected.

### 5. Push

- When you run `git push`, the **pre-push** hook runs.
- The hook runs: `devenv shell -- pre-push`
- **pre-push** (defined in `devenv.nix` scripts) runs:  
  `moon run :format :check :lint :build :test :audit :check-docs`
- If any of these fail, the push is aborted. So the branch you push has already been formatted, checked, linted, built, tested, audited, and doc-checked in the same way as in CI.

### 6. CI (when you add it)

- In GitHub Actions (or similar), use the same commands inside a Nix/devenv setup so CI matches local and pre-push.
- **Format check:** `devenv shell -- moon run :ci-format`  
  Uses `treefmt.ci.toml` (same as treefmt but `fail-on-change = true`).
- **Full pipeline:** `devenv shell -- moon run :format :check :lint :build :test :audit :check-docs`  
  Or use `devenv shell -- pre-push` to mirror the pre-push hook exactly.

---

## Moon tasks quick reference

| Task | What it does |
|------|----------------|
| `:format` | treefmt (format tracked files) |
| `:ci-format` | treefmt with `treefmt.ci.toml` (fail if not formatted) |
| `:check` | cargo check --workspace --all-features |
| `:lint` | cargo fmt --check + cargo clippy |
| `:build` | cargo build |
| `:test` | cargo nextest run |
| `:docs` | cargo doc --no-deps --all-features |
| `:fix` | cargo fix + clippy --fix |
| `:bench` | cargo bench (no-op if no `benches/`) |
| `:audit` | cargo audit |
| `:coverage` | cargo llvm-cov nextest |
| `:check-docs` | cargo doc + clippy with missing_docs lint |

Run with: `moon run :<task>` or `devenv shell -- moon run :<task>` from outside the shell.

---

## Config files

- **devenv.nix** — Dev shell: packages, env, scripts (prek-install, moon-sync, pre-push).
- **devenv.yaml** — Nix flake inputs (fenix, nixpkgs, rust-overlay, etc.).
- **moon.yml** — Moon project and task definitions.
- **treefmt.toml** — Formatters and globs (local format; `walk = "git"`).
- **treefmt.ci.toml** — Same as above with `fail-on-change = true` for CI.
- **rustfmt.toml** — Rust format options (edition 2024, 2 spaces).
- **deny.toml** — cargo-deny: advisories, licenses, bans.
- **nextest.toml** — nextest profiles (default + ci), timeouts, cache.
- **.pre-commit-config.yaml** — prek: pre-push (devenv pre-push script), commit-msg (commitizen).

---

## Summary flow

1. **Clone** (with submodules) → **devenv shell** → prek installs hooks, moon syncs, sccache ready.  
2. **Develop** with moon tasks (`:format`, `:check`, `:lint`, `:build`, `:test`, etc.).  
3. **Commit** → commitizen checks message.  
4. **Push** → pre-push runs full moon pipeline; push only if it passes.  
5. **CI** runs orchestrator tests and coverage on push/PR; Rust gates run locally via pre-push.

---

## Coverage

[![codecov](https://codecov.io/gh/Industrial/definitively/branch/main/graph/badge.svg)](https://codecov.io/gh/Industrial/definitively)

CI runs `mix test --cover` in `orchestrator/`; Mix enforces **≥ 90%** coverage (`test_coverage` in `orchestrator/mix.exs`). Upload to Codecov uses `CODECOV_TOKEN` when configured.

![Coverage sunburst](https://codecov.io/gh/Industrial/definitively/branch/main/graphs/sunburst.svg)

---

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=Industrial/definitively&type=Date)](https://star-history.com/#Industrial/definitively&Date)

---

## Contributors

Thanks to everyone who has contributed patches, reported issues, or improved the workflows.

[![Contributors](https://contrib.rocks/image?repo=Industrial/definitively)](https://github.com/Industrial/definitively/graphs/contributors)

---

## License

The orchestrator CLI is licensed under [MIT](orchestrator/LICENSE).
