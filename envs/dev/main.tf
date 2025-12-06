
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

# PCA Module
  module "pca" {
  source = "../../modules/pca"  

  root_ca_arn = "arn:aws:acm-pca:us-east-1:394863179010:certificate-authority/05ead21a-a5bf-4175-a023-a08849f1c386"

  subordinate_ca_config = {
    common_name         = "quantum-sub-ca"
    organization        = "QuantumSafe"
    organizational_unit = "IssuingCA"
    locality            = "Dallas"
    state               = "Texas"
    country             = "US"
  }
}

# KMS Module

module "kms" {
  source = "../../modules/kms"

  project_name        = "dev"
  pqc_keygen_role_arn = module.iam.pqc_keygen_role_arn
}

# Secure S3 Bucket Module

module "secure_s3" {
  source = "../../modules/s3"

  bucket_name = "quantum-safe-artifacts-dev"
  project_name = "dev"

  kms_key_arn = module.kms.pqc_hybrid_key_arn

  iam_roles_allowed = [
    module.iam.pqc_keygen_role_arn,
    module.iam.lambda_scanner_role_arn
  ]

  # Lambda integration
  scanner_lambda_arn        = module.lambda_scanner.scanner_lambda_arn
  scanner_lambda_permission = module.lambda_scanner.allow_s3_permission
}

# Device Identity Module

module "device_identity" {
  source = "../../modules/device_identity"

  project_name        = "quantum-safe"
  environment         = "dev"
  artifact_bucket_arn = module.secure_s3.bucket_arn

  device_role_arn     = module.iam.device_role_arn
  subordinate_ca_arn  = module.pca.subordinate_ca_arn
}

#Module Scanner

module "lambda_scanner" {
  source = "../../modules/lambda"

  project_name             = "dev"
  lambda_scanner_role_arn  = module.iam.lambda_scanner_role_arn
  bucket_arn               = module.secure_s3.bucket_arn
  kms_key_arn              = module.kms.pqc_hybrid_key_arn
}
