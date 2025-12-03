resource "aws_acmpca_certificate_authority" "root_ca" {
  type = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name  = "${var.project_name}-root-ca"
      organization = "QuantumSafe"
      country      = "US"
    }
  }

  revocation_configuration {
    crl_configuration {
      enabled = false
    }
  }

  permanent_deletion_time_in_days = 7

  tags = {
    Name = "${var.project_name}-root-ca"
  }
}

resource "aws_acmpca_certificate_authority" "subordinate_ca" {
  type = "SUBORDINATE"

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name  = "${var.project_name}-sub-ca"
      organization = "QuantumSafe"
      country      = "US"
    }
  }

  revocation_configuration {
    crl_configuration {
      enabled = false
    }
  }

  permanent_deletion_time_in_days = 7

  tags = {
    Name = "${var.project_name}-sub-ca"
  }
}

resource "aws_acmpca_certificate" "sub_ca_cert" {
  certificate_authority_arn    = aws_acmpca_certificate_authority.root_ca.arn
  certificate_signing_request   = aws_acmpca_certificate_authority.subordinate_ca.certificate_signing_request
  signing_algorithm             = "SHA512WITHRSA"

  validity {
    type  = "YEARS"
    value = var.sub_ca_validity_years
  }
}

resource "aws_acmpca_certificate_authority_certificate" "sub_ca_import" {
  certificate_authority_arn = aws_acmpca_certificate_authority.subordinate_ca.arn
  certificate               = aws_acmpca_certificate.sub_ca_cert.certificate
  certificate_chain         = aws_acmpca_certificate.sub_ca_cert.certificate_chain
}

resource "aws_acmpca_permission" "pca_admin" {
  certificate_authority_arn = aws_acmpca_certificate_authority.subordinate_ca.arn
  principal                 = "acm.amazonaws.com"
  actions                   = ["IssueCertificate", "GetCertificate", "ListPermissions"]
  source_account            = split(":", var.pca_admin_role_arn)[4]
}
