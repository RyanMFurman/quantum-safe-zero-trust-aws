# -------------------------------------------------
# ADOPT EXISTING ROOT CA (USE DATA SOURCE)
# -------------------------------------------------

data "aws_acmpca_certificate_authority" "root" {
  arn = var.root_ca_arn
}

# -------------------------------------------------
# CREATE SUBORDINATE CA
# -------------------------------------------------

resource "aws_acmpca_certificate_authority" "subordinate" {
  type  = "SUBORDINATE"

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name         = var.subordinate_ca_config.common_name
      organization        = var.subordinate_ca_config.organization
      organizational_unit = var.subordinate_ca_config.organizational_unit
      locality            = var.subordinate_ca_config.locality
      state               = var.subordinate_ca_config.state
      country             = var.subordinate_ca_config.country
    }
  }

  permanent_deletion_time_in_days = 7
  usage_mode                      = "GENERAL_PURPOSE"
}

# Save CSR for manual signing
resource "local_file" "subordinate_csr" {
  filename = "${path.module}/subordinate_ca.csr"
  content  = aws_acmpca_certificate_authority.subordinate.certificate_signing_request
}
