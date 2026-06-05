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

LLM fix steps use the `cursor` agent profile (see [agents/cursor.yml](agents/cursor.yml) and [env.example](env.example)). devenv sets `DEFINITIVELY_AGENT=cursor`.

### Develop the engine

Inside `definitively/`, `mix definitively …` delegates to the same CLI (for contributors only).


### Logging

Set `DEFINITIVELY_LOG_LEVEL` to one of `TRACE`, `DEBUG`, `INFO` (default), `WARN`, or `ERROR`.
Workflow events (state transitions, node execution, outcomes, and subprocess lifecycle) are logged via OTP `Logger` to the terminal.

## Git hook gate programs

Installed by devenv/prek — **no LLM**, fail fast on first broken gate.

| Program | Hook | Chain |
|---------|------|-------|
| [programs/pre-commit-gate.yml](programs/pre-commit-gate.yml) | pre-commit | format → lint → doctor |
| [programs/pre-push-gate.yml](programs/pre-push-gate.yml) | pre-push | … → test → coverage → docs → build → book-build |

For AI-assisted repair, run [dev-quality-loop.yml](programs/dev-quality-loop.yml) manually — do not wire it into hooks.


## Plan → Maestro mission (autonomous)

Program: [programs/plan-mission.yml](programs/plan-mission.yml)

Drives a full Maestro heavy-mode mission from any plan markdown (including Cursor `.plan.md` files). Pass the plan path via CLI input:

```bash
definitively run "$PWD/.definitively/programs/plan-mission.yml" \
  --plan-file "$PWD/.cursor/plans/your.plan.md"
```

Flow: init → LLM spec → validate → mission → LLM decompose → wave loop (claim → implement → gate → fix → evidence → verify → verdict → ship).

Uses structured `maestro` nodes (see `definitively/priv/templates/definitively/nodes/maestro.yml`). Run state: `.definitively/state/maestro-run.json`.

See [.maestro/docs/DEFINITIVELY_INTEGRATION.md](../.maestro/docs/DEFINITIVELY_INTEGRATION.md).

See the [Hook integration](https://industrial.github.io/definitively/patterns/hook-integration.html) book chapter.



## Autoresearch loop

Tier B Karpathy-style autoresearch FSM: LLM proposes edits to a single mutable file, deterministic nodes run eval, log results, and git-reset on regression.

| Artifact | Purpose |
|----------|---------|
| [programs/autoresearch.yml](programs/autoresearch.yml) | FSM program |
| [autoresearch/](autoresearch/) | Dogfood sandbox (`candidate.exs` + immutable `eval.exs`) |
| [prompts/autoresearch-propose.md](prompts/autoresearch-propose.md) | Agent strategy prompt |

```bash
./.definitively/autoresearch/bin/run-autoresearch.sh my-run-tag
```

See [autoresearch/README.md](autoresearch/README.md) for sandbox details.
