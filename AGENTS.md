# Project Conventions

Repo-level conventions for agents working in this codebase. The harness pointer surface
lives in `.maestro/AGENTS.md`; this file holds code conventions, build commands, and
feature boundaries.

## Build / test / verify

Canonical gates are **definitively FSM programs** under `.definitively/programs/`. Run from repo root after `direnv allow` (or devenv shell) so `definitively` is on PATH.

```bash
# fast gate (pre-commit parity): format → lint → doctor
.maestro/bootstrap/validation/verify-fast.sh
# or: definitively run "$PWD/.definitively/programs/pre-commit-gate.yml"

# full gate (pre-push / maestro verify parity): … → test → coverage → docs → build → book
.maestro/bootstrap/validation/verify-gate.sh
# or: definitively run "$PWD/.definitively/programs/pre-push-gate.yml"

# AI-assisted fix loop (manual — includes LLM nodes + commit)
definitively run "$PWD/.definitively/programs/dev-quality-loop.yml"
```

Individual moon tasks (when debugging a single gate):

```bash
moon run definitively:format definitively:lint definitively:test definitively:build
```

Record evidence for maestro after a gate passes:

```bash
maestro evidence record --task <id> --command ".maestro/bootstrap/validation/verify-gate.sh" --exit 0
```

## Layout

- `definitively/` — Elixir definitively engine (Mix app)
- `.definitively/` — repo-local YAML programs, prompts, node templates
- `book/` — mdBook documentation
- `.maestro/` — harness state (read `.maestro/AGENTS.md` first)

## Conventions

- Match existing code style; use established libraries before adding new ones.
- Surgical edits only — touch what the task requires.
- Bump the relevant version when behavior changes.

## See also

- `.maestro/MAESTRO.md` — read order, lane policy, daily commands
- `.maestro/docs/HARNESS.md` — product-delta vs harness-delta model
- `.maestro/docs/FEATURE_INTAKE.md` — work-type classification decision tree
- `.maestro/docs/VALIDATION_LADDER.md` — 7-step verification protocol

<!-- maestro-setup:start -->
## Maestro

This project is wired into the Maestro harness. State and config live
under `.maestro/`. Run `./init.sh` to bring a fresh checkout up; run
`maestro doctor` and `maestro status` to see what Maestro knows.

Preserve content outside this managed block; the block is rewritten by
`maestro setup` and the `maestro-setup` skill, but everything else in
this file is yours.
<!-- maestro-setup:end -->
