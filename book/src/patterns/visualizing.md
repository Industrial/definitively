# Visualizing workflows

```bash
definitively visualize program.yml                    # DOT + PNG (default)
definitively visualize program.yml --format dot       # DOT only
definitively visualize program.yml --format png       # PNG only (needs dot)
definitively visualize program.yml --format svg       # SVG only (needs dot)
definitively visualize program.yml --out /tmp/myflow  # custom basename
```

## Default output

Without flags, outputs go to:

```text
.definitively/visualizations/<program-basename>.dot
.definitively/visualizations/<program-basename>.png
```

Paths are printed to stdout.

## Graphviz

Install [Graphviz](https://graphviz.org/) for PNG/SVG. The devenv module includes `graphviz`. DOT-only mode works without `dot`.

If PNG compilation fails in default mode, DOT is still written and the command exits non-zero with a helpful message.

**Try it:** Visualize `example.yml` after `init`, then open the PNG in your viewer.
