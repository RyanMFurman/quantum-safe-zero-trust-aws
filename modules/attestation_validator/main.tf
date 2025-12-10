resource "aws_iam_role" "attestation_role" {
  name = "${var.project_name}-attestation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach basic logging
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.attestation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Inline permissions for DynamoDB + KMS decrypt (if needed)
resource "aws_iam_role_policy" "inline" {
  role = aws_iam_role.attestation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.device_table_name}"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "attestation" {
  function_name = "${var.project_name}-attestation"

  role          = aws_iam_role.attestation_role.arn
  handler       = "attestation.lambda_handler"
  runtime       = "python3.12"

  filename         = "${path.module}/attestation.zip"
  source_code_hash = filebase64sha256("${path.module}/attestation.zip")

  environment {
    variables = {
      DEVICE_TABLE = var.device_table_name
    }
  }
}

output "attestation_lambda_arn" {
  value = aws_lambda_function.attestation.arn
}
