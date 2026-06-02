# Progressive Delivery

## Purpose

Progressive delivery reduces release risk by gradually exposing users to a new version and stopping the rollout when operational signals show failure.

This project uses Argo Rollouts with Prometheus analysis.

## Strategy

The rollout uses a canary strategy:

```text
10% traffic
pause
Prometheus analysis
50% traffic
pause
Prometheus analysis
100% traffic
promotion to stable
```

## Rollout Components

The deployment uses:

- Argo Rollout
- stable service
- canary service
- NGINX traffic routing
- Prometheus AnalysisTemplate
- ServiceMonitor
- application metrics

## Success Rate Query

The rollout analysis uses this Prometheus query:

```promql
(
  sum(rate(http_requests_total{status_code!~"5.."}[1m]))
  /
  clamp_min(sum(rate(http_requests_total[1m])), 1)
) or vector(1)
```

This query is intentionally defensive.

It prevents:

- empty result errors
- missing metric series failures
- division by zero
- rollout failure due to low traffic

## Successful Canary

The successful v2 rollout proved:

- image was built and scanned
- image was pushed to ECR
- Argo Rollouts shifted traffic gradually
- Prometheus analysis passed
- v2 became stable
- `/health` returned v2

## Failed Canary

The failed v3 rollout proved:

- a bad version can enter canary
- Prometheus can detect poor success rate
- Argo Rollouts can abort the rollout
- the failed ReplicaSet is scaled down
- stable traffic remains on the healthy version

## Key Lesson

The first analysis query failed because Prometheus returned no usable result and Argo attempted to read `result[0]`.

The fix was to use:

```text
len(result) > 0
clamp_min(...)
or vector(1)
```

This is a realistic production lesson. Rollout metrics must be safe against missing data, low traffic, and label mismatch.
