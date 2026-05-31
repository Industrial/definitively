---
slug: fsm-workflow-ddd-model-be25dfb3
title: FSM Workflow DDD Model
acceptance_criteria:
  - "Domain.Program, NodeDefinition, OutcomeRules, and TransitionTable structs load from a fixture YAML program via Spec.Loader and pass Spec.Validator (one initial, reachable finals, valid on: targets, defined node refs)."
  - "OutcomeRules.classify/2 evaluates medium DSL predicates (exit_code, timeout, signal, jq) against RawResult and returns Outcome with verdict_label; unmatched rules yield status :unknown."
  - "Workflow.Engine is a data-driven :gen_statem built from Domain.Program and TransitionTable with no hardcoded lint/fix/commit module states; supports passive, active, approval, and final state types."
  - "Nodes.Cli executes CLI node definitions and returns RawResult; Definitively.Run exposes start/status with an ephemeral run registry; CLI supports definitively run and definitively status against the fixture program."
  - "Nodes.Llm executes LLM node definitions to RawResult; approval states block until Run.approve/2; MCP tools workflow_run, workflow_status, and workflow_approve mirror the Run API."
  - "moon run definitively:format definitively:compile definitively:lint definitively:test pass."
non_goals:
  - "Porting Symphony or WORKFLOW.md semantics."
  - "Durable persistence or resume-after-crash for runs."
  - "Parallel FSM branches or sub-workflow nodes in v1."
  - "Choosing MCP transport (stdio vs HTTP) before the Run API is stable."
risk_class: medium
mode: heavy
work_type: new-spec
---

# FSM Workflow Definitively — Domain Model Plan

## Product decisions (locked in)

| Decision | Choice |
|----------|--------|
| Symphony / WORKFLOW.md | Out of scope; greenfield design |
| Human interaction | Auto transitions by default; optional **approval** states in YAML |
| Persistence | **Ephemeral** runs (in-memory + structured logs); no resume-after-crash v1 |
| Node executors v1 | **CLI** + **LLM** only |
| Outcome rules | **Medium** DSL: exit code, timeout, named signals, JSONPath/JQ on stdout or LLM JSON |

Existing code to evolve—not throw away:

- `Definitively.Outcome` — keep as the **verdict** value object after classification
- `Definitively.Workflow.Engine` — replace hardcoded `linting/fixing/committing` with a **data-driven** `:gen_statem` driven by parsed YAML
- `Definitively.Application` — wire supervision when CLI/MCP land

## Implementation slices (from plan)

1. **Core + Spec** — YAML types, loader, validator, transition table tests
2. **Evaluator** — predicate structs + classify + extend `Outcome`
3. **CLI executor** — minimal `echo` / `mix test` nodes
4. **Engine refactor** — data-driven gen_statem + fixture program
5. **Run + CLI** — `definitively run`
6. **LLM executor** — agent command + JSON envelope
7. **Approval + MCP** — human gates and tools
