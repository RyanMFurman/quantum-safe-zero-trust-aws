
# Device Identity Module
# Creates: DynamoDB table for device registry
# IAM role + policy for device onboarding

resource "aws_dynamodb_table" "device_registry" {
  name         = "${var.project_name}-device-registry"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-device-registry"
    Env  = var.environment
  }
}

resource "aws_iam_role_policy" "device_policy" {
  name = "${var.project_name}_device_policy"
  role = var.device_role_name      # <⬅ FIXED — NAME not ARN

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${var.artifact_bucket_arn}/device-csrs/*"
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.device_registry.arn
      }
    ]
  })
}

resource "aws_lambda_function" "onboard" {
  function_name = "${var.project_name}-device-onboard"
  role          = var.device_role_arn
  handler       = "onboard.handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = "${path.module}/onboard.zip"
  source_code_hash = filebase64sha256("${path.module}/onboard.zip")

  environment {
    variables = {
      DEVICE_TABLE = aws_dynamodb_table.device_registry.name
      SUB_CA_ARN   = var.subordinate_ca_arn
    }
  }
}
