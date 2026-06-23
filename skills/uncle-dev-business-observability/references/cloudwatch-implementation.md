# Implementing on AWS CloudWatch

Load this **only when the target stack is AWS CloudWatch** (Steps 2–6). It maps this skill's vendor-neutral concepts (journey spans, business attributes, client-side UX, SLO alarms) onto CloudWatch's data model and its hard limits — the facts that bite you if you assume Prometheus semantics.

## Two metric models live side by side

CloudWatch supports both traditional metrics and OpenTelemetry (OTLP) metrics, and they are **not** the same model:

| Concept | Traditional CloudWatch | OpenTelemetry metrics |
| --- | --- | --- |
| Identity | Namespace + name + **up to 30 dimensions** | Name + **up to 150 labels** |
| Types | Single values, statistic sets | Gauge, sum, histogram, exponential histogram |
| Ingestion | `PutMetricData` API / CLI / EMF | OTLP |
| Query | `GetMetricStatistics`, Metrics Insights | **PromQL** (Query Studio) |
| Alarms | Standard CloudWatch Alarms | **PromQL-based** alarms |

**Implication for this skill:** if you instrument journeys with OpenTelemetry (Step 2), prefer the OTLP path — 150 labels and histograms fit journey/business attributes far better than 30 dimensions and statistic sets. PromQL alarms then carry the burn-rate expressions from `slo-cookbook.md` almost verbatim.

## Dimensions are the cardinality trap

- A *dimension* is a name/value pair that is **part of the metric's identity**. Every unique combination is a **separate metric** and a separate billing line.
- CloudWatch does **not** aggregate across dimensions for custom metrics — you can only retrieve the exact combinations you published. Publishing `Server=Prod,Domain=Frankfurt` does **not** let you later query `Server=Prod` alone.
- This is exactly why the SKILL.md gotcha holds: putting `customer_id` or raw `cart_total` in a dimension multiplies metrics without bound. Keep dimensions to small fixed sets (journey name, journey step, status class, region). Raw IDs and amounts belong in logs/traces.

## Resolution, retention, and what it costs

- **Standard resolution** = 1-minute granularity (AWS defaults). **High resolution** = 1-second granularity for custom metrics.
- Every `PutMetricData` call is billed — high-resolution metrics called frequently cost more. High-resolution **alarms** (10 s / 30 s periods) also cost more than standard 60 s-multiple alarms.
- Retention auto-rolls up: <60 s data → 3 h; 1 min → 15 days; 5 min → 63 days; 1 h → 455 days (15 months). Plan SLO windows around this — a 28-day SLO read at 1-minute resolution is fine; reading 1-second data after 3 hours is not possible.
- **Statistic sets** (Min/Max/Sum/SampleCount) pre-aggregate high-frequency data cheaply — but **percentiles need raw data points**, so a statistic set generally can't yield P95/P99. For latency SLIs publish raw points or use histograms.

## Percentiles (for latency SLIs)

CloudWatch supports percentile statistics (e.g. `p95`, up to `p99.9999999999`) on metrics with raw data points. Use percentiles, not averages — an average hides the slow tail that drives cart abandonment. Percentiles are unavailable if any metric value is negative.

## Alarms map to burn-rate and severity

- Alarms act on **sustained** state changes only (the state must hold for N evaluation periods) — this is CloudWatch's native multi-window/`for:` equivalent. Use "M datapoints out of N" to require, e.g., 2 of 3 periods breaching before paging.
- Alarm period must be ≥ the metric's resolution (basic EC2 = 5 min → period ≥ 300 s).
- For OTLP metrics, write **PromQL-based alarms** and paste the fast/slow burn-rate expressions from `slo-cookbook.md`.
- Actions route to SNS (→ PagerDuty/Slack/email) — the routing/escalation split from `alert-design.md`.

## Client-side journey instrumentation: CloudWatch RUM

Step 4 calls for **client-side instrumentation on Critical journeys** (the broad, real-UX signal). On AWS that's CloudWatch RUM:

- RUM app monitors emit default metrics + dimensions automatically. You can additionally define **custom** and **extended** metrics.
- **Custom metrics** — your own name/namespace derived from any custom/built-in event or attribute. Created via API/CLI only (`PutRumMetricsDestination`, `BatchCreateRumMetricDefinitions`), not the console. Example: count visits to a URL from Chrome by pattern-matching a `recordEvent` payload into a metric in namespace `RUM/CustomMetrics/...`.
- **Extended metrics** — send default RUM metrics to CloudWatch with **extra dimensions** for a finer view. Web dims: `BrowserName`, `CountryCode` (ISO-3166), `DeviceType`, `FileType`, `OSName`, `PageId`. Mobile dims: `ScreenName`, `DeviceModel`, `OSVersion` (defaults include `ScreenLoadTime`, `CrashCount`, `ColdLaunchTime`, etc.).
- **Limit:** max 2000 extended+custom metric definitions per destination; **each dimension-name/value combination counts toward the limit** — the same cardinality discipline applies. You are not charged for RUM-derived custom/extended metrics, but the 2000-definition cap is hard.
- You can alarm directly on extended metrics from the RUM console (e.g. `JSErrorCount` filtered to `BrowserName=Chrome`, Average statistic, 5-min period, "2 of 2" datapoints to avoid single-spike flapping).

## Mapping cheat-sheet

| This skill's concept | CloudWatch realization |
| --- | --- |
| Journey span + business attributes | OTLP metric labels (≤150) / EMF structured logs; never as dimensions if high-cardinality |
| Server-side SLI | Traditional metric + percentile statistic, or OTLP histogram |
| Client-side UX SLI (Critical journeys) | RUM custom/extended metric |
| Error-budget burn-rate alert | PromQL-based alarm (OTLP) or multi-datapoint standard alarm |
| Severity routing | Alarm → SNS topic → pager/Slack/email |
