# Resources owned by the persistent stack
data "aws_s3_bucket" "models" {
  bucket = var.model_bucket_name
}

data "aws_secretsmanager_secret" "hf_token" {
  name = var.hf_token_secret_name
}
