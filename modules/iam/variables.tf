variable "subordinate_ca_arn" {
  type        = string
}

variable "device_table_name" {
  type        = string
}

variable "kms_key_arn" {
  type        = string
}

variable "bucket_name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
