variable "bucket_name" {
  type = string
}

variable "project_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "iam_roles_allowed" {
  type = list(string)
}

variable "scanner_lambda_arn" {
  type = string
}

variable "scanner_lambda_permission" {
  type = string
}

variable "cert_issuer_lambda_arn" {
  type = string
}

variable "cert_issuer_lambda_permission" {
  type = string
}