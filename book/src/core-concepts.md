# Core concepts

## Finite state machine

Every program is a **finite state machine (FSM)**:

- One **initial** state where execution begins
- **Active** states run a node (CLI command or LLM session)
- **Passive** states wait for an external event (e.g. approval label)
- **Final** states end the run (success or failure)

Transitions are declared on each state under `on:` — mapping an **outcome label** to the next state name.

## Nodes

A **node** is a reusable unit of work referenced by active states:

| Kind | Runs |
|------|------|
| `cli` | A shell command (argv list) |
| `llm` | An LLM agent via configurable command + prompt file |

Nodes define **outcome rules** that classify raw results (exit code, timeout, JSON, signals) into labels like `success`, `failure`, or `partial`.

## Outcomes

Definitively does not treat exit code 0 as success blindly. Each node declares how to interpret results:

```yaml
outcome:
  success:
    - exit_code: 0
  failure:
    - exit_code: {neq: 0}
```

The engine picks the first matching label, then looks up that label in the current state's `on:` map to decide the next state.

## Workspace

The **workspace root** is the directory containing `.definitively/`. Definitively infers it from the program path (parent of `.definitively/`). Override with `DEFINITIVELY_WORKSPACE`.

## Runs

A **run** is one execution of a program from initial state through transitions to a final state. The CLI command `definitively run` starts a run synchronously and exits when the workflow finishes or gets stuck.

**Try it:** Open `.definitively/programs/example.yml` after `definitively init` and trace each state against [States and transitions](./authoring/states.md).
