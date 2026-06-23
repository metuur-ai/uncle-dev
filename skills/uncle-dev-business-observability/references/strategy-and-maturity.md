# Business Observability — Strategy, Criticality & Maturity

Load this when you need to justify the investment, size instrumentation cost by criticality, place the org on the maturity model, or frame the strategic "why." The actionable procedure lives in `../SKILL.md`.

## 1. The paradigm: monitoring vs. observability

System uptime is a vanity metric if it doesn't correlate with customer happiness and revenue. The "iceberg": monitoring watches the visible surface (infrastructure, components); observability surfaces the submerged insight (journeys, outcomes).

| Feature | Monitoring (Technical) | Observability (Business) |
| ------ | ------ | ------ |
| **Primary Focus** | Isolated components, system-centric metrics | End-to-end customer journeys and outcomes |
| **Operational Stance** | Reactive; alerts after disruption | Proactive/predictive; identifies risk before impact |
| **Data Depth** | Surface logs, predefined rules | Deep telemetry (traces, metrics, logs) with context |
| **Visibility Scope** | Fragmented silos | Unified view across hybrid/multi-cloud |
| **Strategic Goal** | Firefighting (status quo) | Fireproofing (outcome-driven) |

**The Value Gap.** Engineering telemetry and business outcomes are rarely synchronized. During incidents this creates *decision latency*: engineers chase an RPC latency spike while leaders watch conversion drop without knowing the cause. Closing it means making **user experience the primary unit of measure**.

## 2. Modeling the product: Critical User Journeys

The legacy *service-centric* model (SRE owns fixed infra) breaks when service growth outpaces engineering capacity → alert fatigue. The *product-centric* model anchors reliability to **Critical User Journeys (CUJs)**.

Journey-mapping progression (use Jobs to be Done to capture intent):

1. **Hypothetical "As-Is"** — sketch current flows, surface assumptions, scope research.
2. **Research-Based maps** — real data → actual experiences, interdependencies, pain points.
3. **"To-Be" journeys** — design the ideal future state, align roadmaps.

## 3. The Golden Signals → financial outcomes

Cost is the modern 5th signal.

- **Latency** → cart abandonment; every 100ms of delay erodes conversion.
- **Errors** → failed transactions and churn.
- **Traffic** → market demand; failures = lost opportunity.
- **Saturation** → predictive of exhaustion and revenue loss.
- **Cost** → financial efficiency; enables ROI-driven scaling.

**Request annotation** turns telemetry into *Business Event Analytics*: tagging requests with `journey.name`/`journey.step` reveals which 2% of errors cause 100% of failures in a critical workflow.

## 4. Instrumentation tradeoffs

| Type | Cost | Confidence | Latency | Business Coverage |
| ------ | ------ | ------ | ------ | ------ |
| **Service SLOs** | Low | High | Seconds | Narrow (server-side) |
| **Client-Side** | Moderate | Low (ISP/device noise) | 15–60m | Broad (direct UX) |
| **End-to-End** | Very High | High (cross-referenced) | Hours | Deep (specific business metric) |

## 5. Criticality framework (sizing the investment)

Severity by degradation of core vs. auxiliary functionality:

- **Major** — any impact to core features (transport/delivery) or >20% overall degradation.
- **Medium** — >5% impact to core features, or >20% to auxiliary (e.g. auto-complete).
- **Minor** — auxiliary/unlaunched features that don't impede primary goals.

Criticality → observability investment:

| Criticality | Business Workflows | Recommended Investment |
| ------ | ------ | ------ |
| **Critical** | Revenue paths; core transport/delivery | High-cost E2E SLOs + client-side annotation |
| **Important** | Graceful failover; spam filters | Moderate-cost server-based SLOs |
| **None** | Internal tools; unlaunched features | Baseline platform monitoring only |

## 6. Maturity model

- **Level 0 — Monitoring:** siloed data, manual reactive firefighting.
- **Level 1 — Observability:** integrated metrics, logs, traces; basic anomaly detection.
- **Level 2 — Full-Stack:** coverage across cloud, container, and application layers.
- **Level 3 — Intelligent:** automated root-cause and predictive causation analysis.
- **Level 4 — Federated:** decentralized, AI-driven, real-time business-IT alignment.

## 7. Value realization (illustrative targets, not guarantees)

| Metric | Pre (Reactive) | Post (Proactive) |
| ------ | ------ | ------ |
| **MTTR** | Slow, manual | ~50% reduction via causation analysis |
| **Cloud Costs** | Over-provisioned | ~20% reduction via optimization |
| **Downtime Cost** | High exposure | Large reduction via prediction |
| **Revenue Impact** | High loss in outages | Increase via stability/uptime |
| **Customer Experience** | Inconsistent | Improvement in CSAT/user scores |

> These figures are illustrative industry claims, not promises. Measure your own baseline before and after.

## 8. Cultural transformation

Business observability requires SRE, DevOps, Product, and UX to share **one nomenclature grounded in user objectives**. When they do, IT stops being a cost center and becomes the engine of strategic advantage. Technical performance is valuable only as a direct proxy for customer and business success: stop monitoring systems; start observing business value.
