output "rsa_key_arn" {
  value = aws_kms_key.rsa_key.arn
}

output "ecc_key_arn" {
  value = aws_kms_key.ecc_key.arn
}

output "pqc_hybrid_key_arn" {
  value = aws_kms_key.pqc_hybrid_key.arn
}
