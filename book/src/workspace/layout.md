# The `.definitively/` layout

The workspace root is the directory **containing** `.definitively/`, not the folder itself.

```text
<workspace-root>/
  .definitively/
    env.example          # environment variable hints
    agents/
      cursor.yml         # agent profiles for LLM nodes
    programs/
      *.yml              # workflow program definitions
    prompts/
      *.md               # LLM prompt files (referenced by program YAML)
    state/
      .gitkeep           # runtime run state (gitignored)
    visualizations/
      .gitkeep           # default output for `definitively visualize`
      *.dot / *.png      # generated graphs (typically gitignored)
```

## Rules

1. **Program paths must be under `.definitively/`** — `Definitively.Workspace` resolves layout from the program file location.
2. **Prompt paths** in LLM nodes are relative to the workspace root (e.g. `.definitively/prompts/fix-lint.md`).
3. **Agent profiles** live under `.definitively/agents/<id>.yml` and are referenced by LLM node `agent:` fields.
4. **Runtime state** under `state/` is gitignored (see `.gitignore`); keep `state/.gitkeep` so the directory exists after clone.
5. **Visualizations** default to `.definitively/visualizations/<program-basename>.{dot,png}`.

## Templates vs live workspace

`definitively init` copies from packaged templates in the installed escript (`priv/templates/definitively/`). Your live `.definitively/` is what runs execute against.

**Try it:** Run `definitively init` in a scratch repo and compare the tree to the template paths in the [definitively repository](https://github.com/Industrial/definitively/tree/main/definitively/priv/templates/definitively).
