variable "project_name" {
  type        = string
  description = "Environment/project name (dev, prod, etc.)"
}

variable "cert_issuer_lambda_name" {
  type        = string
  description = "Certificate issuer Lambda function name"
}

variable "attestation_lambda_name" {
  type        = string
  description = "Attestation Lambda function name"
}

variable "device_onboard_lambda_name" {
  type        = string
  description = "Device onboarding Lambda function name"
}

variable "scanner_lambda_name" {
  type        = string
  description = "Scanner Lambda function name"
}

variable "subordinate_ca_arn" {
  type        = string
  description = "Subordinate CA ARN"
}

variable "artifact_bucket_name" {
  type        = string
  description = "Artifact S3 bucket name"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Device registry DynamoDB table name"
}

variable "api_gateway_name" {
  type        = string
  description = "API Gateway name used for metrics"
}
