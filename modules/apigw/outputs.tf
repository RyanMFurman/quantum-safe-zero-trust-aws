output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.device_onboard.id}.execute-api.${var.region}.amazonaws.com/dev/onboard"
}

output "api_id" {
  value = aws_api_gateway_rest_api.device_onboard.id
}

output "resource_id" {
  value = aws_api_gateway_resource.onboard.id
}

