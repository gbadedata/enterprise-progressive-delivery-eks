#!/usr/bin/env bash
set -euo pipefail

echo "Verifying Kubernetes access..."
kubectl get nodes

echo
echo "Adding Helm repositories..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo
echo "Installing NGINX Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.service.type=LoadBalancer

echo
echo "Installing Argo Rollouts..."
helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --set dashboard.enabled=true

echo
echo "Installing Prometheus and Grafana..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword='ChangeMe123!' \
  --set prometheus.prometheusSpec.scrapeInterval=15s \
  --set prometheus.prometheusSpec.evaluationInterval=15s

echo
echo "Waiting for platform pods..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s
kubectl rollout status deployment/argo-rollouts -n argo-rollouts --timeout=300s
kubectl rollout status deployment/monitoring-grafana -n monitoring --timeout=300s

echo
echo "Platform add-ons installed."

mkdir -p docs/evidence
kubectl get pods -A -o wide > docs/evidence/platform-addons-pods.txt
kubectl get svc -A -o wide > docs/evidence/platform-addons-services.txt

echo
echo "Evidence saved:"
echo "docs/evidence/platform-addons-pods.txt"
echo "docs/evidence/platform-addons-services.txt"
