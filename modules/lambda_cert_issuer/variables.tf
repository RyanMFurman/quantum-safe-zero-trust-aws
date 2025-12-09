variable "project_name" {
  description = "Project prefix for naming resources"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket where CSR files are uploaded"
  type        = string
}

variable "subordinate_ca_arn" {
  description = "ARN of subordinate CA used to sign device certificates"
  type        = string
}

variable "device_table_name" {
  description = "DynamoDB table storing device registry entries"
  type        = string
}
