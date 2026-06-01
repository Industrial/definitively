Produce a **hierarchical implementation plan** of the highest possible quality before writing or changing any code. Treat planning as the primary deliverable; implementation comes only after the plan is complete and the user approves it (unless they explicitly asked for plan + implementation in one pass).

## Mindset

- **Think before you act.** Decompose the problem until each leaf is independently implementable, verifiable, and reviewable in one focused session.
- **Ground every claim in evidence.** Read the codebase, specs, ADRs, and relevant docs. Cite real paths, modules, and patterns — never invent structure that does not exist.
- **Prefer decisions over options.** Lock product and technical choices at the root; surface open questions only where blocking. For each open question, state default recommendation and what would change if the answer differs.
- **Design for verification.** If a leaf cannot define acceptance criteria and a quality gate, it is not decomposed enough.

## Phase 0 — Reconnaissance (mandatory)

Before drafting the plan:

1. **Clarify scope** — Restate the user's goal in one paragraph. List in-scope, out-of-scope, and assumptions.
2. **Inventory context** — Read (as applicable):
   - User message and conversation history
   - `AGENTS.md`, `.maestro/AGENTS.md`, relevant specs under `.maestro/specs/`
   - Existing plans under `.cursor/plans/` (avoid duplicating or contradicting)
   - Code paths the change will touch (use roam-code, serena, or lean-ctx — do not guess)
3. **Identify constraints** — Language, frameworks, test commands, CI gates, backward compatibility, performance, security.
4. **Name locked decisions** — Table of decisions already made vs. decisions this plan must make.

Do not skip reconnaissance. A plan without codebase grounding is invalid.

## Phase 1 — Hierarchical decomposition

Build a tree:

```
Epic (the user's goal)
├── Phase / milestone (coherent slice of value)
│   ├── Work package (1–3 days of focused work)
│   │   └── Leaf task (single session: implement + test + verify)
```

**Rules:**

- **Leaves only** carry full detail (sections below). Parents summarize intent, dependencies, and rollup acceptance criteria.
- Each leaf must be **MECE** relative to its parent — no overlap, no gaps.
- Order leaves by **dependency** (topological). Mark parallelizable siblings explicitly.
- Cap leaf size: one module boundary, one API surface, one migration, or one testable behavior — not "build the feature."
- Assign stable IDs: `L1`, `L2`, … or `phase-a/cli-executor` — use consistently in diagrams and gates.

## Phase 2 — Required content per leaf

Every **leaf** in the plan MUST include all of the following subsections. Do not use placeholders like "TBD" or "add tests later."

### 1. Context

- **Why this leaf exists** — Parent goal and what breaks if skipped.
- **Current state** — What exists today (files, modules, behavior) with paths.
- **Target state** — One-paragraph description of done.
- **Dependencies** — Other leaf IDs that must complete first; external services or env vars.

### 2. Acceptance criteria

Use **Given / When / Then** or numbered **must** statements. Each criterion must be objectively checkable.

Example:

> - **AC-L3.1**: Given a valid YAML program with `initial: idle`, when `Spec.Loader.load/1` is called, then `{:ok, %Program{}}` is returned and `initial` is `:idle`.
> - **AC-L3.2**: Given a program referencing an undefined node, when loaded, then `{:error, %SpecError{reason: :undefined_node, ...}}` is returned.

Include **negative cases** and **edge cases** where relevant.

### 3. File & module structure

- **Create** — New files with purpose (not empty stubs).
- **Modify** — Existing files and nature of change (~add struct, ~refactor callback, ~extend schema).
- **Delete / move** — If any, with migration notes.

Prefer a tree listing:

```
lib/definitively/
  spec/
    loader.ex          # NEW — YAML → Program
    validator.ex       # NEW — cross-reference checks
  domain/
    program.ex         # MODIFY — add initial/ states fields
test/definitively/
  spec/
    loader_test.exs    # NEW — AC-L3.1, AC-L3.2
```

Call out **public API** additions (`@spec`, `@callback`, CLI flags, MCP tools) explicitly.

### 4. Diagrams

Include at least one diagram per **phase** (architecture, sequence, or state). Every leaf that changes control flow, data flow, or state MUST have a diagram — pick the best fit:

| Situation | Diagram type |
|-----------|----------------|
| Module boundaries, layers | `flowchart TB` or C4-style |
| Request / event lifecycle | `sequenceDiagram` |
| FSM, workflow, status | `stateDiagram-v2` |
| Data model | `erDiagram` or struct table |
| Rollout / ordering | `gantt` or numbered dependency graph |

Diagrams must use **real names** from the plan (modules, events, states), not generic boxes.

### 5. Quality gates

For each leaf, define how an agent proves completion **before** marking done:

| Gate | Command / action | Pass condition |
|------|------------------|----------------|
| Unit tests | `mix test path/to_test.exs` | 0 failures |
| Lint | `mix credo --strict` or project equivalent | 0 issues |
| Format | `mix format --check-formatted` | clean |
| Integration | specific command or scenario | stated outcome |
| Repo gate (if leaf is shippable) | `.maestro/bootstrap/validation/verify-fast.sh` or `definitively run …/pre-commit-gate.yml` | exit 0 |

If this repo uses Maestro: reference witness level (L0–L3) and whether `maestro evidence record` applies.

**Definition of done** for the leaf = all gates pass + acceptance criteria satisfied.

### 6. Implementation notes

- Key algorithms, patterns to follow (link to existing code).
- Error handling and return-value conventions (`{:ok, _}` / `{:error, _}`).
- What **not** to do (scope traps, anti-patterns).
- Version bump or changelog entry if behavior changes.

### 7. Risks & rollback

- What could go wrong; severity (low / medium / high).
- Rollback or feature-flag strategy if applicable.

## Phase 3 — Plan-level rollup

After all leaves, include:

1. **Executive summary** — 3–5 sentences for a reviewer who reads nothing else.
2. **Decision log** — Table of locked choices.
3. **Dependency graph** — Mermaid or ASCII showing leaf order and parallel tracks.
4. **Recommended implementation order** — Numbered list of leaf IDs with one-line rationale.
5. **Total quality gate** — Command(s) that validate the full epic (e.g. `verify-gate.sh`, full test suite).
6. **Out of scope / deferred** — Explicit list to prevent scope creep.

## Output format

Write the plan as markdown suitable for `.cursor/plans/<slug>.plan.md`:

```yaml
---
name: <Human-readable title>
overview: <One sentence>
todos:
  - id: <leaf-id>
    content: <leaf title — imperative verb>
    status: pending
isProject: false
---
```

Then the full hierarchical body using headings:

```markdown
# <Title>

## Executive summary
...

## Locked decisions
| Decision | Choice | Rationale |
...

## Phase A: <name>
### A.1 Leaf: <title> (`leaf-id-a1`)
#### Context
...
#### Acceptance criteria
...
#### File structure
...
#### Diagrams
```mermaid
...
```
#### Quality gates
...
#### Implementation notes
...
#### Risks
...

### A.2 Leaf: ...
```

Use collapsible detail for long leaves only if the platform supports it; otherwise keep leaves focused so each fits on screen.

## Quality bar (self-check before submitting)

Reject your own draft if any of these fail:

- [ ] Every leaf has acceptance criteria, file structure, diagrams (where applicable), and quality gates — no exceptions.
- [ ] No leaf requires "and also refactor unrelated X" — split or defer.
- [ ] Paths and module names were verified against the repo.
- [ ] Diagrams compile (valid mermaid) and match the prose.
- [ ] Gates use commands that actually exist in this project (`AGENTS.md`, `moon`, `mix`, `definitively`, maestro).
- [ ] Dependencies are acyclic; order is executable.
- [ ] A mid-level engineer could implement any leaf without asking clarifying questions.

## Anti-patterns (do not)

- Flat bullet lists without hierarchy or IDs.
- Leaves named "Implement feature" or "Add tests" without specifying what.
- Copy-paste acceptance criteria across leaves.
- Diagrams that contradict file structure or sequence sections.
- Skipping quality gates ("we'll verify manually").
- Planning code you have not looked at.
- Starting implementation in the same response unless the user asked for both.

## When the user attaches `/quality`

Re-read the user's request and this command. Rewrite the plan (or plan outline) with maximum precision: sharper acceptance criteria, tighter scope, stronger diagrams, explicit gates, and resolved ambiguities. Then present the improved plan — do not proceed to code until approved.
