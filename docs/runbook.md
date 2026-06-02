# Operational Runbook

## Update kubeconfig

```bash
aws eks update-kubeconfig --region us-east-1 --name epd-eks-dev
```

## Check Cluster Health

```bash
kubectl get nodes
kubectl get pods -A
```

## Check Orders API Rollout

```bash
kubectl argo rollouts get rollout orders-api -n app-dev
kubectl get pods -n app-dev -o wide
kubectl get analysisrun -n app-dev -o wide
```

## Get Ingress Hostname

```bash
export INGRESS_HOST="$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

echo "$INGRESS_HOST"
```

## Test Live API

```bash
curl -s http://$INGRESS_HOST/health
curl -s http://$INGRESS_HOST/ready
curl -s http://$INGRESS_HOST/api/orders
curl -s http://$INGRESS_HOST/metrics | head
```

## Watch Rollout

```bash
kubectl argo rollouts get rollout orders-api -n app-dev --watch
```

## Abort Rollout

```bash
kubectl argo rollouts abort orders-api -n app-dev
```

## Undo Rollout

```bash
kubectl argo rollouts undo orders-api -n app-dev
```

## Delete AnalysisRuns

```bash
kubectl delete analysisrun -n app-dev --all
```

## Check Prometheus

Port-forward Prometheus:

```bash
kubectl port-forward service/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Request rate:

```bash
curl -sG 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(http_requests_total[1m]))'
```

Success rate:

```bash
curl -sG 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=(sum(rate(http_requests_total{status_code!~"5.."}[1m])) / clamp_min(sum(rate(http_requests_total[1m])), 1)) or vector(1)'
```

## Access Private Runner

```bash
RUNNER_INSTANCE_ID="$(terraform -chdir=terraform/environments/dev output -raw github_runner_instance_id)"

aws ssm start-session \
  --target "$RUNNER_INSTANCE_ID" \
  --region us-east-1
```

Inside SSM:

```bash
sudo su - ubuntu
```

## Check Runner Service

```bash
cd ~/actions-runner
sudo ./svc.sh status
```

## Restart Runner Service

```bash
cd ~/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh start
sudo ./svc.sh status
```
