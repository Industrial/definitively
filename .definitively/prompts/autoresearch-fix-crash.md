The autoresearch experiment crashed or produced no `metric_value` in `run.log`.

## Immutable

Do not edit `.definitively/autoresearch/eval.exs`, `prepare.sh`, or `fixtures/`.

## Mutable

Only `.definitively/autoresearch/candidate.exs`.

## Debug steps

1. Read the failure: `tail -n 50 .definitively/autoresearch/run.log`
2. Read the current candidate: `cat .definitively/autoresearch/candidate.exs`
3. Fix trivial bugs (syntax, bad math, missing return shape) in `candidate.exs` only.

If the idea is fundamentally broken, revert `candidate.exs` toward the last known-good version from `git show HEAD~1:.definitively/autoresearch/candidate.exs` and make a smaller change.

Update `.definitively/autoresearch/experiment.desc` with what you fixed.

Respond with JSON only:

```json
{"status":"ok","signals":{"fix_complete":true}}
```
