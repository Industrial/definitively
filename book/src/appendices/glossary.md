# Glossary

| Term | Definition |
|------|------------|
| **Workspace** | Directory containing `.definitively/`; parent of the config folder |
| **Program** | YAML file defining a complete FSM workflow |
| **State** | A step in the FSM: passive, active, or final |
| **Node** | Reusable executor (cli, git, gh, or llm) referenced by active states |
| **Action** | Named operation for git/gh nodes (e.g. `commit`, `run_watch`) |
| **Options** | Action-specific parameters on git/gh nodes |
| **Signal** | Named boolean flag parsed from node output (e.g. `clean`, `dirty`) |
| **Data** | Structured JSON map from git/gh node output, usable with `jq` predicates |
| **Outcome** | Typed result of a node (success, failure, partial, unknown) |
| **Label** | Named outcome used in transitions (`success`, `failure`, …) |
| **Transition** | Edge from one state to another, keyed by outcome label |
| **Run** | Single execution of a program from initial to final state |
