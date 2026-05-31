# Developing definitively

Contributors work from the [definitively repository](https://github.com/Industrial/definitively).

## Setup

```bash
git clone --recurse-submodules git@github.com:Industrial/definitively.git
cd definitively
devenv shell
```

Set `DEFINITIVELY_FROM_SOURCE=1` before `devenv shell` to build the escript from `definitively/` on enter.

## Quality pipeline

```bash
moon run definitively:lint definitively:doctor definitively:test definitively:coverage definitively:docs definitively:build
```

| Task | Checks |
|------|--------|
| `definitively:lint` | Credo `--strict` |
| `definitively:doctor` | `@moduledoc` / `@doc` / `@spec` coverage |
| `definitively:test` | ExUnit |
| `definitively:coverage` | ≥ 90% threshold |
| `definitively:docs` | ExDoc with `--warnings-as-errors` |
| `definitively:build` | Full chain + compile |

## API docs

```bash
cd definitively && mix docs
# → doc/index.html
```

ExDoc covers modules; this book covers usage.

## Book development

```bash
mdbook serve book   # live preview at http://localhost:3000
mdbook build book   # output in book/book/
```
