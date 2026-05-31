# Repository definitively workflows

Dogfood configuration for [orchestrator](../definitively/).

## Dev quality loop

Program: [programs/dev-quality-loop.yml](programs/dev-quality-loop.yml)

The program drives a sequential gate chain (same order as [definitively/moon.yml](../definitively/moon.yml)):

```text
lint → doctor → test → coverage → docs → build → commit (LLM) → done
```

Each gate on failure/partial enters an LLM fix state, then retries **that same gate**.

| Node (in program YAML) | Fix state |
|------------------------|-----------|
| `moon run definitively:lint` | `fix_lint` |
| `moon run definitively:doctor` | `fix_doctor` |
| `moon run definitively:test` | `fix_test` |
| `moon run definitively:coverage` | `fix_coverage` |
| `moon run definitively:docs` | `fix_docs` |
| `moon run definitively:build` | `fix_build` |
| `llm_ship` (git commit) | `fix_commit` |

Moon is only used inside the program’s CLI nodes—not via root `moon.yml` tasks.

### Run

From the repository root (after `direnv allow` / devenv shell builds the `definitively` escript):

```bash
definitively run "$PWD/.definitively/programs/dev-quality-loop.yml"
```

Workspace root is inferred from the program path (parent of `.definitively/`). Optional override: `DEFINITIVELY_WORKSPACE`.

LLM fix steps require `cursor-agent` on PATH (see [env.example](env.example)).

### Develop the engine

Inside `definitively/`, `mix definitively …` delegates to the same CLI (for contributors only).


### Logging

Set `ORCHESTRATOR_LOG_LEVEL` to one of `TRACE`, `DEBUG`, `INFO` (default), `WARN`, or `ERROR`.
State transitions, node execution, outcomes, and subprocess lifecycle are logged via OTP `Logger`.

## Git hook gate programs

Installed by devenv/prek — **no LLM**, fail fast on first broken gate.

| Program | Hook | Chain |
|---------|------|-------|
| [programs/pre-commit-gate.yml](programs/pre-commit-gate.yml) | pre-commit | format → lint → doctor |
| [programs/pre-push-gate.yml](programs/pre-push-gate.yml) | pre-push | … → test → coverage → docs → build → book-build |

For AI-assisted repair, run [dev-quality-loop.yml](programs/dev-quality-loop.yml) manually — do not wire it into hooks.

See the [Hook integration](https://industrial.github.io/definitively/patterns/hook-integration.html) book chapter.

