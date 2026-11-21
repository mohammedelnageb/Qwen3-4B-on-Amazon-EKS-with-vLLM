provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "qwen-eks-vllm"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
