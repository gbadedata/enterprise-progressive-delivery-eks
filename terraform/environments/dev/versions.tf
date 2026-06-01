terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "epd-eks-tfstate-677276115158-us-east-1"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "epd-eks-tf-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}
