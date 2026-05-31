# The `.definitively/` layout

The workspace root is the directory **containing** `.definitively/`, not the folder itself.

```text
<workspace-root>/
  .definitively/
    env.example          # environment variable hints
    programs/
      *.yml              # workflow program definitions
    prompts/
      *.md               # LLM prompt files (referenced by program YAML)
    visualizations/
      .gitkeep           # default output for `definitively visualize`
      *.dot / *.png      # generated graphs (typically gitignored)
```

## Rules

1. **Program paths must be under `.definitively/`** — `Definitively.Workspace` resolves layout from the program file location.
2. **Prompt paths** in LLM nodes are relative to the workspace root (e.g. `.definitively/prompts/fix-lint.md`).
3. **Visualizations** default to `.definitively/visualizations/<program-basename>.{dot,png}`.

## Templates vs live workspace

`definitively init` copies from packaged templates in the installed escript (`priv/templates/definitively/`). Your live `.definitively/` is what runs execute against.

**Try it:** Run `definitively init` in a scratch repo and compare the tree to the template paths in the [definitively repository](https://github.com/Industrial/definitively/tree/main/definitively/priv/templates/definitively).
