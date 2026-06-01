# Grafana Dashboard Evidence

## Purpose

This dashboard proves that the Orders API is observable during progressive delivery on Amazon EKS.

It tracks request rate, server error rate, success rate, traffic by application version, traffic by HTTP status code, and business-level failure rate.

## Panels

### Orders API - HTTP Request Rate

```promql
sum(rate(http_requests_total[1m]))

sum(rate(http_requests_total{status_code=~"5.."}[1m])) or vector(0)

(
  sum(rate(http_requests_total{status_code!~"5.."}[1m]))
  /
  clamp_min(sum(rate(http_requests_total[1m])), 1)
) or vector(1)

sum by (version) (rate(http_requests_total[1m]))

sum by (status_code) (rate(http_requests_total[1m]))

sum(rate(business_order_failures_total[1m])) or vector(0)
