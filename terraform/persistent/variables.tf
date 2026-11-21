variable "region" {
  type    = string
  default = "us-east-1"
}

variable "model_bucket_name" {
  description = "S3 bucket that stores the Qwen model weights"
  type        = string
  default     = "qwen-models-058264225887"
}

variable "hf_token_secret_name" {
  description = "Secrets Manager secret name for the Hugging Face token"
  type        = string
  default     = "qwen-eks/hf-token"
}

variable "budget_limit_usd" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "20"
}

variable "budget_email" {
  description = "Email that receives budget alerts"
  type        = string
}
