# SLO Cookbook — Formulas, Budgets, and Burn-Rate Alerts

Load this from **Step 3 (define SLIs/SLOs)** or **Step 6 (alerting)** when you need the actual PromQL, the error-budget math, the burn-rate thresholds, or the policy that decides what happens when the budget drains. SKILL.md gives the procedure; this gives the numbers.

## The hierarchy

- **SLI** — a quantifiable measure of service quality: `good events / valid events`.
- **SLO** — a target range for an SLI over a window (e.g. 99.9% over 28 days).
- **SLA** — a business agreement with consequences for missing the SLO. SLA target is always looser than the internal SLO.

**Golden rule:** start simple, iterate. First SLOs won't be perfect — 1–2 SLIs per journey, refine quarterly.

## Choosing good SLIs

A good SLI is **measurable, meaningful** (reflects user experience), **controllable** (you can act on it), and **proportional** (moves with user happiness).

**Anti-patterns — do NOT use as primary SLIs:**
- CPU / memory / disk — symptoms, not user impact.
- Counts instead of rates/proportions ("number of errors" vs "error rate").
- Internal metrics users don't feel (queue depth, cache hit rate) unless they directly gate UX.

### SLI formulas by service type (PromQL)

```prometheus
# HTTP API — availability (non-5xx proportion)
sum(rate(http_requests_total{code!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# HTTP API — latency SLI (P95)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Journey step — success rate (instrument explicit good/total counters)
sum(rate(checkout_payment_success_total[5m])) / sum(rate(checkout_payment_attempts_total[5m]))
```

| Service type | SLIs |
| --- | --- |
| HTTP API | request latency (P95/P99), availability (non-5xx), throughput |
| Batch job | freshness (age of last success), correctness (success proportion), throughput |
| Data pipeline | data freshness, data quality (records passing validation), processing latency |

```prometheus
# Batch freshness — data no older than 4h
(time() - last_successful_update_timestamp) < (4 * 3600)

# Pipeline quality — ≥99.5% records valid
sum(rate(records_valid_total[5m])) / sum(rate(records_processed_total[5m])) >= 0.995
```

## SLO targets by criticality

| Criticality (revenue impact) | Availability | Latency P95 | Error rate |
| --- | --- | --- | --- |
| **Critical** (revenue path) | 99.95% – 99.99% | 100–200ms | < 0.1% |
| **High** | 99.9% – 99.95% | 200–500ms | < 0.5% |
| **Standard** | 99.5% – 99.9% | 500ms – 1s | < 1% |

Three target-setting methods: **historical** (4–6 weeks of data → set just better than worst acceptable), **user-journey mapping** (acceptable per-step performance → work backward to component SLOs), **error-budget** (decide affordable unreliability → derive target).

> Higher SLOs cost exponentially more. Pick the *minimum acceptable* level, not the highest achievable. 99.99% when 99.9% would satisfy users is wasted money.

## Error-budget math

```
Error Budget = (1 − SLO) × Time Window
```

99.9% availability over 30 days → `(1 − 0.999) × 30d = 0.001 × 30d ≈ 43.8 minutes` of allowed downtime.

| SLO | Allowed downtime / 30 days |
| --- | --- |
| 99.0% | ~7.2 hours |
| 99.9% | ~43.8 minutes |
| 99.95% | ~21.9 minutes |
| 99.99% | ~4.4 minutes |

The budget is the decision tool: budget healthy → ship features; budget draining → stabilize.

### Error-budget policies (decide BEFORE you need them)

| Policy | Trigger → action |
| --- | --- |
| **Conservative** (high-risk) | >50% consumed → freeze non-critical releases · >75% → reliability only · >90% → emergency measures (traffic shaping) |
| **Balanced** (standard) | >75% → increase reliability work · >90% → pause feature work |
| **Aggressive** (early-stage) | >90% → review but continue · 100% → re-evaluate whether the SLO is right |

## Multi-window burn-rate alerts

Burn rate = how fast you're spending the budget relative to "exactly on target." Burn rate 1 = budget exhausted exactly at window end. Higher = faster. The `14.4` multiplier = consuming 2% of a 30-day budget in 1 hour.

```yaml
# FAST burn — 2% of budget in 1h → page (severity: critical)
- alert: ErrorBudgetFastBurn
  expr: |
    (1 - (sum(rate(http_requests_total{code!~"5.."}[5m])) / sum(rate(http_requests_total[5m])))) > (14.4 * 0.001)
    and
    (1 - (sum(rate(http_requests_total{code!~"5.."}[1h])) / sum(rate(http_requests_total[1h])))) > (14.4 * 0.001)
  for: 2m
  labels: { severity: critical }

# SLOW burn — 10% of budget in 3 days → ticket (severity: warning)
- alert: ErrorBudgetSlowBurn
  expr: |
    (1 - (sum(rate(http_requests_total{code!~"5.."}[6h])) / sum(rate(http_requests_total[6h])))) > (1.0 * 0.001)
    and
    (1 - (sum(rate(http_requests_total{code!~"5.."}[3d])) / sum(rate(http_requests_total[3d])))) > (1.0 * 0.001)
  for: 15m
  labels: { severity: warning }
```

The short-window condition gives fast detection; the long-window condition prevents flapping on brief blips. Both must be true to fire. Replace `0.001` with your own `(1 − SLO)`.

## Dependency SLOs

A service can be no more reliable than the product of its hard dependencies:

```
SLO_service ≤ min(SLO_inherent, ∏ SLO_dependencies)
```

Three hard dependencies at 99.9% each → max achievable `0.999³ ≈ 99.7%`. If you promise 99.95% on top of that, you're promising something physically impossible without redundancy or graceful degradation.

## SLO implementation ladder

- **Level 1 — Basic:** 1–2 SLIs that matter; aspirational-but-achievable targets; alert on miss.
- **Level 2 — Operational:** add burn-rate alerting, error-budget dashboard, written error-budget policy, monthly review.
- **Level 3 — Advanced:** multi-window burn-rate alerts, automated policy enforcement, SLO-driven incident priority, CI/CD release gating on budget.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| Too many SLOs | Start 1–2 per journey; add only when a gap is felt. |
| Internal metrics as SLIs | Ask "if this changes, do users notice?" If no, it's not an SLI. |
| Perfectionist SLOs | 99.9% beats 99.99% when users can't tell the difference; the extra nine costs exponentially. |
| Ignoring the budget | The budget exists to be spent. Not every miss is an emergency. |
| Static SLOs | Review quarterly against real user feedback and business change. |

## Review cadence

- **Monthly:** Did we meet SLOs? How was the budget spent? Which incidents hit it? Are the SLIs still meaningful? Adjust targets?
- **Quarterly:** Validate user impact (do users actually accept this performance?), business alignment, measurement quality, cost/benefit of tighter SLOs.

## Getting-started checklist

- [ ] Identify the critical user journeys (Step 1 of SKILL.md).
- [ ] Choose 1–2 SLIs per journey that reflect user experience.
- [ ] Collect 4–6 weeks of baseline data.
- [ ] Set initial targets from historical performance.
- [ ] Implement SLO monitoring + an error-budget dashboard.
- [ ] Add multi-window burn-rate alerts.
- [ ] Write the error-budget policy.
- [ ] Schedule monthly reviews + quarterly health checks.
