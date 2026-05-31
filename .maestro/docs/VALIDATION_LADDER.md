# Validation Ladder

The harness models verification as a 7-rung ladder. Maestro's canonical verification protocol (`maestro-verify`) covers all 7 rungs but groups them under 6 steps.

In this repo, **rungs 1–5 are executed by definitively gate programs** — not ad-hoc shell one-liners.

## The 7-Rung Ladder

1. **Format** — code formatting checks (treefmt via moon `:format`)
2. **Lint** — static analysis (credo, dialyzer via `definitively:lint`)
3. **Type** — compile + doctor (`definitively:doctor`, `definitively:build`)
4. **Integration** — unit tests + coverage (`definitively:test`, `definitively:coverage`)
5. **E2E** — docs build + mdBook (`definitively:docs`, `:book-build`)
6. **Platform** — platform-specific tests, deploy readiness
7. **Release** — final verdict, release checks

## Definitively gate mapping

| Rung | pre-commit-gate | pre-push-gate | dev-quality-loop |
|------|-----------------|---------------|------------------|
| 1 Format | ✓ | ✓ | (via lint chain) |
| 2 Lint | ✓ | ✓ | ✓ + LLM fix |
| 3 Type/Doctor | ✓ | ✓ | ✓ + LLM fix |
| 4 Integration | — | ✓ test + coverage | ✓ + LLM fix |
| 5 E2E/Docs | — | ✓ docs + book | ✓ + LLM fix |

Scripts (from repo root):

```bash
.maestro/bootstrap/validation/verify-fast.sh   # rungs 1–3
.maestro/bootstrap/validation/verify-gate.sh   # rungs 1–5
definitively run .definitively/programs/dev-quality-loop.yml  # rungs 2–5 + LLM repair + commit
```

## Mapping to `maestro-verify`

- **Plan** → Pre-validation (read spec, contracts, prior evidence)
- **Implement** → Code changes; optional `verify-fast.sh` during iteration
- **Verify** → `verify-gate.sh` (rungs 1–5) + `maestro task verify` (architecture-lint)
- **ProofMap** → Evidence coverage check
- **Verdict** → Rungs 6–7 (platform / release)
- **Branch** → Action based on verdict (merge, rollback, retry)

Evidence recording:

```bash
maestro evidence record --task <id> --command ".maestro/bootstrap/validation/verify-gate.sh" --exit 0
```

## Harness-Specific Validation

For `harness-improvement` work types, additional checks apply:

- Policy schema validation via `maestro policy check`
- Contract amendment evidence when contracts change
- One `harness-delta` evidence row per task that touched `.maestro/`, `policies/`, `skills/`, or `hooks/`
