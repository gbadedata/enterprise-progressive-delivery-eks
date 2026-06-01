#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-v1.0.0}"

echo "Getting ECR repository URL from Terraform output..."
ECR_REPO_URL="$(terraform -chdir=terraform/environments/dev output -raw ecr_repository_url)"

echo "ECR repository: ${ECR_REPO_URL}"
echo "Image tag: ${IMAGE_TAG}"

echo
echo "Getting AWS account ID..."
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

echo
echo "Logging in to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo
echo "Building Docker image..."
docker build --no-cache \
  -t orders-api:${IMAGE_TAG} \
  ./app

echo
echo "Running strict Trivy scan before push..."
mkdir -p docs/evidence

trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --format table \
  --output "docs/evidence/trivy-ecr-${IMAGE_TAG}.txt" \
  orders-api:${IMAGE_TAG}

echo
echo "Tagging image for ECR..."
docker tag orders-api:${IMAGE_TAG} "${ECR_REPO_URL}:${IMAGE_TAG}"

echo
echo "Pushing image to ECR..."
docker push "${ECR_REPO_URL}:${IMAGE_TAG}"

echo
echo "Capturing ECR image evidence..."
aws ecr describe-images \
  --repository-name "$(basename "${ECR_REPO_URL}")" \
  --region "${AWS_REGION}" \
  --query 'imageDetails[*].{Digest:imageDigest,Tags:imageTags,PushedAt:imagePushedAt,Size:imageSizeInBytes}' \
  --output table \
  > "docs/evidence/ecr-image-${IMAGE_TAG}.txt"

echo
echo "Image pushed successfully."
echo "Evidence:"
echo "docs/evidence/trivy-ecr-${IMAGE_TAG}.txt"
echo "docs/evidence/ecr-image-${IMAGE_TAG}.txt"
