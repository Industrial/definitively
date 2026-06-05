# Autoresearch sandbox (definitively dogfood)

Tier B autoresearch harness for testing the `.definitively/programs/autoresearch.yml` FSM on this repo without GPU/ML dependencies.

## Layout

| Path | Role |
|------|------|
| `fixtures/problem.exs` | Immutable benchmark definition |
| `eval.exs` | Immutable judge — runs candidate, prints `metric_value` |
| `candidate.exs` | **Mutable** — agent edits this file only |
| `prepare.sh` | One-time readiness check |
| `bin/` | FSM helper scripts |
| `results.tsv` | Experiment log (gitignored) |

## Metric

Lower `metric_value` is better. The sandbox minimizes a fixed scalar function of `target_x` from `fixtures/problem.exs`.

## Run

From the repository root (devenv shell recommended):

```bash
# optional tag for branch autoresearch/<tag>
export AUTORESEARCH_RUN_TAG=jun5-test
./.definitively/autoresearch/bin/run-autoresearch.sh "$AUTORESEARCH_RUN_TAG"
```

Or directly:

```bash
definitively run "$PWD/.definitively/programs/autoresearch.yml"
```

Requires `cursor-agent` (or set `DEFINITIVELY_AGENT`) for LLM propose/fix steps.

## Manual smoke test (no LLM)

```bash
sh .definitively/autoresearch/prepare.sh
sh .definitively/autoresearch/bin/run-experiment.sh
sh .definitively/autoresearch/bin/parse-metrics.sh
```

## Stop

Interrupt the definitively run (Ctrl+C) or `definitively cancel <run_id>`.
