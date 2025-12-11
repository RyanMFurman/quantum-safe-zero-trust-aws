output "api_id" {
  value = aws_api_gateway_rest_api.device_onboard.id
}

output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.device_onboard.id}.execute-api.${var.region}.amazonaws.com/${var.environment}/onboard"
}
