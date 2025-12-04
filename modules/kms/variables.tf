variable "project_name" {
  type        = string
  description = "Prefix for all KMS keys"
}

variable "pqc_keygen_role_arn" {
  type        = string
  description = "IAM role allowed to generate PQC hybrid keys"
}
