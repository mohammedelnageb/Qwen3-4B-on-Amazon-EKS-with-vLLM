variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  description = "Name used for the VPC and the EKS cluster"
  type        = string
  default     = "qwen-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (null = EKS default)"
  type        = string
  default     = null
}

variable "azs" {
  description = "Two AZs where g6.xlarge is available"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint (your IP/32)"
  type        = list(string)
}

variable "gpu_instance_types" {
  type    = list(string)
  default = ["g6.xlarge"]
}

variable "gpu_desired_size" {
  description = "0 = no GPU node (no GPU cost), 1 = one GPU node"
  type        = number
  default     = 0
}

variable "model_bucket_name" {
  description = "Bucket created by the persistent stack"
  type        = string
  default     = "qwen-models-058264225887"
}

variable "hf_token_secret_name" {
  description = "Secret created by the persistent stack"
  type        = string
  default     = "qwen-eks/hf-token"
}

variable "llm_namespace" {
  type    = string
  default = "llm"
}
