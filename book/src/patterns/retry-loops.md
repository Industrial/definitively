# Retry and fix loops

The dev quality loop pattern: **gate → fix → gate**.

## Pattern

```yaml
lint:
  type: active
  node: moon_lint
  on:
    success: doctor
    failure: fix_lint
    partial: fix_lint

fix_lint:
  type: active
  node: llm_fix_lint
  on:
    success: lint
    failure: fix_lint
    retry: fix_lint
```

- **failure** and **partial** on the gate route to a fix state
- **success** on the fix state returns to the gate
- **retry** keeps trying the fix when the LLM session fails

## Avoiding infinite loops

Definitively does not cap retries automatically. For production use:

- Set reasonable `timeout_ms` on LLM nodes
- Add a counter state or max-retry final state in your program design
- Monitor logs at `DEFINITIVELY_LOG_LEVEL=INFO`

**Try it:** Simplify the pattern to two states (run → fix → run) before adding the full gate chain.
