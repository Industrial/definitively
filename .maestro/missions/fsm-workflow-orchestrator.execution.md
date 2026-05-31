# FSM Workflow Definitively — Maestro execution overlay

Mission: `pln-mpsu3xxd-h0s6jn`  
Spec: `.maestro/specs/fsm-workflow-definitively.md`  
Verbatim DDD plan (1:1): `.maestro/missions/fsm-workflow-definitively.md`

This file is **not** part of the product plan. It defines parallel execution, worktrees, and subagent dispatch.

## Task map

| Wave | Parallel? | Task ID | Slug | Claim when |
|------|-----------|---------|------|------------|
| 0 | no | `tsk-mpsu3z87-xy3w58` | `domain-spec` | immediately |
| 1 | **yes (2 agents)** | `tsk-mpsu3z87-117b1h` | `outcome-eval` | after `domain-spec` **shipped** |
| 1 | **yes (2 agents)** | `tsk-mpsu3z87-t6295y` | `engine-dynamic` | after `domain-spec` **shipped** |
| 2 | no | `tsk-mpsu3z87-hae7p4` | `nodes-cli` | after **both** wave-1 tasks shipped |
| 3 | no | `tsk-mpsu3z87-evv7d9` | `nodes-llm-approval` | after `nodes-cli` shipped |

Decompose created a linear slug list only; **do not** claim wave-1 tasks until wave-0 ships (human/agent discipline). Maestro does not auto-block across unrelated slugs.

## Worktree + subagent protocol (heavy mode)

Each `maestro task claim <tsk-id> --agent <id>` auto-creates a git worktree (ADR-0008). For wave 1:

1. Parent agent ships `domain-spec`, merges PR.
2. Dispatch **two** Cursor subagents (`best-of-n-runner` or `generalPurpose`) in parallel:
   - Agent A: `maestro task claim tsk-mpsu3z87-117b1h --agent cursor-a`
   - Agent B: `maestro task claim tsk-mpsu3z87-t6295y --agent cursor-b`
3. Each agent works only in its worktree; no shared edits to `definitively/lib/definitively/domain/*` vs `outcome/*` vs `workflow/engine.ex` without coordination.
4. If merge conflicts appear at PR time, **engine-dynamic** rebases after **outcome-eval** (evaluator modules are leafier; engine imports domain + outcome).

## Further split (optional)

If a phase is too large while **claimed**:

```bash
maestro task claim <parent-tsk> --agent <id>
maestro task split <parent-tsk> --parallel "slice A" "slice B"
```

Use `--parallel` so children are not sequentially `blocked_by` each other.

## Verification per wave

| Wave | Falsify with |
|------|----------------|
| 0 | `moon run definitively:test` — pure tests for loader, validator, transition table |
| 1a | Unit tests for `OutcomeRules.classify/2` and predicates |
| 1b | Engine tests with stubbed `RawResult`; fixture YAML drives states |
| 2 | Integration: fake CLI node; `mix run -e` or CLI `definitively run` |
| 3 | MCP tool smoke + approval path |

Always: `maestro task verify <tsk-id>` before `ship`.

## Commands (copy-paste)

```bash
maestro mission show pln-mpsu3xxd-h0s6jn
maestro task claim tsk-mpsu3z87-xy3w58 --agent cursor-main
# after ship:
maestro task claim tsk-mpsu3z87-117b1h --agent cursor-outcome &
maestro task claim tsk-mpsu3z87-t6295y --agent cursor-engine &
```

## Skills per wave

| Wave | Cursor skills |
|------|----------------|
| all | `.cursor/skills/maestro/SKILL.md` |
| 0–3 Elixir | `elixir-core`, `elixir-otp-design` |
| 1a | `elixir-core` (pure predicates) |
| 1b | `elixir-otp-design` (gen_statem) |
| 2–3 | `elixir-testing`, `elixir-concurrency` (Task supervisor for nodes) |
