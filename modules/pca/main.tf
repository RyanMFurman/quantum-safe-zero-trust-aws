# -------------------------------------------------
# ADOPT EXISTING ROOT CA (USE DATA SOURCE)
# -------------------------------------------------

data "aws_acmpca_certificate_authority" "root" {
  arn = var.root_ca_arn
}

# -------------------------------------------------
# OPTION 1 — USE EXISTING SUBORDINATE CA
# -------------------------------------------------

locals {
  subordinate_ca_arn = var.use_existing_subordinate_ca ? var.existing_subordinate_ca_arn : aws_acmpca_certificate_authority.subordinate[0].arn
}

# -------------------------------------------------
# OPTION 2 — CREATE SUBORDINATE CA (ONLY IF NEEDED)
# -------------------------------------------------

resource "aws_acmpca_certificate_authority" "subordinate" {
  count = var.use_existing_subordinate_ca ? 0 : 1

  type = "SUBORDINATE"

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

# -------------------------------------------------
# ONLY WRITE CSR IF WE CREATED A NEW SUB CA
# -------------------------------------------------

resource "local_file" "subordinate_csr" {
  count    = var.use_existing_subordinate_ca ? 0 : 1
  filename = "${path.module}/subordinate_ca.csr"
  content  = aws_acmpca_certificate_authority.subordinate[0].certificate_signing_request

  depends_on = [
    aws_acmpca_certificate_authority.subordinate
  ]
}


