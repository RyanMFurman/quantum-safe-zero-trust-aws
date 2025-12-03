output "root_ca_arn" {
  description = "ARN of the root certificate authority"
  value       = aws_acmpca_certificate_authority.root_ca.arn
}

output "subordinate_ca_arn" {
  description = "ARN of the subordinate certificate authority"
  value       = aws_acmpca_certificate_authority.subordinate_ca.arn
}

output "subordinate_ca_certificate_arn" {
  description = "ARN of the certificate imported into the subordinate CA"
  value       = aws_acmpca_certificate_authority_certificate.sub_ca_import.certificate_authority_arn
}
