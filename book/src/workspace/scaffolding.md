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
| `agents/cursor.yml` | Cursor agent profile for LLM nodes |
| `agents/example.yml` | Stub profile for local testing (no agent CLI) |
| `agents/README.md` | Profile authoring guide |
| `env.example` | Environment variable hints |
| `.gitignore` | Ignores runtime state under `state/` |
| `state/.gitkeep` | Ensures state directory exists |
| `visualizations/.gitkeep` | Ensures visualize output directory exists |

## Override workspace root

When your shell cwd is not the repo root:

```bash
export DEFINITIVELY_WORKSPACE=/path/to/repo
definitively init
```

**Try it:** Run `init`, then `definitively run` and `definitively visualize` on `example.yml` as in [Quick start](../quick-start.md).
