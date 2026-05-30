Before planning or writing code, load the project skills that match the task.

## 1. Discover

- List `.cursor/skills/` (project skills first; check `~/.cursor/skills/` only if the task clearly needs user-global skills).
- Read each domain's index when present (e.g. `.cursor/skills/elixir/README.md`).
- For every candidate skill directory, read the YAML frontmatter `description` in `SKILL.md` — that field defines when the skill applies.

## 2. Select

Choose the **smallest sufficient set** of skills:

| Task signal | Skill(s) |
|-------------|----------|
| `.ex` / `.exs` idioms, refactoring, `@spec`, pure functions | `elixir-core` |
| GenServer, Supervisor, Application, process design | `elixir-otp-design` |
| Task, Flow, GenStage, Broadway, pipelines, back-pressure | `elixir-concurrency` |
| Contexts, plugs, router, Ecto, channels (not LiveView) | `elixir-phoenix` |
| LiveView, HEEx, components, streams, `handle_event` | `elixir-liveview` |
| Tests, ExUnit, coverage gaps | `elixir-testing` |
| Review, idiomaticity, pre-merge check | `elixir-review` |

Rules:

- Prefer **project** skills over generic model knowledge when both apply.
- Load **multiple** skills when the task crosses boundaries (e.g. OTP + Phoenix context + tests).
- Do **not** load skills for unrelated work (Rust tooling, infra-only edits, markdown-only changes).
- If nothing matches, say so briefly and proceed without forcing a skill.

## 3. Ingest

For each selected skill, **read the full `SKILL.md` before acting** — do not summarize from memory or from the description alone.

Then read linked `reference/` files **only when** the task needs that depth (Ecto queries, supervision trees, LiveView streams, test patterns, review checklist, etc.).

## 4. Apply

- Follow the skill's workflow, conventions, and anti-patterns for the rest of the task.
- When skills disagree with generic advice, **the skill wins** for this repo.
- Re-check skill selection if the user pivots (e.g. "add tests" → also load `elixir-testing`; "review this" → load `elixir-review`).

Do not announce skill loading unless the user asks; just read and apply.
