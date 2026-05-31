# Glossary

| Term | Definition |
|------|------------|
| **Workspace** | Directory containing `.definitively/`; parent of the config folder |
| **Program** | YAML file defining a complete FSM workflow |
| **State** | A step in the FSM: passive, active, or final |
| **Node** | Reusable CLI or LLM executor referenced by active states |
| **Outcome** | Typed result of a node (success, failure, partial, unknown) |
| **Label** | Named outcome used in transitions (`success`, `failure`, …) |
| **Transition** | Edge from one state to another, keyed by outcome label |
| **Run** | Single execution of a program from initial to final state |
