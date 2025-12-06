variable "bucket_name" {
  description = "Name of the secure bucket"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key used for encryption"
  type        = string
}

variable "iam_roles_allowed" {
  description = "IAM role ARNs allowed to read/write"
  type        = list(string)
}
