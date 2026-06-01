output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.orders_api.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC deployment."
  value       = aws_iam_role.github_actions_deploy.arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "github_runner_public_ip" {
  description = "Public IP of the GitHub Actions self-hosted runner."
  value       = aws_instance.github_runner.public_ip
}

output "github_runner_instance_id" {
  description = "EC2 instance ID of the GitHub Actions self-hosted runner."
  value       = aws_instance.github_runner.id
}

output "github_runner_role_arn" {
  description = "IAM role ARN attached to the EC2 self-hosted runner."
  value       = aws_iam_role.github_runner_ec2.arn
}
