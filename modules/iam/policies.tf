
#IAM INLINE POLICIES 



#Certificate Issuer Role


data "aws_iam_policy_document" "cert_issuer_policy" {
  statement {
    actions = [
      "acm-pca:IssueCertificate",
      "acm-pca:GetCertificate",
      "acm-pca:DescribeCertificateAuthority"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cert_issuer_inline" {
  role   = aws_iam_role.lambda_cert_issuer.name
  policy = data.aws_iam_policy_document.cert_issuer_policy.json
}


#Lambda Scanner Role


data "aws_iam_policy_document" "scanner_policy" {
  statement {
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "acm-pca:ListCertificateAuthorities",
      "acm-pca:DescribeCertificateAuthority",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "kms:Encrypt",
      "kms:Decrypt",
      "sqs:SendMessage"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "scanner_inline" {
  role   = aws_iam_role.lambda_scanner.name
  policy = data.aws_iam_policy_document.scanner_policy.json
}


#Remediation Role


data "aws_iam_policy_document" "remediation_policy" {
  statement {
    actions = [
      "acm:DeleteCertificate",
      "acm:RequestCertificate",
      "acm:DescribeCertificate"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "remediation_inline" {
  role   = aws_iam_role.lambda_remediation.name
  policy = data.aws_iam_policy_document.remediation_policy.json
}


#PCA Admin Role


data "aws_iam_policy_document" "pca_admin_policy" {
  statement {
    actions = [
      "acm-pca:IssueCertificate",
      "acm-pca:GetCertificate",
      "acm-pca:ListCertificateAuthorities",
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:RevokeCertificate",
      "acm-pca:ListPermissions"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "pca_admin_inline" {
  role   = aws_iam_role.pca_admin.name
  policy = data.aws_iam_policy_document.pca_admin_policy.json
}


#PQC KeyGen Role


data "aws_iam_policy_document" "pqc_keygen_policy" {
  statement {
    actions = [
      "kms:GenerateDataKeyPair",
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:Encrypt"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "pqc_keygen_inline" {
  role   = aws_iam_role.pqc_keygen.name
  policy = data.aws_iam_policy_document.pqc_keygen_policy.json
}

# Device Identity Policy
data "aws_iam_policy_document" "device_policy" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTable"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "device_policy" {
  role   = aws_iam_role.device_role.name
  policy = data.aws_iam_policy_document.device_policy.json
}
