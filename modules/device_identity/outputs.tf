output "device_onboard_lambda_name" {
  value = aws_lambda_function.onboard.function_name
}

output "device_onboard_lambda_invoke_arn" {
  value = aws_lambda_function.onboard.invoke_arn
}

output "device_role_arn" {
  value = var.device_role_arn
}
