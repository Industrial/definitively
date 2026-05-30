# Repository orchestrator workflows

Dogfood configuration for [orchestrator](../orchestrator/).

## Dev quality loop

Program: [programs/dev-quality-loop.yml](programs/dev-quality-loop.yml)

The program drives a sequential gate chain (same order as [orchestrator/moon.yml](../orchestrator/moon.yml)):

```text
lint → doctor → test → coverage → docs → build → commit (LLM) → done
```

Each gate on failure/partial enters an LLM fix state, then retries **that same gate**.

| Node (in program YAML) | Fix state |
|------------------------|-----------|
| `moon run orchestrator:lint` | `fix_lint` |
| `moon run orchestrator:doctor` | `fix_doctor` |
| `moon run orchestrator:test` | `fix_test` |
| `moon run orchestrator:coverage` | `fix_coverage` |
| `moon run orchestrator:docs` | `fix_docs` |
| `moon run orchestrator:build` | `fix_build` |
| `llm_ship` (git commit) | `fix_commit` |

Moon is only used inside the program’s CLI nodes—not via root `moon.yml` tasks.

### Run

From the repository root (after `direnv allow` / devenv shell builds the `orchestrator` escript):

```bash
orchestrator run "$PWD/.orchestrator/programs/dev-quality-loop.yml"
```

Workspace root is inferred from the program path (parent of `.orchestrator/`). Optional override: `ORCHESTRATOR_WORKSPACE`.

LLM fix steps require `cursor-agent` on PATH (see [env.example](env.example)).

### Develop the engine

Inside `orchestrator/`, `mix orchestrator …` delegates to the same CLI (for contributors only).


### Logging

Set `ORCHESTRATOR_LOG_LEVEL` to one of `TRACE`, `DEBUG`, `INFO` (default), `WARN`, or `ERROR`.
State transitions, node execution, outcomes, and subprocess lifecycle are logged via OTP `Logger`.
