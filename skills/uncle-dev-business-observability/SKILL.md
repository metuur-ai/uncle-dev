---
name: uncle-dev-business-observability
description: Brings an observability mindset to feature work — decides conceptually whether a custom metric is warranted, what it should measure, whether it's a business or operational metric, and whether dimensions are needed, then delegates tool-specific implementation to a configured companion skill. Also covers connecting telemetry to business outcomes via Critical User Journeys, journey-scoped SLOs, and error-budget alerting. Use during spec or task breakdown to decide "should we add a metric here / what should we measure"; when adding observability to a service; when alerts fire that nobody can tie to user or revenue impact; when defining SLOs/SLIs; when on-call suffers alert fatigue; or when a stakeholder asks "is this incident actually hurting customers?". Stays technology-agnostic — NOT for picking a telemetry library, writing emit code, or raw infrastructure monitoring setup.
---
## Overview

Uptime is a vanity metric if it doesn't correlate with customer outcomes and revenue. Business observability instruments the **user's journey**, not the server, so a latency spike is immediately legible as "the Checkout path is degrading, ~$X/min at risk" instead of an anonymous graph. This skill is the procedure to get there: pick a journey, instrument it with business context, define journey-scoped SLOs, and alert on error-budget burn — not on host thresholds.

SKILL.md is the entry point — a 7-step procedure. Deep material lives in colocated references, loaded only when a step needs it:

| Load when you reach… | Reference |
| --- | --- |
| Deciding if a custom metric is warranted — decision tree, worked examples, metric-spec contract, delegation lookup | `references/metric-necessity-test.md` |
| Strategy, maturity model, value framing, criticality tiers | `references/strategy-and-maturity.md` |
| Step 3/6 — SLI PromQL, error-budget math, burn-rate thresholds, SLO targets by tier | `references/slo-cookbook.md` |
| Step 6 — alert patterns, routing/escalation, runbook template, noise metrics | `references/alert-design.md` |
| Step 5 — dashboard layout, role archetypes, panel/chart selection | `references/dashboard-design.md` |
| Steps 2–6 when the stack is **AWS CloudWatch** — metric model, dimension limits, RUM, alarms | `references/cloudwatch-implementation.md` |

## When to Use

- Adding observability to a new or existing service and you want it tied to outcomes, not just infra.
- Alerts fire but nobody can answer "what user-facing thing is broken, and does it matter?"
- Defining SLIs/SLOs, error budgets, or burn-rate alerts for a product.
- On-call is drowning in alerts that have no user impact (alert fatigue).
- A PM/exec asks for a dashboard that speaks in conversion/revenue, not p99.

**NOT for:** standing up raw infrastructure dashboards (CPU/disk/memory), log-aggregation plumbing, or APM tool installation in isolation. Those are inputs to this skill, not the goal.

## Decide First: Is a Custom Metric Warranted?

Before instrumenting anything, run this conceptual gate. **The default is NO.** Generic auto-instrumentation (RED per endpoint, USE per resource), logs, and traces already answer most questions; a *custom* metric must earn its place. Do not put a metric on every method, class, or branch — instrument meaningful business behavior, not code structure.

**Where metrics usually earn their place** — these are *candidates*, not mandates; each still has to pass the five gates below:

- Calls to **downstream APIs** — success vs failure rates.
- Important **business events** / domain event types.
- **Authentication and authorization failures.**
- **Database operations** whose failure is significant to a specific business flow.
- **Publishing to queues / streams / topics** — success and error outcomes.
- Specific **response codes** returned by downstream systems or databases.
- **Error codes/conditions that trigger compensating actions**, retries, alerts, or alternative flows.
- Critical **business decisions or state transitions** worth monitoring.

Add these intentionally and sparingly. Excessive metrics create noise and cardinality and make observability *less* useful, not more.

A candidate metric is warranted only if it passes **all five gates**:

1. **Action** — a named person/role changes a decision based on the value. (No action → vanity metric, drop.)
2. **Coverage** — it is *invisible* to generic instrumentation/logs/traces. (Already covered → use what exists.)
3. **Aggregate** — the question is "how many / how often / how much / how fast, in aggregate." ("What happened in this one case / why did THIS fail?" → that's a **log or trace**, not a metric.)
4. **Durable** — the behavior deserves a long-lived named series and dashboard panel, not a one-off look. (Curiosity → query logs ad-hoc.)
5. **Worth it** — the ongoing storage/cardinality cost is justified (re-check after dimensions).

For each metric that survives, answer the four questions this skill exists to answer:

- **Business or operational?** Litmus: *if the system were fine but this number moved, would a non-engineer care?* Yes → **business** (domain outcome; product owns it; executive dashboard). No → **operational** (system health; SRE owns it; engineering dashboard).
- **What to measure?** The outcome at the **business-meaningful boundary**, not the method call — `payment_captured` (confirmed), not `capture() invoked`. Pick the conceptual instrument by question shape: **counter** (how many), **distribution** (how long/big, read as percentiles), **gauge** (how many right now).
- **Why is it valuable?** Write the one-line question it answers. If you can't, it fails gate 1.
- **Dimensions?** Add one *only* when someone will segment by it to make a decision — and you can name the comparison ("failing more on `provider=stripe` vs `adyen`?"). Dimensions must be **bounded/low-cardinality**; never IDs, emails, raw amounts, or free text (those belong on logs/traces).

For the full decision tree, the worked good/bad examples, and the metric-spec contract, load `references/metric-necessity-test.md`.

### The output: a Measurement Plan (technology-agnostic)

The product of this gate is **not** emit code — it is a list of **metric specs**, each stating name, kind (business/operational), instrument, the question it answers, dimensions + the reason for each, and owner. Example:

```yaml
metric:
  name: payments_captured          # domain language, not code symbol
  kind: business                   # business | operational
  instrument: counter              # counter | distribution | gauge (conceptual)
  question: "How many payments succeed, trending by provider and plan?"
  dimensions:
    - { name: provider, reason: "compare success across providers" }   # bounded set
    - { name: plan_tier, reason: "are paid customers disproportionately hit?" }
  owner: payments-team
  dashboard_layer: executive       # executive | engineering
  implementation: delegated
```

### Where this runs in the lifecycle

- **Spec** (`uncle-dev-spec-driven-development`): for each behavior/acceptance criterion, run the test; attach surviving specs as the Measurement Plan. Most criteria yield zero metrics — expected and correct.
- **Task breakdown** (`uncle-dev-planning-and-task-breakdown`): each surviving metric becomes one instrumentation subtask, owned by the implementation companion.
- **Build**: the companion emits it; verify it actually answers its question.

### Delegate implementation to a configured companion

This skill stays conceptual. The *how* — OpenTelemetry, Prometheus, Datadog, CloudWatch, exporters, SDK calls, naming conventions — is owned by a project-configured companion skill, looked up via the project config helper (never read the YAML directly):

```bash
bash scripts/uncle-dev-config.sh --list skills.companions.uncle-dev-business-observability path
```

- **Companion path returned** → load it and hand over each metric spec to implement in the project's telemetry stack (it maps `kind`/`instrument`/`dimensions` onto its library and cardinality limits).
- **Empty** → deliver the Measurement Plan and **stop**. Tell the user no telemetry-implementation companion is configured and that one can be added via `/uncle-dev-custom-me companion uncle-dev-business-observability <name>` or by editing `skills.companions` in `.agents/uncle-dev-setup.yaml`. **Never guess a telemetry library or write emit code.**

## Core Process

```
1. JOURNEY   → Pick ONE critical user journey; write it as objective→action→success
2. INSTRUMENT→ Trace it end-to-end with OpenTelemetry + business span attributes
3. SLO       → Define an SLI + SLO + error budget per journey step
4. CRITICALITY→ Right-size instrumentation by business impact (control cost)
5. DASHBOARD → Two layers: executive (business) → engineering (telemetry), linked
6. ALERT     → Burn-rate alerts routed by journey severity, with business context
7. LOOP      → Each incident retro proves the instrumentation caught it, or files a gap
```

Do not instrument everything at once. Ship one journey fully (steps 1–7) before starting the next — a half-instrumented journey gives false confidence.

### Step 1 — Pick one Critical User Journey (CUJ)

Choose a single revenue-bearing or core journey (Checkout, Send Mail, Sign-up). Write it as an ordered table — this is the contract between Product and Engineering:

| User Objective | User Action | Technical Success Condition (RPC / Telemetry) |
| ------ | ------ | ------ |
| Checkout | Submit payment | `PaymentService` 2xx; duration < 2s |
| Checkout | Confirm order | `OrderService` writes order; event emitted |

> **Verify:** A non-engineer reads the journey and agrees it describes what the user is trying to do.

### Step 2 — Instrument end-to-end with OpenTelemetry

Use **OpenTelemetry** (vendor-neutral) so you are not locked to one backend.

- Propagate one **trace context** across every hop (gateway → services → datastore). Do not start a fresh trace per service.
- On the root/journey span, attach **business attributes** (low-cardinality, no PII):

```python
# Annotate the journey span with business metadata
span.set_attribute("journey.name", "checkout")
span.set_attribute("journey.step", "submit_payment")
span.set_attribute("customer.tier", tier)            # e.g. "free" | "pro"
span.set_attribute("cart.value_bucket", bucket(total))  # bucketed, not raw amount
```

- Emit the **Golden Signals** per step: rate, errors, duration, saturation — and **cost** (cloud/run cost per request where available) as the modern 5th signal.

Pick the signal per question: **metrics** tell you *that* something is wrong (RED — Rate/Errors/Duration — on every step and dependency; USE — Utilization/Saturation/Errors — on resources), **traces** tell you *where*, **logs** tell you *why*. Track latency as a histogram and read percentiles (P95/P99) — averages hide the slow tail that drives abandonment.

On AWS CloudWatch, prefer the OTLP path over traditional dimensions, and instrument the client side of Critical journeys with RUM — load `references/cloudwatch-implementation.md`.

> **Verify:** A single trace for one real request shows every journey step with its `journey.*` attributes attached.

### Step 3 — Define an SLI + SLO + error budget per step

An **SLI** is `good events / valid events`. Each step gets an SLI, an SLO target, and an error budget (`1 − SLO`):

| Step | SLI | SLO target |
| ------ | ------ | ------ |
| Submit payment | `% requests < 2s AND 2xx` | 99.5% / 28 days |
| Address lookup | `% lookups < 500ms` | 99.9% / 28 days |

The error budget is `(1 − SLO) × window` — e.g. 99.9% over 30 days ≈ 43.8 min of allowed failure. It is the decision tool: budget healthy → ship features; budget burning → freeze and stabilize. Set targets by criticality (Critical revenue paths 99.95–99.99%; Standard 99.5–99.9%) and remember a service is no more reliable than the product of its hard dependencies (3 × 99.9% ≈ 99.7% ceiling).

Pick a good SLI: measurable, meaningful (reflects UX), controllable, proportional. Never use CPU/memory or raw counts as the SLI. For the PromQL formulas, the per-tier target tables, the dependency math, and error-budget policies, load `references/slo-cookbook.md`.

> **Verify:** Every journey step has exactly one SLI definition, one SLO target, and a computed error budget.

### Step 4 — Right-size instrumentation by criticality

Telemetry storage/egress is real OPEX. Classify each journey and match the investment (full table in `references/strategy-and-maturity.md`):

- **Critical** (revenue paths) → end-to-end + client-side instrumentation.
- **Important** (failover, spam filters) → server-side SLOs.
- **None** (internal tools, unlaunched) → baseline monitoring only.

> **Verify:** Telemetry spend is concentrated on Critical journeys; auxiliary features are not over-instrumented.

### Step 5 — Build dashboards in two linked layers

- **Executive layer** — one tile per CUJ: SLO status, error-budget remaining, expressed as conversion / revenue-at-risk / CSAT proxy.
- **Engineering layer** — the underlying traces, Golden Signals, saturation — linked from each executive tile.

Keep ≤ 7±2 panels per screen, most-important top-left, every number shown against a comparison (previous period / target / SLO line). For role archetypes (exec / SRE / dev), layout patterns, and panel/chart selection, load `references/dashboard-design.md`.

> **Verify:** From an executive tile, a responder reaches the offending service's telemetry in **one click** — killing the manual-interpretation lag.

### Step 6 — Alert on burn rate, routed by severity

Replace static-threshold alerts with **multi-window burn-rate alerts** on the error budget. Both a short and a long window must breach to fire — short = fast detection, long = no flapping:

- **Fast burn** — 2% of budget in 1h (5m + 1h windows, `14.4 × (1−SLO)`) → **page**.
- **Slow burn** — 10% of budget in 3d (6h + 3d windows) → **ticket**.

Alert on **symptoms users feel, not causes** (page on journey latency/errors, not CPU). Use only two severities (page / ticket); suppress downstream alerts when an upstream dependency is already firing (inhibit rules). Every alert links a **runbook** and carries business context: "Checkout error budget burning — ~$X/min at risk", not a hostname.

For the burn-rate PromQL, load `references/slo-cookbook.md`; for routing/escalation, inhibition, the runbook template, and noise metrics, load `references/alert-design.md`.

> **Verify:** A test alert names the affected journey and its business impact, links a runbook, and was test-fired once.

### Step 7 — Close the loop in incident review

After every incident, confirm the journey instrumentation actually detected it and pointed at the cause. If it didn't, the gap (missing span attribute, SLI, or burn-rate alert) becomes a backlog item. This is what moves the org up the maturity model.

> **Verify:** Each incident retro produces either "observability caught it correctly" or a concrete instrumentation fix.

## Gotchas

- **High-cardinality attributes blow up cost and break backends.** Never tag spans with raw user IDs, full cart totals, emails, or request bodies. Bucket (`cart.value_bucket`), hash, or omit. Metrics with unbounded label values are the #1 cause of observability bill shock.
- **An SLO without an error budget is just a dashboard number.** The budget (and burn-rate alerting on it) is what changes behavior. Defining the target alone accomplishes nothing.
- **Client-side telemetry carries ISP/device noise** — lower confidence than server SLIs. Use it for breadth (real UX) but cross-reference server-side before declaring an incident.
- **Trace context must be propagated, not regenerated.** A new trace ID per service yields disconnected spans and destroys the end-to-end view. Use the OTel propagators; check that downstream spans share the root `trace_id`.
- **CloudWatch caps dimensions at 30 (traditional) vs 150 OTLP labels, and does not aggregate across custom-metric dimensions.** Each unique dimension combination is a separate, separately-billed metric you can only query by the exact combination you published. RUM custom/extended metrics share a hard cap of 2000 definitions per destination. See `references/cloudwatch-implementation.md`.
- **Percentiles need raw data points.** A pre-aggregated statistic set (Min/Max/Sum/Count) generally can't produce P95/P99 — publish raw points or histograms for latency SLIs.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We already have CPU/memory dashboards, we're observable." | That's monitoring the surface. Without journey-scoped signals you can't tell a revenue outage from a cosmetic one. |
| "Let's instrument every service equally for completeness." | Equal instrumentation = alert fatigue + cost. Tier by criticality (Step 4) and concentrate on revenue paths. |
| "Static thresholds (CPU > 80%) are simpler than SLOs." | Thresholds alert on causes, not user pain, and fire constantly without impact. Burn-rate on an SLO alerts only when the user promise is at risk. |
| "We'll add the business context tags later." | Later never comes, and retrofitting trace attributes across services is far costlier than adding them at instrumentation time. |
| "The APM vendor's auto-instrumentation covers it." | Auto-instrumentation captures spans, not *business* meaning. `journey.name`/`journey.step` are yours to add. |
| "One big dashboard is fine for everyone." | Execs can't read p99 and engineers can't act on 'conversion down'. Two linked layers serve both and cut decision latency. |
| "Instrument every method so we have full coverage." | Coverage ≠ insight. A metric per method is cost and noise that buries the few that matter. Default to NO; pass the five gates first. |
| "Just make it a metric so we can see what happened to this request." | Per-case "what happened / why" is a log or trace. Metrics answer aggregate questions; forcing a per-case question into a metric explodes cardinality. |
| "Add every field as a dimension, might need them later." | Each dimension multiplies series and cost. Add one only when you can name the decision-driving comparison; IDs/emails/amounts never. |
| "Pick the telemetry library now while we're here." | This skill decides *what/why*. The library/emit code is the companion's job — guessing it here couples conceptual decisions to one tool. |

## Red Flags

- Alerts fire but the responder can't state which user journey or revenue path is affected.
- SLOs defined with no error budget or no burn-rate alert attached.
- Spans tagged with raw IDs, emails, or unbucketed monetary values (cardinality bomb).
- Every service instrumented at the same depth regardless of business impact.
- Dashboards that only show infra metrics, with no journey/business tile.
- Disconnected traces — services starting new trace IDs instead of propagating context.
- "Observability" project that never names a single Critical User Journey.
- A metric added per method/class/branch rather than per meaningful business behavior.
- A custom metric that no named role acts on, or that duplicates auto-instrumentation/logs.
- A per-case "why did THIS fail" question implemented as a metric instead of a log/trace.
- Dimensions that are unbounded (IDs, emails, amounts, free text) or that map to no stated comparison.
- A metric whose spec doesn't declare business-vs-operational, owner, or the question it answers.
- Tool-specific emit code written by this skill instead of delegated to the configured companion.

## Verification

When deciding whether to add a metric, confirm:

- [ ] Each proposed metric passed all five gates (action, coverage, aggregate, durable, worth it); rejected candidates were left to logs/traces/auto-instrumentation.
- [ ] Each surviving metric has a spec declaring kind (business/operational), instrument, the question it answers, dimensions + per-dimension reason, and owner.
- [ ] Every dimension is bounded; no IDs/emails/amounts/free text as dimensions.
- [ ] Implementation was delegated: the companion lookup ran, and either a companion implemented it or the Measurement Plan was delivered with a note that none is configured. No telemetry library was guessed here.

When applying this skill to a journey, confirm:

- [ ] One Critical User Journey is written as objective → action → success condition, approved by a non-engineer.
- [ ] A real end-to-end trace shows every step with `journey.*` business attributes and no high-cardinality/PII tags.
- [ ] Each step has an SLI, an SLO target, and an error budget.
- [ ] Instrumentation depth matches the journey's criticality tier.
- [ ] An executive dashboard tile drills to engineering telemetry in one click.
- [ ] Burn-rate alerts (fast + slow) are wired, routed by severity, link a runbook, carry business context, and were test-fired once.
- [ ] The incident-retro loop is established (catches were verified, or gaps were filed).
