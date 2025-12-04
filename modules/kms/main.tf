data "aws_caller_identity" "current" {}

resource "aws_kms_key" "rsa_key" {
  description              = "${var.project_name}-rsa4096"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_4096"
  deletion_window_in_days  = 7

  tags = {
    Name = "${var.project_name}-rsa4096"
  }
}

resource "aws_kms_key" "ecc_key" {
  description              = "${var.project_name}-eccp384"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P384"
  deletion_window_in_days  = 7

  tags = {
    Name = "${var.project_name}-eccp384"
  }
}

resource "aws_kms_key" "pqc_hybrid_key" {
  description              = "${var.project_name}-pqc-hybrid"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 7

  tags = {
    Name = "${var.project_name}-pqc-hybrid"
  }
}

resource "aws_kms_key_policy" "pqc_key_policy" {
  key_id = aws_kms_key.pqc_hybrid_key.key_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountRootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowPQCKeyGenRole"
        Effect = "Allow"
        Principal = {
          AWS = var.pqc_keygen_role_arn
        }
        Action = [
          "kms:GenerateDataKeyPair",
          "kms:GenerateDataKey",
          "kms:Encrypt",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}
