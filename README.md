# Enterprise Progressive Delivery Platform on AWS EKS

## Executive Summary

This project is a production-style progressive delivery platform built on AWS EKS. It demonstrates how a containerised API can move from local development to a secure, observable, automated Kubernetes delivery pipeline with controlled canary releases and automatic protection against failed deployments.

The platform combines infrastructure-as-code, container security scanning, Kubernetes deployment validation, GitHub Actions CI/CD, Argo Rollouts, Prometheus analysis, Grafana observability, and a private AWS self-hosted GitHub Actions runner.

The main engineering goal is not simply to “deploy an app to Kubernetes.” The goal is to prove that releases can be built, scanned, deployed, observed, promoted, or blocked using measurable operational signals.

---

## Project Outcomes

This project proves the following capabilities:

- A Node.js Orders API can be containerised, scanned, and deployed to Amazon EKS.
- AWS infrastructure can be provisioned repeatably using Terraform.
- Infrastructure can be hardened using Checkov findings.
- Docker images can be scanned with Trivy before deployment.
- Kubernetes manifests can be validated before use.
- Argo Rollouts can progressively shift traffic during a canary release.
- Prometheus metrics can determine whether a release should continue.
- A successful release can be promoted automatically.
- A failed release can be stopped before becoming stable.
- Grafana can visualise request rate, success rate, error rate, and version traffic.
- GitHub Actions can deploy to EKS through a private AWS self-hosted runner without exposing the EKS API publicly.

---

## Architecture Overview

The platform is composed of six major layers:

1. **Application Layer**
   - Node.js Orders API
   - Health, readiness, liveness, order, and metrics endpoints

2. **Container Layer**
   - Docker image
   - Minimal runtime image
   - Trivy vulnerability scanning
   - Immutable ECR image tags

3. **Infrastructure Layer**
   - Terraform
   - Amazon VPC
   - Public and private subnets
   - NAT Gateway
   - Amazon EKS
   - Managed node group
   - Amazon ECR
   - IAM roles and policies
   - KMS encryption
   - CloudWatch logging

4. **Kubernetes Platform Layer**
   - NGINX Ingress Controller
   - Argo Rollouts
   - Prometheus
   - Grafana
   - NetworkPolicy
   - ServiceMonitor

5. **Progressive Delivery Layer**
   - Argo Rollout
   - Stable service
   - Canary service
   - NGINX traffic routing
   - Prometheus AnalysisTemplate
   - Automated promotion or abort

6. **CI/CD Layer**
   - GitHub Actions CI workflow
   - GitHub Actions deployment workflow
   - Private EC2 self-hosted runner
   - ECR push
   - Argo Rollouts image update

---

## High-Level Deployment Flow

```text
Developer push
    ↓
GitHub Actions CI
    ↓
Test / lint / audit / Docker build / Trivy / Checkov / kubeconform
    ↓
Manual deployment workflow
    ↓
Private AWS self-hosted runner
    ↓
Build and scan Docker image
    ↓
Push immutable image tag to ECR
    ↓
Update Argo Rollout image
    ↓
Canary traffic shift
    ↓
Prometheus analysis
    ↓
Promote or abort
    ↓
Grafana observability
```

---

## Technology Stack

| Area | Tooling |
|---|---|
| Cloud Provider | AWS |
| Container Orchestration | Amazon EKS |
| Infrastructure as Code | Terraform |
| Container Registry | Amazon ECR |
| CI/CD | GitHub Actions |
| Deployment Strategy | Argo Rollouts |
| Ingress | NGINX Ingress Controller |
| Metrics | Prometheus |
| Dashboarding | Grafana |
| Image Scanning | Trivy |
| IaC Security | Checkov |
| Manifest Validation | kubeconform |
| Runtime | Node.js / Express |
| Runner Model | Private EC2 self-hosted GitHub Actions runner |

---

## Application Endpoints

The Orders API exposes:

| Endpoint | Purpose |
|---|---|
| `/health` | Confirms application health and deployed version |
| `/live` | Kubernetes liveness probe |
| `/ready` | Kubernetes readiness probe |
| `/api/orders` | Sample business API endpoint |
| `/metrics` | Prometheus metrics endpoint |

Example health response:

```json
{
  "status": "healthy",
  "color": "blue",
  "version": "v4.0.2",
  "fail_mode": "none"
}
```

---

## Progressive Delivery Design

The application is deployed using Argo Rollouts rather than a normal Kubernetes Deployment.

The rollout strategy uses staged canary delivery:

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

The success-rate query is:

```promql
(
  sum(rate(http_requests_total{status_code!~"5.."}[1m]))
  /
  clamp_min(sum(rate(http_requests_total[1m])), 1)
) or vector(1)
```

This query was hardened after an earlier failure caused by empty Prometheus results. The final query avoids missing-series failure and division-by-zero failure.

---

## Successful Canary Proof

A successful `v2.0.0` rollout was tested.

Evidence captured:

- v2 image built and scanned clean
- v2 image pushed to ECR
- Argo Rollouts shifted traffic through canary stages
- Prometheus analysis passed
- v2 became stable
- `/health` returned `v2.0.0`

Representative evidence files:

```text
docs/evidence/canary-v2-rollout-status.txt
docs/evidence/canary-v2-analysisruns.txt
docs/evidence/canary-v2-health.json
docs/evidence/prometheus-success-rate-query.json
```

---

## Failed Canary / Rollback Protection Proof

A deliberately broken `v3.0.0` rollout was tested using failure mode.

Expected behaviour:

```text
v3 enters canary
Prometheus detects degraded success rate
Argo Rollouts aborts the rollout
v3 ReplicaSet is scaled down
v2 remains stable
live users continue receiving the healthy version
```

This was proven successfully.

Representative evidence files:

```text
docs/evidence/failed-canary-v3-rollout-status.txt
docs/evidence/failed-canary-v3-analysisruns.txt
docs/evidence/failed-canary-v3-health-after-abort.json
docs/evidence/prometheus-v3-success-rate.json
docs/evidence/prometheus-v3-5xx-rate.json
```

---

## CI Quality and Security Gate

The CI workflow runs on push and pull request.

Checks include:

- dependency installation
- unit tests
- syntax/lint check
- npm audit
- Docker build
- Trivy image scan
- Terraform formatting
- Terraform validation
- kubeconform Kubernetes manifest validation
- Checkov Terraform scan

Workflow file:

```text
.github/workflows/ci.yml
```

This prevents low-quality or insecure changes from entering the main branch unnoticed.

---

## Deployment Workflow

The deployment workflow runs manually through GitHub Actions.

Workflow file:

```text
.github/workflows/deploy.yml
```

The deployment job:

1. runs on a private AWS self-hosted runner
2. confirms AWS identity through the EC2 IAM role
3. builds the Docker image
4. scans the image with Trivy
5. pushes the immutable image tag to ECR
6. updates the Argo Rollout image
7. waits for rollout completion
8. prints rollout diagnostics

---

## Private Self-Hosted Runner Design

A key design decision was to avoid opening the EKS API endpoint to GitHub-hosted runners.

Instead, this project uses a private EC2 self-hosted runner:

- deployed in a private subnet
- no public IP
- accessed through AWS Systems Manager Session Manager
- uses an IAM role attached through an instance profile
- reaches the EKS private API endpoint through VPC networking
- runs GitHub Actions deployment jobs close to the cluster

This is stronger than allowing `0.0.0.0/0` access to the EKS API.

Production improvement:

```text
Use ephemeral self-hosted runners or an autoscaling runner controller rather than a long-lived EC2 runner.
```

---

## Observability

Grafana dashboards were created to visualise:

- request rate
- 5xx error rate
- success rate
- request rate by version
- request rate by status code
- business failure rate

Dashboard documentation:

```text
docs/grafana-dashboard.md
```

Representative evidence files:

```text
docs/evidence/grafana-query-request-rate.json
docs/evidence/grafana-query-success-rate.json
docs/evidence/grafana-query-request-rate-by-version.json
docs/evidence/grafana-query-request-rate-by-status-code.json
```

---

## Security Controls

Implemented controls include:

- Terraform-managed infrastructure
- remote state backend
- ECR immutable tags
- Trivy image scanning
- Checkov IaC scanning
- kubeconform manifest validation
- KMS encryption for supported services
- private self-hosted runner
- EKS access controlled through IAM/EKS access entries
- NetworkPolicy for application namespace
- no long-lived AWS keys in GitHub Actions deployment

Documented security notes:

```text
docs/security.md
```

---

## Evidence Directory

Evidence is stored under:

```text
docs/evidence/
```

Evidence includes:

- Terraform plans and outputs
- Checkov scan results
- Trivy scan results
- EKS node and pod state
- Argo Rollouts status
- successful canary proof
- failed canary proof
- Prometheus query outputs
- Grafana query evidence
- GitHub Actions deployment proof

Evidence index:

```text
docs/evidence-index.md
```

---

## Repository Structure

```text
.
├── app/
│   ├── src/
│   ├── tests/
│   ├── Dockerfile
│   ├── package.json
│   └── package-lock.json
├── k8s/
│   ├── base/
│   └── rollouts/
├── scripts/
│   ├── 04_build_and_scan_local.sh
│   ├── 05_aws_preflight.sh
│   ├── 06_bootstrap_terraform_backend.sh
│   ├── 10_install_platform_addons.sh
│   ├── 11_build_push_ecr.sh
│   ├── 12_create_k8s_app_manifests.sh
│   ├── 13_create_argo_rollout_manifests.sh
│   └── 14_create_broken_v3_rollout.sh
├── terraform/
│   └── environments/
│       └── dev/
├── docs/
│   ├── evidence/
│   ├── architecture.md
│   ├── progressive-delivery.md
│   ├── runbook.md
│   ├── security.md
│   ├── cost-and-teardown.md
│   └── evidence-index.md
└── .github/
    └── workflows/
        ├── ci.yml
        └── deploy.yml
```

---

## Rebuild Guide

From a clean AWS account state with the Terraform backend still available:

```bash
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev plan -out=tfplan
terraform -chdir=terraform/environments/dev apply tfplan
```

Update kubeconfig:

```bash
aws eks update-kubeconfig --region us-east-1 --name epd-eks-dev
kubectl get nodes
```

Install platform add-ons:

```bash
./scripts/10_install_platform_addons.sh
```

Push the application image:

```bash
IMAGE_TAG=v2.0.0 ./scripts/11_build_push_ecr.sh
```

Create and apply rollout manifests:

```bash
IMAGE_TAG=v2.0.0 ./scripts/13_create_argo_rollout_manifests.sh

kubectl apply -f k8s/rollouts/namespace.yaml
kubectl apply -f k8s/rollouts/serviceaccount.yaml
kubectl apply -f k8s/rollouts/service-stable.yaml
kubectl apply -f k8s/rollouts/service-canary.yaml
kubectl apply -f k8s/rollouts/servicemonitor.yaml
kubectl apply -f k8s/rollouts/analysis-template.yaml
kubectl apply -f k8s/rollouts/networkpolicy.yaml
kubectl apply -f k8s/rollouts/ingress.yaml
kubectl apply -f k8s/rollouts/rollout.yaml
```

Watch rollout:

```bash
kubectl argo rollouts get rollout orders-api -n app-dev --watch
```

---

## Cost and Teardown

This project can incur AWS charges from:

- EKS control plane
- EC2 worker nodes
- private EC2 runner
- NAT Gateway
- Load Balancer
- ECR image storage
- CloudWatch logs
- KMS keys

Teardown guide:

```text
docs/cost-and-teardown.md
```

Critical teardown command:

```bash
terraform -chdir=terraform/environments/dev destroy -auto-approve
```

ECR must be emptied before repository deletion if images exist.

---

## Known Limitations

This is a strong portfolio-grade project, but it is not a complete production platform.

Known limitations:

- private runner bootstrap is not fully automated yet
- runner is long-lived rather than ephemeral
- EKS access for the runner is broader than ideal
- no image signing with cosign yet
- no admission controller policy enforcement
- no External Secrets integration
- no autoscaling runner controller
- no full multi-environment promotion model
- no HTTPS custom domain on the ingress

These are valid future improvements, not hidden flaws.

---

## Future Improvements

Recommended next improvements:

- automate private runner bootstrap with cloud-init
- use ephemeral GitHub Actions runners
- add VPC endpoints for ECR, S3, STS, CloudWatch, and SSM
- add cosign image signing and verification
- add OPA Gatekeeper or Kyverno policies
- add External Secrets Operator with AWS Secrets Manager
- add HTTPS with ACM and Route 53
- add horizontal pod autoscaling
- add cluster autoscaling or Karpenter
- split Terraform into reusable modules
- create dev/staging/prod environments
- add architecture diagrams

---

## Final Assessment

This project demonstrates practical cloud platform engineering, DevOps, Kubernetes delivery, infrastructure security, and operational observability.

The strongest proof points are:

- successful canary promotion
- failed canary protection
- Prometheus-based rollout analysis
- private GitHub Actions deployment runner
- security scanning integrated into CI
- documented teardown and cost awareness

The project is suitable as an advanced cloud/devops portfolio project and can be extended into a production-grade platform with additional automation and governance.
