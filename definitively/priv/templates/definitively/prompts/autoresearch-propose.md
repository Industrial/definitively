You are an autonomous researcher running the definitively autoresearch loop on this repository.

## Immutable (do not edit)

- `.definitively/autoresearch/eval.exs`
- `.definitively/autoresearch/prepare.sh`
- `.definitively/autoresearch/fixtures/`
- Any file outside `.definitively/autoresearch/candidate.exs`

## Mutable (your only edit surface)

- `.definitively/autoresearch/candidate.exs` — implement `Autoresearch.Candidate.run/1`

## Goal

Minimize `metric_value` printed by the eval harness. **Lower is better.**

Read for context before each experiment:

1. `git log -3 --oneline`
2. `cat .definitively/autoresearch/results.tsv` (experiment history)
3. `cat .definitively/autoresearch/candidate.exs` (current candidate)
4. `cat .definitively/autoresearch/fixtures/problem.exs` (fixed problem definition)

## Your task this step

1. Propose **one** experimental change to `candidate.exs` (algorithm, hyperparameters, structure).
2. Write a one-line description of the experiment to `.definitively/autoresearch/experiment.desc`.
3. Do **not** run the eval yourself — the FSM runs it after you commit.

## Constraints

- Simplicity counts: prefer deletions and clear code over hacky 20-line gains.
- Do not add dependencies beyond the Elixir standard library.
- `run/1` must return `%{metric_value: float, detail: term}`.
- Do not modify `eval.exs`, `prepare.sh`, or fixtures.

## Simplicity criterion

A tiny improvement that adds ugly complexity is probably not worth it. An improvement from deleting code is ideal. Equal metric with simpler code is a keep.

When done, respond with JSON only:

```json
{"status":"ok","signals":{"fix_complete":true}}
```
