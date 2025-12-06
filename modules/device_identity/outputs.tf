output "device_role_arn" {
  value = aws_iam_role.device_role.arn
}

output "device_registry_table" {
  value = aws_dynamodb_table.device_registry.name
}

output "device_registry_arn" {
  value = aws_dynamodb_table.device_registry.arn
}
