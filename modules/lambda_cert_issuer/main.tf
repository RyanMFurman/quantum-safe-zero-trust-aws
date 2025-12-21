locals {
  lambda_name = "${var.project_name}-cert-issuer"
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "issuer" {
  function_name = local.lambda_name
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda_cert_issuer_role"

  runtime          = "python3.12"
  handler          = "issuer.lambda_handler"
  filename         = "${path.module}/issuer.zip"
  source_code_hash = filebase64sha256("${path.module}/issuer.zip")
  timeout          = 30

  layers = [
  "arn:aws:lambda:us-east-1:394863179010:layer:cryptography-py312:3"
  ]

  environment {
    variables = {
      SUBORDINATE_CA_ARN = var.subordinate_ca_arn
      DEVICE_TABLE       = var.device_table_name
      PROJECT_NAME       = var.project_name
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3InvokeCertIssuer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.issuer.function_name
  principal     = "s3.amazonaws.com"

  source_arn = "arn:aws:s3:::${var.bucket_name}"
}

resource "aws_s3_bucket_notification" "csr_event" {
  bucket = var.bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.issuer.arn
    events              = ["s3:ObjectCreated:*"]

    filter_prefix = "csr/"
    filter_suffix = ".csr"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

