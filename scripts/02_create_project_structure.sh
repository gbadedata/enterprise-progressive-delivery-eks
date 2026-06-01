#!/usr/bin/env bash
set -euo pipefail

echo "Creating enterprise project structure..."

mkdir -p app/src
mkdir -p app/tests

mkdir -p terraform/environments/dev
mkdir -p terraform/environments/staging
mkdir -p terraform/environments/prod
mkdir -p terraform/modules/vpc
mkdir -p terraform/modules/eks
mkdir -p terraform/modules/ecr
mkdir -p terraform/modules/github-oidc
mkdir -p terraform/modules/irsa
mkdir -p terraform/modules/monitoring
mkdir -p terraform/modules/ingress

mkdir -p k8s/base
mkdir -p k8s/overlays/dev
mkdir -p k8s/overlays/staging
mkdir -p k8s/overlays/prod

mkdir -p argocd/applications
mkdir -p argocd/projects

mkdir -p monitoring/prometheus-rules
mkdir -p monitoring/grafana-dashboards
mkdir -p monitoring/alertmanager

mkdir -p security/policies
mkdir -p security/trivy
mkdir -p security/checkov

mkdir -p docs/screenshots
mkdir -p docs/evidence

mkdir -p .github/workflows

touch README.md
touch docs/architecture.md
touch docs/threat-model.md
touch docs/runbook.md
touch docs/rollback-test.md
touch docs/cost-analysis.md

echo "Project structure created."
tree -a -I '.git|node_modules'
