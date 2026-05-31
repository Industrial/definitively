# Introduction

**Definitively** is an FSM-based workflow runner for CLI commands, LLM sessions, and git steps. You describe workflows as YAML state machines; definitively executes them with OTP `:gen_statem`, classifying each step into typed **outcomes** rather than raw exit codes.

## When to use definitively

Use definitively when you want:

- **Repeatable automation** — lint → test → fix loops, release pipelines, agent-driven quality gates
- **Explicit control flow** — states, transitions, and failure paths visible in YAML
- **Mixed executors** — shell commands and LLM agents in one program
- **Workspace-local config** — programs, prompts, and visualizations live under `.definitively/` in your repo

## Mental model

```text
workspace root
  └── .definitively/
        programs/*.yml   ← workflow definitions
        prompts/*.md     ← LLM prompt files
        visualizations/  ← graph output from `visualize`

definitively run program.yml
  → load & validate program
  → start FSM at initial state
  → execute active state's node (CLI or LLM)
  → classify outcome (success, failure, partial, …)
  → transition via state's `on:` map
  → repeat until a final state
```

## What this book covers

| Part | Topics |
|------|--------|
| I | Install, first run, core concepts |
| II | Workspace layout and scaffolding |
| III | YAML program authoring |
| IV | Real-world patterns |
| V | CLI reference |
| VI | All install channels |
| Appendices | Cheat sheets, contributing, releases |

**Try it:** Continue to [Quick start](./quick-start.md) to install and run your first program in five minutes.
