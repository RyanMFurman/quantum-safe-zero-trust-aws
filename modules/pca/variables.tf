variable "use_existing_subordinate_ca" {
  type    = bool
  default = false
}

variable "existing_subordinate_ca_arn" {
  type    = string
  default = null
}

variable "root_ca_arn" {
  type = string
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
