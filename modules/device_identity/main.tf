# Device Identity Module
# Creates: DynamoDB table + IAM policy for onboarding Lambda

resource "aws_dynamodb_table" "device_registry" {
  name         = "${var.project_name}-device-registry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-device-registry"
    Env  = var.environment
  }
}

# IAM POLICY for device onboarding Lambda
resource "aws_iam_role_policy" "device_policy" {
  name = "${var.project_name}_device_policy"
  role = var.device_role_name  # STAYS AS NAME

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # FIXED PREFIX — must match device_client.py (csr/)
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${var.artifact_bucket_arn}/csr/*"
      },

      # DynamoDB write permissions
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.device_registry.arn
      }
    ]
  })
}

# Onboarding Lambda Function
resource "aws_lambda_function" "onboard" {
  function_name = "${var.project_name}-device-onboard"
  role          = var.device_role_arn
  handler       = "onboard.handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = "${path.module}/onboard.zip"
  source_code_hash = filebase64sha256("${path.module}/onboard.zip")

  # REMOVE the cryptography layer — onboard doesn't need it
  # layers = []

  environment {
    variables = {
      DEVICE_TABLE = aws_dynamodb_table.device_registry.name
      SUB_CA_ARN   = var.subordinate_ca_arn
    }
  }
}
