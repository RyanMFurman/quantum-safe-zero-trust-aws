variable "project_name" {
  type        = string
  description = "Project/environment name prefix"
}

variable "root_ca_validity_years" {
  type        = number
  default     = 10
  description = "Valid duration of the Root CA certificate"
}

variable "sub_ca_validity_years" {
  type        = number
  default     = 3
  description = "Valid duration of the Subordinate CA certificate"
}

variable "pca_admin_role_arn" {
  type        = string
  description = "IAM role that will administer the CA (from IAM module)"
}
