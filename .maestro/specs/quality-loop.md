---
slug: quality-loop
title: Production dev quality loop
acceptance_criteria:
  - ".definitively/programs/dev-quality-loop.yml runs from repo root via moon run quality:run with DEFINITIVELY_WORKSPACE set"
  - "LLM node uses inlined command argv (cursor-agent) and passes prompt_file contents after --"
  - "CLI nodes call moon definitively:lint and definitively:build matching definitively/moon.yml"
  - "devenv exports DEFINITIVELY_WORKSPACE; no scripts/*.sh wrapper for LLM"
  - "mix test and moon definitively:build pass"
non_goals:
  - "Auto git commit in the quality loop"
  - "Rust workspace gates in the same FSM (definitively-only v1)"
risk_class: medium
mode: heavy
work_type: change-request
---

# Production dev quality loop

Repo-local dogfood: `.definitively/` programs, prompts, and moon `quality:*` tasks.
