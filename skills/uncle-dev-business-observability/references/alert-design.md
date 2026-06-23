# Alert Design Patterns

Load this from **Step 6 (alerting)** when you need the alert patterns, routing/escalation config, runbook template, or the metrics to prove an alert set isn't just noise. Goal: alerts that are invisible when things work and invaluable at 3 AM.

## The four golden rules

1. **Actionable** — if you can't do something about it, don't alert.
2. **Requires human intelligence** — if a script can fix it, automate the fix instead of paging.
3. **Novel** — don't re-alert on a known, ongoing issue.
4. **User-visible impact** — internal metrics matter only when users are affected.

## Two severities, not five

Collapse to **page** (user-facing, act now) and **ticket** (degradation, act this week). A third tier becomes noise people learn to ignore. Map burn-rate fast→page, slow→ticket (see `slo-cookbook.md`).

## Core patterns

### 1. Symptoms, not causes

```yaml
# GOOD — user-visible symptom
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
  for: 5m
# BAD — internal cause that may not affect anyone
- alert: HighCPU
  expr: cpu_usage > 80   # users may feel nothing
```

Cause-based alerts fire when nothing is wrong and miss failures you didn't predict. Symptom-based alerts fire exactly when users hurt.

### 2. Multi-window (avoid flapping)

```yaml
- alert: ServiceDown
  expr: avg_over_time(up[2m]) == 0 and avg_over_time(up[10m]) < 0.8
  for: 1m
```

Short window = fast detection; long window = confirmation. Burn-rate alerts are the SLO-aware version of this (`slo-cookbook.md`).

### 3. Hysteresis (different fire/resolve thresholds)

Fire at error_rate > 5%, resolve only when < 3%. Prevents flapping around a single threshold.

### 4. Composite (only alert with traffic)

```yaml
- alert: ServiceDegraded
  expr: (latency_p95 > T or error_rate > E or availability < A) and (request_rate > min_rate)
```

The `request_rate > min_rate` guard stops 3 AM pages when a single overnight request skews a ratio.

### 5. Contextual (carry the business impact)

```yaml
annotations:
  summary: "Checkout payment latency high"
  description: "P95 {{ $value }}s on the Checkout journey"
  impact: "Cart abandonment rising; ~$X/min revenue at risk"
  runbook_url: "https://runbooks.company.com/alerts/{{ $labels.alertname }}"
  suggested_action: "Check PaymentService provider latency; consider failover"
```

Every alert names the **journey and business impact**, not just a host or metric.

## Routing and escalation

```yaml
route:
  group_by: ['service']
  group_wait: 30s        # gather related alerts before firing
  group_interval: 2m
  repeat_interval: 1h
  routes:
    - match: { service: payment-api, severity: critical }
      receiver: payment-team-pager
    - match: { service: payment-api, severity: warning }
      receiver: payment-team-slack
    # time-based: warnings go to Slack in hours, email after hours
```

Escalation: primary on-call → secondary (5m) → manager (15m) → director (30m). Critical escalates immediately; warning escalates within the team first.

## Fatigue prevention

- **Grouping** — `group_wait`/`group_interval` batch related alerts into one notification.
- **Inhibition (dependent suppression)** — when `ServiceDown` fires, suppress its downstream `HighLatency`:

```yaml
inhibit_rules:
  - source_match: { alertname: ServiceDown }
    target_match: { alertname: HighLatency }
    equal: ['service']
```

- **Throttling** — a longer `for:` duration on inherently noisy conditions cuts repeat pages.

## Runbook template (link from every alert)

```markdown
# Alert: {{ alertname }}
## Immediate actions
1. Check the journey dashboard — are users affected?
2. Look at recent deploys/changes.
## Investigation
1. Errors in the last 30 min (filter by requestId/journey).
2. Dependent services healthy?
3. Resource saturation?
## Resolution
- Deploy-related → roll back.  Resource → scale/optimize.  Dependency → engage that team.
## Escalation
Primary @team-oncall · Secondary @eng-manager · Emergency @sre
```

## Prove the alert set is healthy

```
Precision = True Positives / (True Positives + False Positives)
```

Track: alerts that led to a real incident vs false alarms; time-to-resolution per alertname; alerts/day per team; % acknowledged within 15 min. Test that alerts actually fire under controlled failure (chaos/lowered threshold) and resolve when conditions clear.

## Anti-patterns

| Anti-pattern | Fix |
| --- | --- |
| Alerting on everything | Only user-impacting symptoms. |
| Vague messages ("Service X down") | Include instance, impact, suggested action. |
| Alerts without runbooks | Every alert links a runbook. |
| Static thresholds | Use SLO burn-rate or contextual/adaptive thresholds. |
| Tolerating high false-positive rates | Review precision quarterly; delete or tune noisy alerts. |
