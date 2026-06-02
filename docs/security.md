# Security Notes

## Implemented Controls

### Infrastructure as Code

Terraform defines and manages AWS infrastructure.

### Remote State

Terraform state is stored in an S3 backend with locking.

### Image Scanning

Docker images are scanned with Trivy for HIGH and CRITICAL vulnerabilities.

### Infrastructure Scanning

Terraform is scanned with Checkov.

### Kubernetes Validation

Kubernetes manifests are validated with kubeconform.

### ECR Immutability

ECR image tags are immutable. Released image tags cannot be overwritten.

### KMS Encryption

KMS encryption is used for supported AWS resources, including ECR and EKS secrets.

### Private Deployment Runner

The final deployment design uses a private AWS self-hosted runner.

The runner:

- has no public IP
- runs in a private subnet
- is accessed through AWS SSM
- uses an EC2 IAM role
- reaches the EKS API through VPC networking

## Why Not GitHub-Hosted Runners?

GitHub-hosted runners require the EKS API endpoint to be reachable from GitHub infrastructure.

Opening the EKS API endpoint broadly is weaker.

The private runner design avoids that compromise.

## Current Trade-Offs

The runner currently has broad EKS access for portfolio simplicity.

Production should use:

- namespace-scoped Kubernetes RBAC
- least-privilege IAM
- ephemeral runners
- isolated runner groups
- environment approval gates

## Production Hardening Recommendations

Recommended future improvements:

- ephemeral self-hosted runners
- VPC endpoints for AWS APIs
- cosign image signing
- Kyverno or OPA Gatekeeper admission policies
- External Secrets Operator
- AWS Secrets Manager integration
- runtime security monitoring
- private-only EKS endpoint
- namespace-scoped deployment permissions
