#!/usr/bin/env bash
set -euo pipefail

TF_DIR="terraform/environments/dev"
MAIN_FILE="${TF_DIR}/main.tf"

echo "Backing up main.tf..."
cp "${MAIN_FILE}" "${MAIN_FILE}.pre-checkov-final.bak"

echo "Patching Terraform for remaining Checkov findings..."

python3 <<'PY'
from pathlib import Path

path = Path("terraform/environments/dev/main.tf")
text = path.read_text()

# Add account identity data if missing
if 'data "aws_caller_identity" "current" {}' not in text:
    text = text.replace(
        'locals {\n',
        'data "aws_caller_identity" "current" {}\n\nlocals {\n',
        1
    )

# Add KMS key for CloudWatch Logs if missing
kms_logs_block = '''
resource "aws_kms_key" "cloudwatch_logs" {
  description             = "KMS key for CloudWatch log group encryption"
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
      },
      {
        Sid    = "AllowCloudWatchLogsUse"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudwatch-logs-kms"
  })
}

resource "aws_kms_alias" "cloudwatch_logs" {
  name          = "alias/${local.name_prefix}-cloudwatch-logs"
  target_key_id = aws_kms_key.cloudwatch_logs.key_id
}

'''
if 'resource "aws_kms_key" "cloudwatch_logs"' not in text:
    marker = '# -----------------------------\n# VPC\n# -----------------------------\n'
    text = text.replace(marker, marker + "\n" + kms_logs_block, 1)

# Patch VPC flow log group: KMS encryption + 365 retention
old_lg = '''resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = 14

  tags = local.common_tags
}'''

new_lg = '''resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudwatch_logs.arn

  tags = local.common_tags
}'''

if old_lg in text:
    text = text.replace(old_lg, new_lg)
elif 'resource "aws_cloudwatch_log_group" "vpc_flow_logs"' in text:
    # Conservative line-level patch if formatting changed
    lines = text.splitlines()
    output = []
    inside = False
    for line in lines:
        if line.startswith('resource "aws_cloudwatch_log_group" "vpc_flow_logs"'):
            inside = True
        if inside and 'retention_in_days' in line:
            output.append('  retention_in_days = 365')
            output.append('  kms_key_id        = aws_kms_key.cloudwatch_logs.arn')
            continue
        output.append(line)
        if inside and line == '}':
            inside = False
    text = "\n".join(output) + "\n"

# Add explicit KMS policies to ECR and EKS secrets keys
old_ecr = '''resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr-kms"
  })
}'''

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
      },
      {
        Sid    = "AllowECRUse"
        Effect = "Allow"
        Principal = {
          Service = "ecr.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr-kms"
  })
}'''

if old_ecr in text:
    text = text.replace(old_ecr, new_ecr)

old_eks = '''resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS Kubernetes secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-secrets-kms"
  })
}'''

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
      },
      {
        Sid    = "AllowEKSUse"
        Effect = "Allow"
        Principal = {
          Service = "eks.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-secrets-kms"
  })
}'''

if old_eks in text:
    text = text.replace(old_eks, new_eks)

# Replace Checkov skip comment for EKS public endpoint with canonical Checkov syntax.
text = text.replace(
    '# checkov:skip=CKV_AWS_39:Public endpoint remains enabled for local operator access in this portfolio environment, but access is restricted to admin_cidr_blocks rather than 0.0.0.0/0.\nresource "aws_eks_cluster" "main"',
    '#checkov:skip=CKV_AWS_39: Public endpoint remains enabled for local operator access in this portfolio environment, but access is restricted to admin_cidr_blocks rather than 0.0.0.0/0.\nresource "aws_eks_cluster" "main"'
)

path.write_text(text)
PY

echo "Patch complete."
