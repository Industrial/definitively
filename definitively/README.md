# Definitively (Mix app)

**User documentation:** **[Read the Book](https://industrial.github.io/definitively/)** — the canonical guide for install, workspace setup, program authoring, and CLI usage.

This file covers Mix-specific contributor commands only.

## Module layout

```text
lib/definitively/
  outcome.ex           # NodeResult / status
  workflow/engine.ex     # gen_statem FSM
  nodes/                 # CLI and LLM evaluators
  init.ex                # .definitively/ scaffold
  visualize.ex           # Graphviz graphs
  cli.ex                 # escript + Mix task entry
```

## Mix commands

```bash
cd definitively
mix test
mix format
mix docs                  # API docs → doc/index.html
mix definitively run ../.definitively/programs/example.yml
mix escript.build         # local escript
```

## Quality gates

From repo root in devenv:

```bash
moon run definitively:lint definitively:doctor definitively:test definitively:docs definitively:build
```

See [Developing definitively](https://industrial.github.io/definitively/appendices/developing.html) in the book.
