variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Map of public subnets"
  type        = map(string)
}

variable "private_subnets" {
  description = "Map of private subnets"
  type        = map(string)
}
