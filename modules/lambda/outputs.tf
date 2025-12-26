output "scanner_lambda_arn" {
  value = aws_lambda_function.scanner.arn
}

output "allow_s3_permission" {
  value = aws_lambda_permission.allow_s3.id
}

output "scanner_dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "scanner_lambda_name" {
  value = aws_lambda_function.scanner.function_name
}
