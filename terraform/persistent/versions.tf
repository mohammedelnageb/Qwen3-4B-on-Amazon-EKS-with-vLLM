terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Separate state: these resources survive `terraform destroy` of envs/dev
  backend "s3" {
    bucket       = "qwen-eks-tfstate-058264225887"
    key          = "persistent/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "qwen-eks-vllm"
      Stack     = "persistent"
      ManagedBy = "terraform"
    }
  }
}
