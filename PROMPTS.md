# Sample Prompts

Production-grade sample prompts for every phase of the development lifecycle, combining **agent-skills** and **gstack** commands. Use these as starting points — swap in your actual feature name, bug description, or URL.

```
  IDEATE         DEFINE          PLAN           BUILD          VERIFY         REVIEW          SHIP          REFLECT
 ┌──────┐      ┌──────────┐   ┌──────────┐    ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │Brain │ ───▶ │ OpenSpec │──▶│ CEO/Eng/ │───▶│ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │ ───▶ │Retro │
 │storm │      │  Change  │   │  Design  │    │ Impl │      │Debug │      │ Gate │      │ Live │      │Learn │
 └──────┘      └──────────┘   └──────────┘    └──────┘      └──────┘      └──────┘      └──────┘      └──────┘
/office-hours     /spec        /plan-*          /build         /test        /review        /ship         /retro
                               /autoplan                      /investigate  /cso           /canary       /learn
                                                              /qa           /codex
```

---

## IDEATE — Brainstorm & Validate the Idea

> Before writing a spec, pressure-test whether you're solving the right problem.

- "I want to build a bug triage tool that automatically assigns issues to engineers based on file ownership and past blame history. `/office-hours` — before I write any code, push back on my framing. Is 'auto-assignment' actually the pain, or is the real problem that bugs sit unacknowledged for too long? Ask me the six forcing questions, challenge my premises, and tell me what the narrowest shippable wedge looks like."

- "We keep shipping features that users don't engage with — last quarter it was the custom dashboard and the bulk export. Run `/office-hours`. I want you to extract what pain I'm actually describing, challenge whether more features are the right lever, and generate at least 3 implementation alternatives with rough effort estimates. Write a design doc at the end that feeds into the plan stage."

- "I think our problem is the notification system, but users are actually complaining about the app feeling slow after 3 minutes of use. Use `idea-refine` to help me separate the symptom (notifications) from the root cause. Run divergent thinking first — what are all the things this could be — then converge on a concrete proposal I can spec."

- "We have 3 product directions on the table: (1) real-time collaboration, (2) an offline mode, (3) a mobile app. `/office-hours` — don't let me pick based on gut. Extract what each one is actually solving for, challenge the assumptions behind each, and recommend the wedge we should ship first based on effort vs. learning value."

- "I have a rough idea: a 'bug budget' feature that blocks deploys when the open bug count exceeds a threshold. Use `idea-refine` to stress-test it. What are the failure modes of this idea? What would make engineers hate it? What's the version that actually gets adopted? Give me a concrete proposal at the end."

---

## DEFINE — Write the Spec

> OpenSpec change artifact before any code.

- "Users are reporting a race condition on checkout — two tabs open at the same time can both decrement the same inventory item, resulting in overselling. `/spec` this fix. I want a `proposal.md` that explains the problem clearly, a `design.md` that covers at least 3 approaches (optimistic locking, pessimistic locking, idempotency keys) with tradeoffs, and a `tasks.md` with story-level slices. Be explicit about what we're NOT fixing in this change."

- "We want to add offline support to the mobile app — users should be able to create and edit records without a network connection and sync when they reconnect. `/spec` the change. The design must cover conflict resolution strategy, what data is eligible for offline use, how we handle sync failures, and the rollback plan if the sync worker corrupts data. Flag any assumptions that need product sign-off before implementation starts."

- "The auth session bug keeps reappearing — every 2-3 sprints someone touches the middleware and breaks session expiry. The root cause is we have no authoritative spec. Write one with `/spec`. Cover: what triggers expiry, what happens to in-flight requests, how we handle refresh tokens, what the UX is when a session expires mid-action, and the exact HTTP status codes and error shapes we return."

- "Product wants a CSV export. `/spec` the change — make sure we cover: (1) which fields are exportable and by whom, (2) encoding (UTF-8 with BOM for Excel compatibility), (3) the error shapes for empty result set, invalid date range, and unauthorized field access, (4) rate limiting for large exports, (5) what we are explicitly NOT building in v1 (streaming, scheduled exports, custom delimiters)."

- "There's a memory leak in the background sync worker — heap grows ~50MB/hour under normal load and never gets GCed. `/spec` the investigation and proposed fix. The proposal should include what we know so far (symptoms, reproduction steps), what we don't know (root cause), the investigation plan, and two candidate fixes with their risk profiles. Include a rollback plan if the fix makes things worse."

---

## PLAN — Architect and Review the Approach

> CEO, Eng, and Design eyes on the plan before implementation.

- "The checkout race condition spec is approved. `/plan-eng-review` — I need three things: (1) an ASCII diagram of the data flow through the inventory check, lock acquisition, and order commit steps, (2) a failure mode table covering network timeout, DB deadlock, and partial commit scenarios, and (3) a test matrix with what we're testing at the unit, integration, and E2E level. Call out any hidden assumptions in the current design."

- "Run `/plan-ceo-review` on the offline support spec. I want you to find the 10-star version hiding inside this feature request — what would it look like if we solved the real problem instead of the stated one? Then run all four modes: Expansion (what should we add?), Selective Expansion (what's worth adding?), Hold Scope (what's exactly right?), and Reduction (what should we cut for the first ship?). Recommend one."

- "The auth session spec is ready but I'm not confident in the approach. `/autoplan` — run CEO → design → eng review in sequence. For CEO: challenge whether session-based auth is the right direction vs. short-lived JWTs. For design: rate the user-facing expiry flow 0-10 and tell me what a 10 looks like. For eng: draw the state machine for session lifecycle and list the edge cases we haven't handled. Surface only the decisions that require my taste."

- "We have three approaches to fix the memory leak: (1) fix the event listener leak in the scheduler, (2) add a periodic GC call with a heap size cap, (3) restart the worker process when heap exceeds 200MB. `/plan-eng-review` — build the decision matrix. What are the failure modes of each, which is safest for a trunk-based rollout with a feature flag, and what does the test plan look like for each option? Recommend one with a rationale."

- "The CSV export plan looks straightforward on the backend, but we're exposing it to developers via API. `/plan-devex-review` — test it against a developer integrating for the first time. What's the time-to-first-export? Where does the documentation fail them? What error message will they hit first and is it actionable? Compare against Stripe's CSV export DX as a benchmark."

- "Run `/plan` to decompose the offline support change into shared story-level tasks. I want slices thin enough that each one is independently shippable with a feature flag. The first slice should touch the minimum number of files possible and give us real learning about the conflict resolution strategy. Generate a `tasks.md` and an `execution.md` with the dependency order."

---

## BUILD — Implement One Slice at a Time

> Thin vertical slices, feature flags, rollback-friendly.

- "Build the first slice of the checkout race condition fix — just the mutex/lock acquisition around the inventory check. Feature flag it off by default using our existing `featureFlags.isEnabled()` pattern. Don't touch the order commit logic yet. Write the unit test first (red), then implement (green), then check if there's anything to refactor. The test should cover: lock acquired successfully, lock already held by another request, lock timeout."

- "Implement the session expiry handler using TDD. Start with the failing tests: (1) token expired → 401 with `error: 'session_expired'`, (2) token missing → 401 with `error: 'unauthenticated'`, (3) token valid but user deactivated → 403 with `error: 'account_disabled'`, (4) refresh token valid → 200 with new access token. Make each test pass one at a time. Don't move to the next until the current one is green."

- "Build the CSV export endpoint contract-first. Before writing any implementation code, define the full response schema in `openapi.yaml`: the `Content-Disposition` header, the `Content-Type`, the query params (`fields`, `date_range`, `format`), and the error shapes for empty result set, invalid date range, and fields that don't exist. Only start implementation after I've reviewed and approved the contract."

- "The memory leak is in the sync scheduler's event listener — it registers a new `'data'` listener on every sync cycle without removing the previous one. Implement the fix: unsubscribe in the cleanup path and add a guard that throws if a listener is registered twice on the same channel. Feature flag it with `sync.useCleanupGuard`. Safe default is `false` — existing behavior unless the flag is on. Write the test first."

- "Build the offline queue — first slice only: capture `CREATE` mutations locally when offline is detected, persist them to IndexedDB, and replay them in order when connectivity is restored. Don't handle conflicts yet (that's slice 2). Use incremental implementation: implement → test → verify → commit. Each commit should be a working state, never half-implemented."

- "Ground the WebSocket implementation in official docs before writing any code. `/source-driven-development` — look up the MDN WebSocket API and the `ws` library changelog. Cite the specific API contract you're implementing against, flag anything that differs between browser and Node.js environments, and note anything that's unverified so I can review those decisions."

---

## VERIFY — Find Bugs, Debug, and Prove It Works

> Tests are proof. Reproduce before fixing.

- "The checkout fix is deployed to staging but the race condition still flakes under load — about 1 in 50 requests. `/investigate` — Iron Law: no fix without root cause. Start by reproducing it deterministically (try concurrent wrk load at 50 RPS). Then localize: is the lock acquisition failing, timing out, or is there a second unguarded path? Reduce to the minimal reproduction. Don't propose a fix until you've identified exactly which line is the problem."

- "Tests pass locally but the session expiry test fails in CI with a timing-related error — `expected 401 got 200` on the token-expired case. `/investigate` — this is almost certainly a clock skew or test isolation issue, but prove it. Check: (1) is the test using real time or a mocked clock, (2) are tests running in parallel and sharing state, (3) is the token TTL short enough that it expires between generation and assertion? Trace the exact execution path in CI."

- "Run `/qa` on `https://staging.myapp.com/checkout`. Click through the full checkout flow: add 3 items, proceed to payment, enter card details, submit. Also test the race condition: open two tabs simultaneously and attempt checkout in both within 500ms. For every bug you find: fix it with an atomic commit, write a regression test that would have caught it, then re-verify. Report the before/after for each fix."

- "The CSV export returns garbled characters for filenames with accents (e.g., `café.csv` becomes `cafÃ©.csv`). `/investigate` five-step triage: (1) reproduce with a minimal test case — a single row, accented filename, (2) localize — is it the filename generation, the Content-Disposition header encoding, or the HTTP client decoding it wrong?, (3) reduce — what's the simplest input that triggers it?, (4) fix with the correct RFC 5987 encoding, (5) guard with a test that checks UTF-8 filenames explicitly."

- "Write the full test suite for the offline queue — test pyramid: 80% unit (queue operations: enqueue, dequeue, retry, discard), 15% integration (IndexedDB persistence across page reload, replay order after reconnect), 5% E2E (actually go offline in a browser, create a record, come back online, verify sync). Use DAMP over DRY — each test should be readable in isolation even if it means some repetition."

- "Run browser devtools on the sync worker after the memory leak fix. Open DevTools → Memory tab, take a heap snapshot, trigger 10 sync cycles, take another snapshot. Compare: are the detached DOM nodes and event listener counts stable? Check the console for any `MaxListenersExceeded` warnings. Check the network tab for any failed sync requests that might be swallowing errors silently."

- "Use `/qa-only` on the sync worker after the memory leak fix. Browse to `https://staging.myapp.com`, trigger 10 consecutive sync cycles, and monitor the heap. Report only: current heap after each cycle, whether it plateaus or grows, any console errors or warnings, and whether the `useCleanupGuard` flag is being read correctly. Do not make any code changes — pure report."

---

## REVIEW — Quality Gates Before Merge

> Staff engineer standard. Find bugs that pass CI but blow up in production.

- "The checkout race condition fix PR is ready — 3 files changed, ~80 lines. `/review` — five-axis check: correctness (does the lock actually prevent double-decrement?), security (can the lock be bypassed by a malformed request?), performance (what's the lock contention at p99?), maintainability (is the lock scope too broad — are we holding it longer than necessary?), test coverage (do the tests cover the concurrent case?). Auto-fix anything obvious. Flag the lock timeout value — I'm not sure 500ms is right."

- "Run `/cso` on the new auth middleware. OWASP Top 10 scope: focus on A01 (Broken Access Control) and A07 (Authentication Failures). STRIDE threat model for the session refresh flow specifically. Zero-noise mode — only report findings with 8/10+ confidence, and for each finding include a concrete exploit scenario, not just a category label. Verify each finding independently before reporting it."

- "The CSV export handler is 340 lines and getting hard to follow. `/code-simplify` — Chesterton's Fence first: read the whole file and tell me why each major block exists before suggesting removing anything. Then apply Rule of 500 — the file should be under 200 lines after simplification. Preserve exact behavior, including the edge cases for empty datasets and the fallback encoding path."

- "Run `/codex` on the session expiry handler in adversarial mode — actively try to break it. Specifically: can you construct a token that passes expiry validation but shouldn't? Can you trigger a 200 when a 401 is expected by manipulating the clock or the token payload? Can you cause an unhandled exception that results in a 500 instead of a proper auth error? Report pass/fail with specific attack vectors."

- "Run `/benchmark` on the checkout flow before and after the race condition fix. Baseline: page load, Time to Interactive, and checkout submit latency at p50/p95/p99. Post-fix: same metrics with the lock enabled. If the lock adds more than 50ms at p95 checkout submit time, block the PR — that's a regression. Include the bundle size delta too — the lock library shouldn't add more than 5KB gzipped."

- "Run `/cso` on the CSV export endpoint. Specific concerns: (1) path traversal — can a crafted `fields` param read columns from other tables?, (2) injection — is the field list interpolated into a raw SQL query anywhere?, (3) content-type — can we trick the browser into executing the CSV as HTML?, (4) authorization — does the endpoint check that the requesting user has access to the requested date range and fields?"

- "The memory leak fix touches 6 files. Before running `/review`, check change size — is this actually one change or three? If it's fixing the listener leak AND adding the guard AND updating the tests, consider splitting into two PRs: the fix (small, targeted, fast to review) and the guard (additive, lower risk). `/review` should flag if the diff is too large to review meaningfully."

---

## SHIP — Deploy With Confidence

> Staged rollout. Faster is safer. Monitor before celebrating.

- "Run `/ship` on the checkout race condition fix. Before pushing: sync main, run the full test suite, check that the feature flag is defaulting to `false` (old behavior for all users), audit coverage — it should not drop below 78%. Open the PR with a description that explains the race condition, the chosen fix, the alternatives we considered, and the rollback procedure (disable the flag)."

- "The auth session fix is merged and CI is green. `/land-and-deploy` — don't declare done until production is verified. After the deploy: check that the `/health` endpoint returns 200, hit the session expiry flow manually with an expired token and confirm you get a 401 with the right error shape, and check the error logs for any unexpected 500s in the first 5 minutes. Only then mark the task complete."

- "Start `/canary` on the offline sync worker after deploy — monitor for 45 minutes. Watch for: (1) heap size growing beyond 150MB (the pre-fix baseline was 200MB/hour), (2) any `SyncError` or `ListenerAlreadyRegistered` exceptions in the console, (3) failed sync requests in the network tab, (4) any page performance regressions vs. the `/benchmark` baseline. Alert me immediately if any threshold is crossed."

- "The CSV export is live and stable. `/document-release` — read every doc file in the project and update anything that drifted: the API reference (new endpoint, new query params, error shapes), the CHANGELOG (this is a new feature, not a bug fix — use 'add'), the README usage section (add the export example), and `openapi.yaml` (verify it matches the implementation, not the original contract). Flag any doc that refers to the old `/v1/export` endpoint."

- "Write the ADR for choosing pessimistic locking over optimistic locking for the inventory check. `/documentation-and-adrs` — format: context (what made this decision necessary), options considered (optimistic with retry, pessimistic with timeout, idempotency key), decision (pessimistic, 500ms timeout), consequences (higher latency under contention, simpler retry logic, no need for version columns). This decision should be traceable from the bug report to the code."

- "Run `/ship` on the offline queue — the project has no test framework. Bootstrap one (use Vitest, it's already in our `package.json` devDependencies), generate a coverage baseline for the offline queue module specifically, then run the ship workflow. The PR description should include the coverage baseline so future PRs can be measured against it."

- "Deprecate the old `/v1/checkout` endpoint now that the race condition fix is live on `/v2/checkout`. Generate the migration guide for API consumers: what changed, how to update their integration, code examples for before/after, the sunset date (90 days from today), and the HTTP deprecation headers (`Deprecation`, `Sunset`, `Link`) we're adding to every `/v1/checkout` response."

---

## REFLECT — Learn and Compound

> What broke, what held, what to do differently.

- "Run `/retro` for this sprint. I want three things: (1) a per-person breakdown of what shipped, (2) a specific analysis of the race condition incident — where did the spec, tests, and review fail to catch it, and what process change would have caught it earlier?, (3) a shipping streak summary — how many PRs had failing tests before merge? What's our trend?"

- "Run `/retro global` — cross all my active projects for the last 2 weeks. How many bugs were caught by `/qa` before reaching production vs. found by users? What's the ratio of spec-driven features vs. ad-hoc ones, and does spec-driven correlate with fewer post-ship bugs? Surface the top 3 patterns that are costing the most rework time."

- "Run `/learn` after this sprint. Specifically: (1) record the race condition pattern — mutex scope too broad, lock held across I/O, (2) record the UTF-8 filename encoding pattern as a known gotcha for CSV exports, (3) prune any stale learnings about the old auth middleware (we've replaced it). Make sure the memory leak pattern is searchable by 'event listener' and 'scheduler'."

- "After the race condition incident: `/retro` with a focus on where our process broke down. Specifically: the bug existed for 6 months and passed code review 3 times. What did `/review` miss? Was it not running `/cso`? Was the test not covering the concurrent path? Generate a specific process addition — one concrete gate we add to the review checklist that would have caught this."

- "We shipped the offline queue with 3 bugs found in `/qa` that should have been caught by unit tests. Run `/retro` focused on test quality. Which tests were missing? Were they missing because we didn't write them, or because we didn't know what to test? Use `/learn` to record the patterns — specifically what offline/sync edge cases to always test — so the next feature that touches IndexedDB starts with that knowledge."

---

## Bug-Specific End-to-End Chains

> Full lifecycle prompts that chain multiple skills for a complete bug workflow.

- "Production bug: checkout silently drops items under high load — no error, the item just disappears from the cart. Full chain: `/investigate` to localize (is it the lock, the cart serialization, or the session?), then `/qa` on staging to reproduce and fix with regression tests, then `/review` to gate the fix (five-axis + `/codex` adversarial), then `/ship` with a staged rollout at 5% → 25% → 100%, then `/canary` for 30 minutes post-deploy."

- "Security report: session tokens are appearing in our application logs — likely being logged as part of the Authorization header in request logging middleware. `/cso` to assess blast radius (how long has this been happening, what logs need rotation?), `/spec` the fix (stop logging the header entirely vs. redact it vs. switch to a custom header), `/review` before merge with `/codex` adversarial to verify the redaction is complete, `/canary` after deploy to confirm no tokens appear in new log lines."

- "Performance regression reported after last Thursday's deploy — checkout page Time to Interactive went from 1.2s to 3.8s on mobile. `/benchmark` to confirm and get the exact delta, `/investigate` to localize (is it the new lock library, the changed session middleware, or a bundle size regression?), `/review` to gate the fix, `/ship` with the benchmark included in the PR description so reviewers can see before/after numbers."

- "Flaky E2E test that fails 1 in 10 runs — the offline sync test that goes offline, creates a record, comes back online, and checks IndexedDB. `/investigate` — it's probably a timing issue between the network being marked online and the sync worker polling. Reproduce it deterministically (add artificial delay in the polling interval), fix it (use an event-based trigger instead of polling), re-run 20 times to confirm it's stable, then add it to the required CI gate."

- "Bug found in `/qa-only` report: the CSV export includes soft-deleted records when the `include_deleted` param is not passed. Full chain: take the report, `/investigate` to confirm the query is missing the `deleted_at IS NULL` clause, fix it with a targeted one-line change, `/cso` to check if this is a data exposure issue (it is — soft-deleted records may contain PII), escalate to security review before merging, `/ship` with a hotfix branch bypassing the normal sprint queue."

- "Memory leak reappeared after a dependency upgrade — `ws@9.0` changed event emitter behavior and our cleanup guard no longer fires. `/investigate` to confirm it's the library change (check the `ws` changelog for breaking changes in event handling), `/source-driven-development` to read the official `ws@9.0` migration guide and cite the correct API, implement the fix, `/codex` for a second opinion on the new cleanup pattern, `/ship` and restart `/canary`."
