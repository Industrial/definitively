# E2E: Run serial suite and fix failures (ng-client, risk-calculator, tests)

## Objective

Run the **serial** end-to-end suite (`apps/e2e-test/bin/e2e-serial.sh`), then fix failures so the suite passes. Prefer fixing **product code** (usually **ng-client**; sometimes **risk-calculator** or API consumers) when behavior or selectors are wrong. Change **tests or page objects** when requirements changed or when you are aligning with documented intent in [`Interactions.txt`](../../Interactions.txt).

Work **one failing test at a time**: run the suite (or a single spec), fix the single failure, re-run, repeat.

## Codebase navigation

Use **[`.cursor/rules/roam.mdc`](../rules/roam.mdc)** before large refactors or when you need blast radius: `roam understand` / `roam tour` on first touch, `roam search`, `roam preflight <name>`, `roam context <name>`, `roam diagnose <name>`, `roam diff` after edits.

## How the suite maps to the product

- **[`Interactions.txt`](../../Interactions.txt)** describes the three high-level flows (individual onboarding, individual portal, demo supervisor).
- **[`history/interactions-e2e-coverage-plan.md`](../../history/interactions-e2e-coverage-plan.md)** tracks what is automated vs still manual (including the **“Update (implemented)”** section for recent specs and `data-testid` work).
- Serial specs include **unauthenticated**, **admin**, **supervisor** (index, demo, rationale, **select-profile**, **subject-panel-tabs**), **researcher**, **requester**, **individual** (index, home-pages, **welcome-chrome**, **profile-settings**, **my-data-interactions**, **data-gathering-flow**), **corporation**, and **onboarding**. The canonical list is **`E2E_SERIAL_SPECS`** in [`apps/e2e-test/bin/e2e-serial.sh`](../../apps/e2e-test/bin/e2e-serial.sh).

## How to run the E2E suite

From the **monorepo root**:

```bash
devenv shell -- bash -c "cd apps/e2e-test && bin/e2e-serial.sh"
```

- Specs: `apps/e2e-test/tests/**/*.spec.ts` (native Playwright, no Gherkin).
- Each entry runs with **one worker** and **`--max-failures=1`** per file.
- By default Playwright also starts **risk-calculator** (subscribe / data-gathering need `NG_CLIENT_API_URL`). Use `E2E_START_RISK_CALCULATOR=0` for faster runs when you only exercise Logto or unauthenticated UI (specs that call `subscribe-url` will fail without a running API).

To run **one** spec while iterating:

```bash
devenv shell -- bash -c "cd apps/e2e-test && bun x playwright test tests/individual/welcome-chrome.spec.ts --workers=1 --max-failures=1"
```

**Full** parallel suite (as in `playwright.config.ts`):

```bash
devenv shell -- bash -c "cd apps/e2e-test && bun run test:e2e"
```

List tests without executing:

```bash
devenv shell -- bash -c "cd apps/e2e-test && bun run test:e2e:list"
```

## How to interpret a failure

1. **Test title**: Reporter shows `describe` / `it` (e.g. `individual @e2e-serial-individual-welcome-chrome › …`).
2. **Spec file** and **line**: Open `apps/e2e-test/tests/.../*.spec.ts` and the **Effect** chain or helper (`loginWelcome`, `reachSelectProfile`, etc.).
3. **Which layer to fix**:
   - **UI / navigation / timing** → usually **ng-client** (routes, components, loading).
   - **Missing or flaky selectors** → add or fix **`data-testid`** in **ng-client** to match **page objects** under `apps/e2e-test/pages/` (prefer testids over brittle CSS for new surface).
   - **API / risk / scoring** → **risk-calculator** or the service the client calls, depending on where logic lives.

## Harness

- Import `describe`, `it`, `expect`, `test` from `apps/e2e-test/tests/fixtures.ts`.
- `it` runs an **Effect** program; use `Effect.gen` or helpers that return `Effect` (e.g. `loginWelcome`, `reachSelectProfile`).
- Coverage is often grouped with **nested `describe`** blocks (role → area → scenario).

## When a test fails: replay in browser first

**Before** editing code for interactive failures, use the **Cursor Browser MCP** (or a normal browser) to replay steps to the failure.

1. Ensure **ng-client** and dependencies (**Logto**, APIs) are running as needed.
2. Match the spec’s starting URL and steps until the assertion would fail.
3. Use snapshot / screenshot, console, and network to see real state.
4. Fix **implementation** or **stable selectors**; adjust tests only when product intent changed.

## Systematic process

1. **Run** — `devenv shell -- bash -c "cd apps/e2e-test && bin/e2e-serial.sh"` (or a single spec).
2. **Identify** — Failing spec, title, and Effect step / assertion.
3. **Replay in browser** — Required for UI/navigation failures.
4. **Navigate the codebase** — Prefer **roam** per [`.cursor/rules/roam.mdc`](../rules/roam.mdc); read spec → `tests/support/` → `pages/` → ng-client templates/components.
5. **Fix** — Product code and/or `data-testid`s; keep tests stable unless requirements changed.
6. **Re-run** — Same command until green.

## Key artifacts

| Area | Location |
|------|----------|
| Specs | `apps/e2e-test/tests/**/*.spec.ts` |
| Login → welcome (individual slot) | `apps/e2e-test/tests/support/loginWelcome.ts` |
| Index → Logto → select-profile (no profile chosen) | `apps/e2e-test/tests/support/reachSelectProfile.ts` |
| Page objects | `apps/e2e-test/pages/*.ts` |
| Locator helpers | `apps/e2e-test/lib/` (e.g. `locatorCount.ts` / `countByTestId`) |
| Playwright + Effect | `apps/e2e-test/tests/fixtures.ts`, `apps/e2e-test/lib/playwrightEffect.ts` |
| Serial list | `apps/e2e-test/bin/e2e-serial.sh` |
| Product UI | `apps/ng-client/` |
| Risk engine | `apps/risk-calculator/` |
| Interaction doc + coverage notes | `Interactions.txt`, `history/interactions-e2e-coverage-plan.md` |

## Rules

- Fix **one** failure at a time; re-run after each fix.
- **Replay in the browser** before guessing on UI failures.
- All shell commands via **`devenv shell --`**.
- When adding new e2e surface, register the spec in **`E2E_SERIAL_SPECS`** if it must run serially (shared auth/session), and update **`history/interactions-e2e-coverage-plan.md`** if it changes Interactions coverage.
- To narrow a long serial run while debugging, run a **single spec** with `bun x playwright test …` (see above); optionally temporarily trim `e2e-serial.sh` locally—do not commit ad-hoc removals unless intentional.
