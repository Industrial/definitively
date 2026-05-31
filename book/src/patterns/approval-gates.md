# Approval gates

Some workflows pause for human or external approval before continuing.

## Passive and active gates

- **Passive states** wait for a labeled transition without running a node.
- Programs can include states that require an approval label (e.g. `done`) before proceeding to a final state.

## Exit code 2

When a run reaches an approval gate that cannot auto-approve, the CLI exits with code **2** (distinct from failure).

## Auto-approve in automation

Tests and CI may supply auto labels programmatically. Design programs with explicit `on:` maps for approval labels you support.

**Try it:** Study `definitively/test/fixtures/approval_state.yml` in the source repo for a minimal approval example.
