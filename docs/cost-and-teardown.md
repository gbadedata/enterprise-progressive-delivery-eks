# Cost and Teardown Guide

## Main Cost Drivers

This project can incur AWS charges from:

- Amazon EKS control plane
- EC2 worker nodes
- EC2 private self-hosted runner
- NAT Gateway
- Elastic Load Balancer
- ECR image storage
- CloudWatch logs
- KMS keys

The largest risks are:

```text
EKS control plane
NAT Gateway
EC2 instances
Load Balancer
```

## Teardown Process

Run from local machine:

```bash
cd ~/enterprise-progressive-delivery-eks
```

Delete Helm add-ons:

```bash
helm uninstall ingress-nginx -n ingress-nginx || true
helm uninstall monitoring -n monitoring || true
helm uninstall argo-rollouts -n argo-rollouts || true
```

Delete namespaces:

```bash
kubectl delete namespace app-dev --ignore-not-found
kubectl delete namespace ingress-nginx --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace argo-rollouts --ignore-not-found
```

Empty ECR repository:

```bash
aws ecr list-images \
  --repository-name epd-eks-dev-orders-api \
  --region us-east-1 \
  --query 'imageIds[*]' \
  --output json > /tmp/ecr-images.json

aws ecr batch-delete-image \
  --repository-name epd-eks-dev-orders-api \
  --region us-east-1 \
  --image-ids file:///tmp/ecr-images.json || true
```

Destroy Terraform resources:

```bash
terraform -chdir=terraform/environments/dev destroy -auto-approve
```

If ECR blocks deletion:

```bash
aws ecr delete-repository \
  --repository-name epd-eks-dev-orders-api \
  --region us-east-1 \
  --force

terraform -chdir=terraform/environments/dev destroy -auto-approve
```

## Verification

```bash
aws eks list-clusters --region us-east-1

aws ec2 describe-instances \
  --region us-east-1 \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table

aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' \
  --output table

aws ec2 describe-nat-gateways \
  --region us-east-1 \
  --query 'NatGateways[*].[NatGatewayId,State]' \
  --output table

aws ecr describe-repositories \
  --repository-names epd-eks-dev-orders-api \
  --region us-east-1
```

Safe state:

```text
No EKS clusters
No running EC2 instances
No active LoadBalancers
No available NAT Gateways
ECR repository deleted or empty
```

## Terraform Backend

Do not delete the S3 backend bucket or DynamoDB lock table unless retiring the project.

They preserve state and cost negligible amounts.
