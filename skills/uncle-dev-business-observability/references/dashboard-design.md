# Dashboard Design — Two Layers, Business on Top

Load this from **Step 5 (dashboards)** when you need the layout, the role-based archetypes, panel/chart selection, or time-range defaults. The core rule of this skill: the **executive layer speaks business, drills into the engineering layer in one click**.

## The two-layer model (this skill's spine)

| Layer | Audience | Shows | Question it answers |
| --- | --- | --- | --- |
| **Executive / business** | PM, leadership | One tile per CUJ: SLO status, error-budget remaining, conversion / revenue-at-risk / CSAT | "Is the business healthy?" |
| **Engineering** | SRE, dev | Golden Signals, traces, saturation, slow endpoints | "Where and why is it broken?" |

Each executive tile **links** to the engineering panels for that journey (Grafana `data_links`). One click goes from "conversion dropping" to "PaymentService P99 spiked." That link is what kills decision latency.

## Information hierarchy (every dashboard)

- **Top third (primary):** service health, SLO achievement, critical alerts, business KPIs.
- **Middle third (secondary):** golden signals (latency, traffic, errors, saturation), resource use.
- **Bottom third (tertiary):** detailed breakdowns, historical trends, dependency status, debug info.

**Rule of 7±2 panels per screen.** A 50-panel dashboard helps no one — push detail to drill-downs.

## Role-based archetypes

**Overview (exec)** — business health + system health, 5–15 min refresh:
`availability summary · revenue/hour · active users · conversion · critical-alert count · SLO summary · error-budget remaining · deploy status`

**SRE operational** — real-time incident response, 15–30 s refresh:
`service up/down · active incidents · recent deploys · latency percentiles · request rate · error rate · saturation · CPU/mem/net/disk`

**Developer debug** — deep troubleshooting, 30 s–2 min refresh:
`endpoint latency breakdown · DB query perf · cache hit rate · queue depth · error rate by endpoint · log volume by level · exception types · slow queries`

## Layout patterns

- **F-pattern** (operational) — most-critical top-left; eye scans left-to-right then down.
- **Z-pattern** (executive) — business KPIs top-left → system status top-right → trends bottom-left → key metrics bottom-right.

## Panel & chart selection

| Need | Chart |
| --- | --- |
| Trends over time | Line / time series |
| Categorical / top-N | Bar |
| Single value vs good/bad range | Gauge |
| Key metric / count / % | Stat |
| Distribution | Heatmap |
| Multi-dimensional detail | Table |

Color semantics: green = healthy, yellow/orange = degraded/warning, red = critical, blue = informational, gray = unknown/baseline. Set thresholds at meaningful boundaries (e.g. SLO target line), not round numbers. Test in a color-blind-safe palette.

```yaml
# Latency time-series — always percentiles, never average
- title: "Checkout payment latency"
  type: timeseries
  targets:
    - { expr: 'histogram_quantile(0.50, rate(http_duration_bucket[5m]))', legend: P50 }
    - { expr: 'histogram_quantile(0.95, rate(http_duration_bucket[5m]))', legend: P95 }
    - { expr: 'histogram_quantile(0.99, rate(http_duration_bucket[5m]))', legend: P99 }
```

## Time-range defaults

| Dashboard | Default | Auto-refresh |
| --- | --- | --- |
| Real-time operational | 15 min | 15–30 s |
| Troubleshooting | 1 h | 1 min |
| Business review | 24 h | 5 min |
| Capacity planning | 7 d | 15 min |

Annotate deploys and incidents on the timeline so spikes line up with their cause.

## Performance

Use **recording rules** for expensive queries instead of computing in-panel. Cap ~20–30 panels per dashboard, ≤10 queries/panel, ≤50 series/panel. Dashboard should load < 5 s.

## Anti-patterns

| Anti-pattern | Fix |
| --- | --- |
| Vanity metrics (total signups ever, total page views) | Show rates/ratios that indicate health. |
| Too many metrics / scrolling required | Cut to what supports a decision. |
| Raw numbers with no comparison | Always show vs previous period / target / SLO. |
| One dashboard for all audiences | Separate exec / SRE / dev views. |
| Output metrics (PRs merged, tickets closed) | Measure user & business outcomes. |
| Stale dashboards | Weekly broken-panel check; quarterly review. |
