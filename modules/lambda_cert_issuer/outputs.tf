output "lambda_cert_issuer_arn" {
  value = aws_lambda_function.issuer.arn
}

output "lambda_cert_issuer_name" {
  value = aws_lambda_function.issuer.function_name
}

output "lambda_cert_issuer_permission" {
  value = aws_lambda_permission.allow_s3.id
}
