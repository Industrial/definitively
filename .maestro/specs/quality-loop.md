---
slug: quality-loop
title: Production dev quality loop
acceptance_criteria:
  - ".orchestrator/programs/dev-quality-loop.yml runs from repo root via moon run quality:run with ORCHESTRATOR_WORKSPACE set"
  - "LLM node uses inlined command argv (cursor-agent) and passes prompt_file contents after --"
  - "CLI nodes call moon orchestrator:lint and orchestrator:build matching orchestrator/moon.yml"
  - "devenv exports ORCHESTRATOR_WORKSPACE; no scripts/*.sh wrapper for LLM"
  - "mix test and moon orchestrator:build pass"
non_goals:
  - "Auto git commit in the quality loop"
  - "Rust workspace gates in the same FSM (orchestrator-only v1)"
risk_class: medium
mode: heavy
work_type: change-request
---

# Production dev quality loop

Repo-local dogfood: `.orchestrator/` programs, prompts, and moon `quality:*` tasks.
