# Scaffolding with `init`

```bash
definitively init              # copy templates; skip existing files
definitively init --force      # overwrite existing template files
```

## What gets copied

| Path | Purpose |
|------|---------|
| `programs/example.yml` | Minimal passive → active → final workflow |
| `prompts/example.md` | Sample LLM prompt |
| `env.example` | Environment variable hints |
| `visualizations/.gitkeep` | Ensures visualize output directory exists |

## Override workspace root

When your shell cwd is not the repo root:

```bash
export DEFINITIVELY_WORKSPACE=/path/to/repo
definitively init
```

**Try it:** Run `init`, then `definitively run` and `definitively visualize` on `example.yml` as in [Quick start](../quick-start.md).
