
# Dev Environment Root Module


terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC Module


module "vpc" {
  source = "../../modules/vpc"

  name = "dev"

  vpc_cidr = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets = {
    public1 = "10.0.1.0/24"
    public2 = "10.0.2.0/24"
  }

  private_subnets = {
    private1 = "10.0.101.0/24"
    private2 = "10.0.102.0/24"
  }
}


# IAM Module


module "iam" {
  source = "../../modules/iam"
}
