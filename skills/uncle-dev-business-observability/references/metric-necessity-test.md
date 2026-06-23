# The Metric Necessity Test — Decision Tree, Examples, and the Handoff Contract

Load this from the **"Decide First"** section of SKILL.md when you are deciding, for a specific piece of feature logic, whether a custom metric should exist — and, if so, what it should measure and whether it needs dimensions. This reference is conceptual and technology-agnostic. It never says *how* to emit a metric; that is delegated (see the bottom).

## Why a gate exists

The failure mode is instrumenting everything — a metric per method, class, or branch. That produces cost, cardinality, and dashboards no one reads, while burying the few numbers that matter. The discipline is the inverse: **the default is NO custom metric.** Generic auto-instrumentation (RED per endpoint, USE per resource), logs, and traces already answer most questions for free. A *custom* metric must earn its place by passing every gate below.

## Where to look for candidates

These are the pieces of logic that *typically* yield meaningful business or operational visibility. Treat them as a shortlist to run through the gates — not a checklist to instrument wholesale:

| Candidate signal | Usually | Typical kind |
| --- | --- | --- |
| Calls to downstream APIs | success/failure rate, latency | operational (or business if it *is* the outcome) |
| Important business events / domain event types | count/rate | business |
| Authentication & authorization failures | count/rate, by reason | operational (security-adjacent) |
| Database operations critical to a business flow | failure rate, by operation | operational |
| Publishing to queues / streams / topics | success vs error outcomes | operational |
| Specific response codes from downstream systems/DBs | count by code class | operational |
| Error conditions triggering compensating actions, retries, alerts, alternate flows | count/rate, by condition | operational |
| Critical business decisions / state transitions | count/rate, by from→to state | business |

The discipline is the same for all of them: **intentional and sparing.** A candidate that no one acts on, or that auto-instrumentation already shows, does not become a metric just because it appears on this list. Over-instrumenting these creates noise and cardinality and makes observability *less* useful.

## The five gates (all must pass)

```
Candidate metric for this logic
        │
        ▼
1. ACTION   — Will a named person/role change a decision or take an action
              based on this value?  ── no ──▶  DROP (vanity metric)
        │ yes
        ▼
2. COVERAGE — Is it already visible via generic instrumentation
              (auto RED/USE, existing logs/traces)?  ── yes ──▶  DROP (use what exists)
        │ no — it's a domain event/state invisible to generic signals
        ▼
3. AGGREGATE— Is the question "how many / how often / how much / how fast,
              in aggregate over time?"
              "what happened in THIS one case / why did THIS fail?" ──▶ LOG or TRACE, not a metric
        │ yes — aggregate question
        ▼
4. DURABLE  — Is the behavior stable enough to deserve a long-lived named
              series, budget, and dashboard panel?
              one-off curiosity ──▶ query logs ad-hoc instead
        │ yes
        ▼
5. WORTH IT — Is the ongoing storage/cardinality cost justified by the value?
              (Re-check after deciding dimensions — they multiply cost.)
        │ yes
        ▼
   ✅ Create the metric — write a metric spec (below)
```

If a candidate fails any gate, it is **not** a custom metric. That is the common, correct outcome — most feature logic needs none.

## Classify: business vs operational

Every surviving metric is one or the other. Knowing which decides its **owner**, its **dashboard layer**, and its **alert routing**.

| | **Business metric** | **Operational metric** |
| --- | --- | --- |
| Measures | A domain outcome the business values, independent of how it's built | System health/behavior while delivering that outcome |
| Examples | payments captured, signups activated, orders placed, subscription upgrades, cart value, watch-time, messages delivered | queue depth, retry count, cache hit ratio, pool saturation, job lag, dead-letter count |
| Owner | Product / business | SRE / engineering |
| Dashboard | Executive layer | Engineering layer |
| Answers | "Are we delivering and earning value?" | "Is the machine healthy?" |

**Litmus:** *If the system were fine but this number moved, would a non-engineer care?* Yes → business. No → operational. Some features warrant one, a few warrant both, many warrant neither.

## What to measure

- Measure the **outcome at the business-meaningful boundary**, not the code path. `payment_captured` (confirmed by provider), **not** `PaymentService.capture() invoked`. The method might be called, retried, and fail — only the confirmed outcome is the business truth.
- Pick the **conceptual instrument** by question shape (still tech-agnostic):

| Question shape | Instrument | Example |
| --- | --- | --- |
| "How many / how often?" | **Counter** (rate) | `orders_placed`, `login_failures` |
| "How long / how big?" (read as percentiles) | **Distribution** | `checkout_duration`, `cart_value` |
| "How many right now / how full?" | **Gauge / level** | `active_sessions`, `queue_depth` |

- Name from the domain (ubiquitous language), not the implementation. Past-tense event names for counters (`orders_placed`, not `placeOrder`).

## Whether to add dimensions

A dimension (label/tag) is justified **only** when someone will segment by it to make a decision.

- **Name the comparison.** "Is checkout failing more on `provider=stripe` vs `adyen`?" "Is activation worse in `region=LATAM`?" If you can't state the comparison, don't add the dimension.
- **Bounded only.** Each dimension must be a finite, known set (status, region, plan tier, provider). Every unique combination is a separate series and a separate cost line.
- **Never** use unbounded values as dimensions: user/order IDs, emails, raw amounts, free text, full URLs, timestamps. That context belongs on **logs and traces**, where high cardinality is fine and you look at one case at a time.
- Add the **minimum** set that answers real comparison questions. Two well-chosen dimensions beat eight speculative ones.

## Worked examples

| Feature logic | Verdict | Why |
| --- | --- | --- |
| `OrderService.placeOrder()` completes | ✅ Business counter `orders_placed`, dims `{region, plan_tier, status}` | Someone tracks revenue/conversion; invisible to generic HTTP metrics; aggregate; durable. |
| A `for` loop iterating cart items | ❌ None | No one acts on iteration counts; not a business or health question. |
| "Why did order #8421 fail?" | ❌ Not a metric → **trace/log** | Per-case question; needs the order ID (high cardinality). |
| Retry wrapper around a flaky provider call | ✅ Operational counter `provider_retries`, dim `{provider}` | SRE acts on retry spikes; invisible to RED; health signal, not business. |
| Validation helper rejects malformed input | ❌ Usually none | Already visible as 4xx via auto-RED (coverage gate). Add a metric only if a specific rejection reason drives a product decision. |
| Time from signup to first activated action | ✅ Business distribution `time_to_activation`, dim `{acquisition_channel}` | Product optimizes activation; aggregate latency read as percentiles; durable. |
| Nightly export job | ✅ Operational gauge `export_lag` + counter `export_failures` | On-call acts on freshness/failure; health signals. |
| Cache hit ratio inside one function | ⚠️ Operational gauge **only if** it gates user-facing latency someone tunes | Otherwise an internal detail — fails the action/coverage gates. |

## The metric spec (handoff contract)

For each metric that passes, write a technology-agnostic spec. This is the artifact the implementation companion consumes — it states WHAT and WHY, never HOW:

```yaml
metric:
  name: payments_captured            # domain language, not code symbol
  kind: business                     # business | operational
  instrument: counter                # counter | distribution | gauge (conceptual)
  question: "How many payments succeed, and how does that trend by provider and plan?"
  unit: payments
  source_event: "payment capture confirmed by provider webhook"   # the business boundary
  dimensions:
    - name: provider                 # bounded: stripe | adyen | paypal
      reason: "compare success/latency across providers to route traffic"
    - name: plan_tier                # bounded: free | pro | enterprise
      reason: "detect if paid customers are disproportionately affected"
  owner: payments-team
  dashboard_layer: executive         # executive | engineering
  implementation: delegated          # filled in by the companion impl skill
```

A collection of these specs is the **Measurement Plan**, attached to the spec/proposal and refined during task breakdown (one instrumentation subtask per metric).

## Delegating the implementation (config-driven)

The main skill stops at the spec. The *how* — OpenTelemetry, Prometheus, Datadog, CloudWatch, naming conventions, exporters, SDK calls — is owned by a project-configured **companion skill**, looked up through the project config helper:

```bash
bash scripts/uncle-dev-config.sh --list skills.companions.uncle-dev-business-observability path
```

- **Companion path returned** → load that SKILL.md and hand it each metric spec to implement in the project's telemetry stack. The companion maps `kind`/`instrument`/`dimensions` onto its library (e.g. `counter` → OTel `Counter`, Prometheus `Counter`, CloudWatch `PutMetricData`; `dimensions` → OTel labels / CW dimensions, respecting that library's cardinality limits).
- **Empty (no companion configured)** → produce the Measurement Plan and **stop**. State that no telemetry-implementation companion is configured, and that one can be added with `/uncle-dev-custom-me companion uncle-dev-business-observability <name>` or by editing `skills.companions` in `.agents/uncle-dev-setup.yaml`. **Do not guess a telemetry library.**

`references/cloudwatch-implementation.md` in this skill is an *example* of the AWS-specific knowledge such a companion would own — it can be promoted into a companion skill for AWS projects.
