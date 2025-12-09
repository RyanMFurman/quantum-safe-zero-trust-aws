# IAM TRUST POLICIES

# Generic Lambda trust policy (used by most Lambda roles)
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Device Identity Lambda trust policy (separate for clarity)
data "aws_iam_policy_document" "device_lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


# IAM ROLES

resource "aws_iam_role" "lambda_cert_issuer" {
  name               = "lambda_cert_issuer_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role" "lambda_scanner" {
  name               = "lambda_scanner_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role" "lambda_remediation" {
  name               = "lambda_remediation_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role" "pca_admin" {
  name               = "pca_admin_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role" "pqc_keygen" {
  name               = "pqc_keygen_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# Device Identity Lambda Execution Role
resource "aws_iam_role" "device_role" {
  name = "quantum-safe_device_role"

  # correct reference, only one assignment
  assume_role_policy = data.aws_iam_policy_document.device_lambda_trust.json

  tags = {
    Project = "quantum-safe"
    Role    = "device-identity"
  }
}

resource "aws_iam_role_policy_attachment" "cert_issuer_logs" {
  role       = aws_iam_role.lambda_cert_issuer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_caller_identity" "current" {}
