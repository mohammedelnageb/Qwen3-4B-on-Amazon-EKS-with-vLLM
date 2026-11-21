output "model_bucket_name" {
  value = aws_s3_bucket.models.bucket
}

output "model_bucket_arn" {
  value = aws_s3_bucket.models.arn
}

output "hf_token_secret_arn" {
  value = aws_secretsmanager_secret.hf_token.arn
}
