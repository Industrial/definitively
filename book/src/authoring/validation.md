# Validation errors

Programs are validated at load time before execution. Common errors:

| Error | Cause |
|-------|-------|
| `invalid_initial` | `program.initial` names a state that does not exist |
| `invalid_transition` | `on:` target names an undefined state |
| `missing_node_ref` | Active state without `node:` |
| `undefined_node` | Active state references unknown node ID |
| `no_final_state` | No state with `type: final` |
| `unreachable_final` | No final state reachable from `initial` |

## Fixing validation errors

1. Read the error message — it includes state names and paths.
2. Ensure every `on:` target exists in `states:`.
3. Ensure active states have valid `node:` references.
4. Add at least one `final` state on a reachable path.

## Missing program fields

Loader errors when `program` lacks `id`, `version`, or `initial`.

**Try it:** Intentionally break `example.yml` (bad transition target) and run `definitively run` to see the error format.
