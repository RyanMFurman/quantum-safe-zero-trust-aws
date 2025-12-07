output "pca_admin_role_arn" {
    value = aws_iam_role.pca_admin.arn 
}

output "pqc_keygen_role_arn" {
  value = aws_iam_role.pqc_keygen.arn
}

output "lambda_scanner_role_arn" {
  value = aws_iam_role.lambda_scanner.arn
}

output "lambda_cert_issuer_role_arn" {
  value = aws_iam_role.lambda_cert_issuer.arn
}

output "lambda_remediation_role_arn" {
  value = aws_iam_role.lambda_remediation.arn
}

output "device_role_arn" {
  value = aws_iam_role.device_role.arn
}

output "device_role_name" {
  value = aws_iam_role.device_role.name
}
