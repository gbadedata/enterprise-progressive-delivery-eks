#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REGION="${AWS_REGION:-us-east-1}"

echo "Checking AWS CLI..."
aws --version

echo
echo "Checking configured AWS identity..."
aws sts get-caller-identity

echo
echo "Checking AWS region..."
CONFIGURED_REGION="$(aws configure get region || true)"

if [ -z "${CONFIGURED_REGION}" ]; then
  echo "No default AWS region configured."
  echo "Setting default region to ${DEFAULT_REGION}."
  aws configure set region "${DEFAULT_REGION}"
else
  echo "Configured region: ${CONFIGURED_REGION}"
fi

echo
echo "Checking required AWS service access..."

echo "Checking EKS access..."
aws eks list-clusters --region "${DEFAULT_REGION}" >/dev/null

echo "Checking ECR access..."
aws ecr describe-repositories --region "${DEFAULT_REGION}" >/dev/null 2>&1 || true

echo "Checking IAM access..."
aws iam list-account-aliases >/dev/null

echo "Checking EC2/VPC access..."
aws ec2 describe-vpcs --region "${DEFAULT_REGION}" >/dev/null

echo
echo "AWS preflight passed."
echo "Region: ${DEFAULT_REGION}"
