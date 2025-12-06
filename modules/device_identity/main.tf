
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

resource "aws_iam_role" "device_role" {
  name = "${var.project_name}_device_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "device_policy" {
  name = "${var.project_name}_device_policy"
  role = aws_iam_role.device_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow device to upload CSR to S3
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.artifact_bucket_arn}/device-csrs/*"
      },

      # Allow device to write its metadata to DynamoDB
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
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

  filename = "${path.module}/onboard.zip"

  environment {
    variables = {
      DEVICE_TABLE = aws_dynamodb_table.device_registry.name
      SUB_CA_ARN   = var.subordinate_ca_arn
    }
  }
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.onboard.arn
  principal     = "apigateway.amazonaws.com"
}
