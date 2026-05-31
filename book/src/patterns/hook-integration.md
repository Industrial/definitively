# Git hook integration

Git hooks can run definitively **gate programs** — linear quality checks with no LLM fix loops. This dogfoods the runner on every commit and push while keeping hooks fast and deterministic.

## Gate programs vs fix loops

| Program | Hook | LLM | Purpose |
|---------|------|-----|---------|
| `pre-commit-gate.yml` | pre-commit | no | Format, lint, doctor |
| `pre-push-gate.yml` | pre-push | no | Full CI parity + mdBook build |
| `dev-quality-loop.yml` | manual | yes | Gate + AI fix loops + ship |

Gate programs use `cli` nodes only. On failure they transition to a `failed` final state and the hook exits non-zero.

## Pre-commit gate

```text
format → lint → doctor → done
```

Installed at `.definitively/programs/pre-commit-gate.yml` (via `definitively init` template).

## Pre-push gate

```text
format → lint → doctor → test → coverage → docs → build → book-build → done
```

Matches the definitively CI pipeline plus mdBook build.

## devenv / prek wiring

In `devenv.nix`, hooks call definitively directly:

```bash
export DEFINITIVELY_WORKSPACE="$DEVENV_ROOT"
definitively run "$DEVENV_ROOT/.definitively/programs/pre-commit-gate.yml"
```

Requires `definitively` on PATH (devenv module or `DEFINITIVELY_FROM_SOURCE=1`).

## When to use AI fix loops

Do **not** wire `dev-quality-loop.yml` into hooks by default — LLM nodes are slow, costly, and modify files during commit.

Run fix loops manually before committing:

```bash
definitively run "$PWD/.definitively/programs/dev-quality-loop.yml"
```

**Try it:** Break credo intentionally, run `pre-commit-gate.yml`, confirm the hook fails at the lint state.
