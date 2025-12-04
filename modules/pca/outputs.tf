output "root_ca_arn" {
  value = data.aws_acmpca_certificate_authority.root.arn
}

output "subordinate_ca_arn" {
  value = aws_acmpca_certificate_authority.subordinate.arn
}

output "subordinate_csr" {
  value = aws_acmpca_certificate_authority.subordinate.certificate_signing_request
}
