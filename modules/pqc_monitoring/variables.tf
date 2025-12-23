variable "project_name" {
  type        = string
  description = "Environment or project prefix (ex: dev)"
}

variable "cert_issuer_lambda_name" {
  type        = string
  description = "Name of the certificate issuer Lambda"
}

variable "attestation_lambda_name" {
  type        = string
  description = "Name of the attestation validator Lambda"
}

variable "subordinate_ca_arn" {
  description = "ARN of the subordinate CA for monitoring certificate issuance"
  type        = string
}
