resource "aws_iam_role" lambda_cert_issuer" {
    name = "lambda_cert_issuer_role"

    assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

    resource "aws_iam_role" "lambda_scanner" {
        name - "lambda_scanner_role"

        assume_role_policy = data.aws_iam_policy.lambda_trust.json
    }

    resource "aws_iam_role" "lambda_remediation" {
        name = "lambda_remediation_role"

    assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role" "pca_admin" {
    name = "pca_admin_role"

    assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resoure "aws_iam_role" "pqc_keygen" {
    name = "pqc_keygen_role"

    assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_documents" lambda_trust" {
    statement {
        effect = "Allow"

        principals {
        type    = "Service"
        identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
    }
}

module "iam" {
    source = "../../modules/iam"
}