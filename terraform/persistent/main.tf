# ---------------------------------------------------------------------------
# Model weights bucket (private, encrypted, kept between sessions)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "models" {
  bucket = var.model_bucket_name
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# Hugging Face token (value is set manually with the AWS CLI, never in code)
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "hf_token" {
  name                    = var.hf_token_secret_name
  description             = "Hugging Face token used by the model download Job"
  recovery_window_in_days = 0
}

# ---------------------------------------------------------------------------
# Monthly cost budget with email alerts
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name         = "qwen-eks-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [50, 80, 100]

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_email]
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
