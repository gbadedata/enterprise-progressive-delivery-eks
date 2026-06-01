#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="orders-api"
IMAGE_TAG="local"

echo "Building Docker image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" ./app

echo "Removing any old test container..."
docker rm -f orders-api-local >/dev/null 2>&1 || true

echo "Running application container..."
docker run -d \
  --name orders-api-local \
  -p 3000:3000 \
  -e APP_VERSION=v1.0.0 \
  -e DEPLOYMENT_COLOR=blue \
  -e FAIL_MODE=none \
  "${IMAGE_NAME}:${IMAGE_TAG}"

echo "Waiting for container to start..."
sleep 5

echo "Testing /health..."
curl -fsS http://localhost:3000/health
echo

echo "Testing /ready..."
curl -fsS http://localhost:3000/ready
echo

echo "Testing /api/orders..."
curl -fsS http://localhost:3000/api/orders
echo

echo "Testing /metrics..."
curl -fsS http://localhost:3000/metrics | head
echo

echo "Running Trivy image scan..."
mkdir -p docs/evidence

trivy image \
  --severity HIGH,CRITICAL \
  --format table \
  --output docs/evidence/trivy-local-image-scan.txt \
  "${IMAGE_NAME}:${IMAGE_TAG}"

echo "Stopping local container..."
docker rm -f orders-api-local >/dev/null

echo "Local Docker build and scan completed."
echo "Trivy report: docs/evidence/trivy-local-image-scan.txt"
