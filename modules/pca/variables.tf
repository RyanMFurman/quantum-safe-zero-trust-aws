variable "root_ca_arn" {
  description = "Existing AWS ACM Private Root CA ARN"
  type        = string
  }

variable "subordinate_ca_config" {
  type = object({
    common_name         = string
    organization        = string
    organizational_unit = string
    locality            = string
    state               = string
    country             = string
  })
}
