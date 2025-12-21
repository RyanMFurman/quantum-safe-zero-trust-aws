#############################################
# IAM ROLE — Attestation Lambda
#############################################

resource "aws_iam_role" "attestation_role" {
  name = "${var.project_name}-attestation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action   = "sts:AssumeRole"
      }
    ]
  })
}

#############################################
# BASIC LOGGING PERMISSION
#############################################

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.attestation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#############################################
# INLINE POLICY — DynamoDB, S3, AND KMS DECRYPT  ← REQUIRED FIX
#############################################

resource "aws_iam_role_policy" "inline" {
  role = aws_iam_role.attestation_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [

      # DynamoDB access for device state
      {
        Effect   = "Allow",
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"],
        Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.device_table_name}"
      },

      # S3 read access for certificates
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "arn:aws:s3:::quantum-safe-artifacts-dev/csr/*"
      },

      # *** CRITICAL FIX ***
      # Allow Lambda to decrypt S3 objects (bucket uses KMS)
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/f740bd47-baaa-4773-8545-968422330234"

      }
    ]
  })
}

#############################################
# DATA SOURCE — Current Account
#############################################

data "aws_caller_identity" "current" {}

#############################################
# LAMBDA FUNCTION — Attestation Validator
#############################################

resource "aws_lambda_function" "attestation" {
  function_name = "${var.project_name}-attestation"

  role          = aws_iam_role.attestation_role.arn
  handler       = "attestation.lambda_handler"
  runtime       = "python3.12"

  filename         = "${path.module}/attestation.zip"
  source_code_hash = filebase64sha256("${path.module}/attestation.zip")

  # cryptography layer (matches cert-issuer)
  layers = [
    "arn:aws:lambda:us-east-1:394863179010:layer:cryptography-py312:1"
  ]

  environment {
    variables = {
      DEVICE_TABLE = var.device_table_name
    }
  }
}

#############################################
# OUTPUTS
#############################################

output "attestation_lambda_arn" {
  value = aws_lambda_function.attestation.arn
}

output "attestation_lambda_name" {
  value = aws_lambda_function.attestation.function_name
}

output "attestation_lambda_invoke_arn" {
  value = aws_lambda_function.attestation.invoke_arn
}
