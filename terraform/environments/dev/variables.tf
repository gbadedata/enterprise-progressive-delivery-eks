variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name used for resource naming."
  type        = string
  default     = "epd-eks"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "epd-eks-dev"
}

variable "github_owner" {
  description = "GitHub username or organisation."
  type        = string
  default     = "gbadedata"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "enterprise-progressive-delivery-eks"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_node_count" {
  description = "Desired number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of EKS worker nodes."
  type        = number
  default     = 3
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint. Restricted to operator public IP for local administration. GitHub deployment uses a self-hosted runner inside AWS instead of opening the EKS API publicly."
  type        = list(string)
  default     = ["213.78.142.56/32"]
}

variable "runner_instance_type" {
  description = "EC2 instance type for the GitHub Actions self-hosted runner."
  type        = string
  default     = "t3.medium"
}

variable "runner_allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the self-hosted runner. Restrict to operator public IP."
  type        = string
  default     = "213.78.142.56/32"
}

variable "runner_key_name" {
  description = "EC2 key pair name for SSH access to the self-hosted runner."
  type        = string
  default     = "epd-eks-runner-key"
}
