---
slug: agent-profile-refactor-054927eb
title: Agent Profile Refactor
acceptance_criteria:
  - "Programs declare `program.inputs` in YAML; `definitively run <program.yml> --plan-file <path>` populates `RunContext.inputs`; `definitively run --help <program.yml>` lists declared inputs without executing; missing required inputs and unknown flags fail before the FSM starts."
  - "`RunState.init_plan/2` reads `inputs[\"plan_file\"]` first; `DEFINITIVELY_PLAN_FILE` is deprecated with a warning but still accepted for one release."
  - "`Definitively.AgentProfile` domain (struct, Loader, Validator, Builder, OutputParser) loads `.definitively/agents/<id>.yml`, builds `{executable, argv}` from profile + node + prompt, and parses stdout via pluggable formats (`stream_json`, `json`, `text`)."
  - "LLM nodes accept `agent:` (profile id); Spec.Validator requires `prompt_file` and exactly one of `agent` or `command`; `Nodes.Llm` has no hardcoded `cursor-agent` resolution or Cursor-specific stream-json parsing."
  - "`.definitively/programs/dev-quality-loop.yml` and `plan-mission.yml` contain zero `cursor-agent` strings, use `agent: cursor` (or `DEFINITIVELY_AGENT` default), and `plan-mission.yml` declares required `plan_file` input so runs work without `DEFINITIVELY_PLAN_FILE`."
  - "Repo ships `.definitively/agents/cursor.yml`; `definitively init` emits agent profile templates; `.definitively/.gitignore` ignores `state/*` with `state/.gitkeep` present."
  - "`devenv.nix`, `.definitively/env.example`, init templates, and book chapters (`llm-nodes`, `agent-profiles`, `program-inputs`, integration docs) document profiles and CLI inputs; version bumped to 0.4.0 with migration note for removed `DEFINITIVELY_CURSOR_AGENT`."
  - "Tests cover CLI input parsing, program inputs schema, agent profile loader/builder/output_parser, and profile-driven LLM execution; `moon run definitively:format definitively:lint definitively:test` passes; `mix definitively run` on `dev-quality-loop.yml` succeeds with repo cursor profile and devenv env."
non_goals:
  - "Auto-detecting installed agent harnesses."
  - "Maestro-specific agent profile (maestro nodes already cover harness lifecycle)."
  - "Per-state agent override in the FSM (single `DEFINITIVELY_AGENT` default is enough for v1)."
  - "Shipping OpenCode or other harness profiles in `priv/` (profile-only model; users author profiles)."
  - "Positional CLI args (flags only in v1; `-- plan.md` deferred)."
risk_class: medium
mode: heavy
work_type: change-request
---

# Agent Profile Refactor (Harness-Agnostic LLM Nodes)

Decouple definitively LLM nodes from Cursor via YAML agent profiles, and add first-class CLI program inputs (e.g. `--plan-file`) so run parameters are passed as flags—not env vars. Programs declare inputs in YAML; the executor resolves argv, prompt delivery, and output parsing from profile config.

## Problem

Cursor is hard-coded at four layers today:

| Layer | Coupling |
|-------|----------|
| Programs | `dev-quality-loop.yml`, `plan-mission.yml` — 12-line `cursor-agent` argv anchor |
| Executor | `Nodes.Llm` — `resolve_executable("cursor-agent")`, `DEFINITIVELY_CURSOR_AGENT`, Nix default path |
| Output parsing | `Nodes.Llm` — `decode_llm_line` knows Cursor stream-json `{type: result, result: …}` |
| Run inputs | `plan-mission.yml` requires `DEFINITIVELY_PLAN_FILE` env — no CLI flags |

Maestro/git/gh nodes already show the right pattern: **structured domain module + YAML config**, not vendor argv inlined in every program.

## Target architecture

```mermaid
flowchart TB
  subgraph programs [YAML Programs]
    LlmNode["llm node\nagent: cursor\nprompt_file: …"]
  end
  subgraph profiles [User-defined profiles]
    Profile[".definitively/agents/cursor.yml"]
  end
  subgraph engine [Definitively Engine]
    Loader["AgentProfile.Loader"]
    Builder["AgentProfile.build_argv/3"]
    Parser["OutputParser for format"]
    LlmExec["Nodes.Llm"]
  end
  subgraph subprocess [Subprocess]
    AgentCLI["any CLI harness"]
  end
  LlmNode --> Loader
  Loader --> Profile
  LlmNode --> LlmExec
  LlmExec --> Builder
  LlmExec --> Parser
  Builder --> AgentCLI
  AgentCLI --> Parser
```

**Principle:** Definitively ships the **profile schema and parser primitives** only.

## Program inputs (CLI flags, not env vars)

Programs declare named inputs under `program.inputs`. Flag names derive from input keys (`plan_file` → `--plan-file`). `RunContext` gains `inputs: map()` populated at run start. Unknown CLI flags error with a hint; missing required inputs fail before the FSM starts.

Example invocation:

```bash
definitively run .definitively/programs/plan-mission.yml \
  --plan-file .cursor/plans/agent_profile_refactor_054927eb.plan.md
```

## Agent profile schema (v1)

New file per profile: `.definitively/agents/<id>.yml`

- **Selection:** per-node `agent: cursor`, default `DEFINITIVELY_AGENT=cursor`, or raw `command:` (mutually exclusive with `agent`)
- **Executable resolution:** `executable_env` → `executable` → error (no magic `cursor-agent` rewrite)
- **Prompt modes:** `argv_after_delimiter`, `flag`, `stdin`
- **Output formats:** `stream_json`, `json`, `text` with configurable extraction and envelope paths

## Rollout order

1. Program inputs — schema, CLI parser, RunContext, plan-mission `--plan-file`
2. AgentProfile domain + loader + validator
3. Llm executor refactor + tests with stub profile
4. Migrate repo programs + add `.definitively/agents/cursor.yml`
5. Remove cursor hardcoding + deprecated plan env vars
6. Docs + book chapters (inputs + agent profiles) + version bump to 0.4.0
