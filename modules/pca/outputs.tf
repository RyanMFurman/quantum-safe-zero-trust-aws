
# ROOT CA ARN (ALWAYS EXISTS)

output "root_ca_arn" {
  value = data.aws_acmpca_certificate_authority.root.arn
}

# SUBORDINATE CA ARN (DYNAMIC: EXISTING OR CREATED)

output "subordinate_ca_arn" {
  value = var.use_existing_subordinate_ca ? var.existing_subordinate_ca_arn : aws_acmpca_certificate_authority.subordinate[0].arn
}


# CSR OUTPUT (ONLY IF WE CREATED A NEW SUB CA)

output "subordinate_csr" {
  value       = var.use_existing_subordinate_ca ? null : aws_acmpca_certificate_authority.subordinate[0].certificate_signing_request
  description = "CSR for the subordinate CA—only present if Terraform created a new CA."
}
