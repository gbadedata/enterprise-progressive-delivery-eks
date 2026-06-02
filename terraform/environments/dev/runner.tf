# -----------------------------
# GitHub Actions Self-Hosted Runner EC2
# Private runner with SSM access
# -----------------------------

data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "github_runner" {
  name        = "${local.name_prefix}-github-runner-sg"
  description = "Security group for private GitHub Actions self-hosted runner"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow outbound internet access through NAT for GitHub, AWS APIs, ECR, and package installs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-github-runner-sg"
  })
}

resource "aws_iam_role" "github_runner_ec2" {
  name = "${local.name_prefix}-github-runner-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "github_runner_deploy" {
  name        = "${local.name_prefix}-github-runner-deploy-policy"
  description = "Permissions for EC2 self-hosted runner to deploy to EKS and push to ECR."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPullSpecificRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
        Resource = aws_ecr_repository.orders_api.arn
      },
      {
        Sid    = "EKSDescribeCluster"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_runner_deploy" {
  role       = aws_iam_role.github_runner_ec2.name
  policy_arn = aws_iam_policy.github_runner_deploy.arn
}

resource "aws_iam_role_policy_attachment" "github_runner_ssm" {
  role       = aws_iam_role.github_runner_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "github_runner" {
  name = "${local.name_prefix}-github-runner-profile"
  role = aws_iam_role.github_runner_ec2.name
}

resource "aws_instance" "github_runner" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = var.runner_instance_type
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.github_runner.id]
  iam_instance_profile        = aws_iam_instance_profile.github_runner.name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-github-actions-runner"
  })
}

# Allow the private self-hosted runner to reach the EKS private API endpoint.
resource "aws_security_group_rule" "github_runner_to_eks_api" {
  description              = "Allow GitHub self-hosted runner to reach EKS API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.github_runner.id
}
