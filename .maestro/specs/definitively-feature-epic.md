---
slug: definitively-feature-epic
title: Definitively Feature Epic (Categories 1–6)
acceptance_criteria:
  - "JSONL run journal under .definitively/runs/ with resume, replay, history browser, idempotent run IDs, cancel, timeout, pause/resume"
  - "CLI exposes status/approve/cancel/pause/resume/runs; MCP exposes workflow_start/status/approve/cancel/pause/resume + resources + HTTP transport"
  - "Orchestration: max_attempts, when:, sub-workflows, parallel, choice, wait, mission meta-FSM, file triggers — each with example program + book chapter"
  - "Outcomes: on.unknown, any/all predicates, native jq, git/gh structured outcomes, artifacts/vars, token budgets"
  - "Node kinds: http, file, docker, shell, secrets, expanded git/gh/maestro, temporal/postgres/notify"
  - "LLM: prompt templating, multi-turn memory, tool loop, profiles, progress events, schema validation, rate limits"
  - "definitively mix.exs version 1.0.0; verify-gate.sh exit 0; mdbook build clean"
non_goals:
  - "OpenTelemetry, web UI, RBAC, Homebrew, GitHub Action distribution"
  - "Maestro harness changes outside definitively nodes/docs"
risk_class: high
mode: heavy
work_type: new-spec
---
# Definitively Feature Epic

Implements `.cursor/plans/definitively_feature_epic_f0e410cf.plan.md` — categories 1–6 only.
