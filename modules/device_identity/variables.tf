variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "artifact_bucket_arn" {
  type        = string
  description = "ARN of the secure S3 bucket for device onboarding"
}

variable "device_role_arn" {
  type = string
}

variable "subordinate_ca_arn" {
  type = string
}

variable "device_role_name" {
  type = string
}
