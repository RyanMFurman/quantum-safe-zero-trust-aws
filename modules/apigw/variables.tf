variable "project_name" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

variable "lambda_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "attestation_lambda_invoke_arn" {
  description = "Invoke ARN for attestation lambda"
  type        = string
}

variable "attestation_lambda_name" {
  description = "Lambda name for attestation validator"
  type        = string
}
