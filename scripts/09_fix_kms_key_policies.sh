#!/usr/bin/env bash
set -euo pipefail

MAIN_FILE="terraform/environments/dev/main.tf"

echo "Backing up main.tf..."
cp "${MAIN_FILE}" "${MAIN_FILE}.pre-kms-policy-fix.bak"

python3 <<'PY'
from pathlib import Path

path = Path("terraform/environments/dev/main.tf")
text = path.read_text()

def replace_block(text, start_marker, end_marker, new_block):
    start = text.find(start_marker)
    if start == -1:
        raise SystemExit(f"Could not find start marker: {start_marker}")

    end = text.find(end_marker, start)
    if end == -1:
        raise SystemExit(f"Could not find end marker after: {start_marker}")

    return text[:start] + new_block + "\n\n" + text[end:]

ecr_start = 'resource "aws_kms_key" "ecr" {'
ecr_end = 'resource "aws_kms_alias" "ecr" {'

new_ecr = '''resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr-kms"
  })
}'''

text = replace_block(text, ecr_start, ecr_end, new_ecr)

eks_start = 'resource "aws_kms_key" "eks_secrets" {'
eks_end = 'resource "aws_kms_alias" "eks_secrets" {'

new_eks = '''resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS Kubernetes secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-secrets-kms"
  })
}'''

text = replace_block(text, eks_start, eks_end, new_eks)

path.write_text(text)
PY

echo "KMS key policies patched."
