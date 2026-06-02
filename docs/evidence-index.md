# Evidence Index

Evidence is stored in:

```text
docs/evidence/
```

## Infrastructure Evidence

- `terraform-dev-plan.txt`
- `terraform-dev-outputs.txt`
- `checkov-dev-results.txt`
- `eks-nodes.txt`
- `eks-system-pods.txt`

## Platform Evidence

- `platform-addons-pods.txt`
- `platform-addons-services.txt`

## Application Evidence

- `orders-api-pods.txt`
- `orders-api-service.txt`
- `orders-api-ingress.txt`
- `orders-api-health.json`
- `orders-api-orders.json`
- `orders-api-metrics.txt`

## Argo Rollouts Evidence

- `argo-rollout-status.txt`
- `argo-rollout-describe.txt`
- `argo-rollout-pods.txt`
- `argo-rollout-services.txt`
- `argo-rollout-ingress.txt`
- `argo-rollout-health.json`
- `argo-rollout-orders.json`
- `argo-rollout-metrics.txt`

## Successful Canary Evidence

- `canary-v2-rollout-status.txt`
- `canary-v2-rollout-describe.txt`
- `canary-v2-analysisruns.txt`
- `canary-v2-pods.txt`
- `canary-v2-replicasets.txt`
- `canary-v2-history.txt`
- `canary-v2-health.json`
- `canary-v2-orders.json`

## Failed Canary Evidence

- `failed-canary-v3-rollout-status.txt`
- `failed-canary-v3-rollout-describe.txt`
- `failed-canary-v3-analysisruns.txt`
- `failed-canary-v3-pods.txt`
- `failed-canary-v3-replicasets.txt`
- `failed-canary-v3-history.txt`
- `failed-canary-v3-health-after-abort.json`
- `failed-canary-v3-orders-after-abort.json`
- `prometheus-v3-5xx-rate.json`
- `prometheus-v3-success-rate.json`

## Grafana Evidence

- `grafana-monitoring-pods.txt`
- `grafana-monitoring-services.txt`
- `grafana-query-request-rate.json`
- `grafana-query-5xx-rate.json`
- `grafana-query-success-rate.json`
- `grafana-query-request-rate-by-version.json`
- `grafana-query-request-rate-by-status-code.json`
- `grafana-query-business-failure-rate.json`

## GitHub Actions Deployment Evidence

- `github-actions-v4-rollout-status.txt`
- `github-actions-v4-rollout-describe.txt`
- `github-actions-v4-pods.txt`
- `github-actions-v4-analysisruns.txt`
- `github-actions-v4-health.json`
- `github-actions-v4-orders.json`

## Note

Some evidence files may reflect earlier infrastructure runs because the environment was destroyed and recreated to control AWS cost. Git history preserves the implementation sequence.
