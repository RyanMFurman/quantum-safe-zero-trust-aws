# S3 BUCKET

resource "aws_s3_bucket" "secure" {
  bucket = var.bucket_name

  tags = {
    Name = var.bucket_name
    Env  = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket                  = aws_s3_bucket.secure.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.secure.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.secure.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# BUCKET POLICY

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.iam_roles_allowed
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = ["${aws_s3_bucket.secure.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.secure.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# NOTIFICATIONS

resource "aws_s3_bucket_notification" "events" {
  bucket = aws_s3_bucket.secure.id

  # Scanner Lambda (uploads/)
  lambda_function {
    lambda_function_arn = var.scanner_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  # Cert Issuer Lambda (csr/)
  lambda_function {
    lambda_function_arn = var.cert_issuer_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "csr/"
    filter_suffix       = ".csr"
  }

  depends_on = [
    var.scanner_lambda_permission,
    var.cert_issuer_lambda_permission
  ]
}

output "bucket_arn" {
  value = aws_s3_bucket.secure.arn
}
