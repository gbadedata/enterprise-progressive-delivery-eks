#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-epd-eks}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET_NAME="${PROJECT_NAME}-tfstate-${ACCOUNT_ID}-${AWS_REGION}"
TABLE_NAME="${PROJECT_NAME}-tf-locks"

echo "AWS account: ${ACCOUNT_ID}"
echo "AWS region: ${AWS_REGION}"
echo "Terraform state bucket: ${BUCKET_NAME}"
echo "Terraform lock table: ${TABLE_NAME}"

echo
echo "Creating S3 bucket if it does not exist..."

if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "S3 bucket already exists: ${BUCKET_NAME}"
else
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi
fi

echo "Enabling S3 bucket versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "Enabling S3 bucket encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'

echo
echo "Creating DynamoDB lock table if it does not exist..."

if aws dynamodb describe-table \
  --table-name "${TABLE_NAME}" \
  --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "DynamoDB table already exists: ${TABLE_NAME}"
else
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --region "${AWS_REGION}" \
    --billing-mode PAY_PER_REQUEST \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH

  echo "Waiting for DynamoDB table to become active..."
  aws dynamodb wait table-exists \
    --table-name "${TABLE_NAME}" \
    --region "${AWS_REGION}"
fi

mkdir -p docs/evidence

cat > docs/evidence/terraform-backend.txt <<EOF
AWS_REGION=${AWS_REGION}
ACCOUNT_ID=${ACCOUNT_ID}
TF_STATE_BUCKET=${BUCKET_NAME}
TF_LOCK_TABLE=${TABLE_NAME}
EOF

echo
echo "Terraform backend bootstrap complete."
echo "Backend details saved to docs/evidence/terraform-backend.txt"
cat docs/evidence/terraform-backend.txt
