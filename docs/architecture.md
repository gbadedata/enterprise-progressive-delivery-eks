# Architecture

## Purpose

This document explains the architecture of the Enterprise Progressive Delivery Platform on AWS EKS.

The platform is designed to demonstrate secure, observable, and controlled Kubernetes delivery using Terraform, Amazon EKS, Argo Rollouts, Prometheus, Grafana, NGINX Ingress, ECR, Trivy, Checkov, kubeconform, and GitHub Actions.

## Architecture Layers

### 1. Application Layer

The application is a Node.js Orders API exposing:

- `/health`
- `/live`
- `/ready`
- `/api/orders`
- `/metrics`

The `/metrics` endpoint exposes Prometheus metrics used for monitoring and rollout analysis.

### 2. Container Layer

The application is packaged into a Docker image.

Controls include:

- minimal runtime image
- vulnerability scanning with Trivy
- immutable ECR image tags
- versioned image tags such as `v2.0.0`, `v3.0.0`, and `v4.0.x`

### 3. Infrastructure Layer

Terraform provisions:

- VPC
- public subnets
- private subnets
- route tables
- NAT Gateway
- Amazon EKS
- EKS managed node group
- Amazon ECR
- IAM roles and policies
- KMS keys
- CloudWatch log groups
- private EC2 self-hosted GitHub Actions runner

### 4. Kubernetes Platform Layer

The cluster includes:

- NGINX Ingress Controller
- Argo Rollouts
- Prometheus
- Grafana
- ServiceMonitor
- NetworkPolicy
- Orders API namespace

### 5. Progressive Delivery Layer

Argo Rollouts controls application delivery using:

- stable service
- canary service
- NGINX traffic routing
- Prometheus AnalysisTemplate
- canary traffic steps
- automated promotion or abort

### 6. CI/CD Layer

GitHub Actions provides:

- CI quality gate
- security scanning
- Docker build
- ECR push
- deployment through private AWS self-hosted runner

## Network Design

The EKS worker nodes and private runner run inside AWS networking.

The self-hosted runner is deployed in a private subnet with no public IP. Access is through AWS Systems Manager Session Manager.

This avoids exposing the EKS API publicly to GitHub-hosted runners.

## Deployment Path

```text
GitHub Actions workflow
    ↓
Private AWS self-hosted runner
    ↓
Build Docker image
    ↓
Trivy image scan
    ↓
Push image to ECR
    ↓
Update Argo Rollout
    ↓
Canary traffic shift
    ↓
Prometheus analysis
    ↓
Promote or abort
```

## Security-Oriented Architecture Decisions

- ECR image tags are immutable.
- The deployment runner uses an EC2 IAM role instead of static AWS keys.
- The runner is private and accessed through SSM.
- Terraform resources are scanned with Checkov.
- Kubernetes manifests are validated with kubeconform.
- Images are scanned before push/deployment.
- Rollout health is evaluated by Prometheus.

## Known Architecture Trade-Offs

The private runner is stronger than a public runner but increases operational overhead.

Current limitations:

- runner bootstrap is manual
- runner is long-lived
- EKS access for runner is broad
- no image signing yet
- no HTTPS custom domain yet
- no multi-environment promotion model yet
