
# TERRAFORM + PROVIDER

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

# DATA SOURCES

data "aws_caller_identity" "current" {}

# VPC MODULE

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

# IAM MODULE

module "iam" {
  source = "../../modules/iam"

  subordinate_ca_arn = module.pca.subordinate_ca_arn
  device_table_name  = module.device_identity.device_registry_name
  kms_key_arn        = module.kms.pqc_hybrid_key_arn

  bucket_name = "quantum-safe-artifacts-dev"
  aws_region  = "us-east-1"
}

# PCA MODULE

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

# KMS MODULE

module "kms" {
  source = "../../modules/kms"

  project_name        = "dev"
  pqc_keygen_role_arn = module.iam.pqc_keygen_role_arn
}

# SECURE S3
  
module "secure_s3" {
  source = "../../modules/s3"

  bucket_name  = "quantum-safe-artifacts-dev"
  project_name = "dev"

  kms_key_arn = module.kms.pqc_hybrid_key_arn

  iam_roles_allowed = [
    module.iam.pqc_keygen_role_arn,
    module.iam.lambda_scanner_role_arn
  ]

  scanner_lambda_arn        = module.lambda_scanner.scanner_lambda_arn
  scanner_lambda_permission = module.lambda_scanner.allow_s3_permission

  # UPDATED OUTPUT NAMES
  cert_issuer_lambda_arn        = module.lambda_cert_issuer.lambda_cert_issuer_arn
  cert_issuer_lambda_permission = module.lambda_cert_issuer.lambda_cert_issuer_permission
}

# DEVICE IDENTITY MODULE (LAMBDA)

module "device_identity" {
  source = "../../modules/device_identity"

  project_name        = "quantum-safe"
  environment         = "dev"
  artifact_bucket_arn = module.secure_s3.bucket_arn

  device_role_arn     = module.iam.device_role_arn
  device_role_name    = module.iam.device_role_name
  subordinate_ca_arn  = module.pca.subordinate_ca_arn
}

# LAMBDA SCANNER MODULE

module "lambda_scanner" {
  source = "../../modules/lambda"

  project_name            = "dev"
  lambda_scanner_role_arn = module.iam.lambda_scanner_role_arn
  bucket_arn              = module.secure_s3.bucket_arn
  kms_key_arn             = module.kms.pqc_hybrid_key_arn
}

# DEVICE API 

module "device_api" {
  source = "../../modules/apigw"

  project_name = "quantum-safe"

  # /onboard
  lambda_invoke_arn = module.device_identity.device_onboard_lambda_invoke_arn
  lambda_name       = module.device_identity.device_onboard_lambda_name

  # /attest  
  attestation_lambda_invoke_arn = module.attestation_validator.attestation_lambda_invoke_arn
  attestation_lambda_name       = module.attestation_validator.attestation_lambda_name

  environment = "dev"
  region      = "us-east-1"
  account_id  = data.aws_caller_identity.current.account_id
}

# LAMBDA CERT ISSUER
module "lambda_cert_issuer" {
  source = "../../modules/lambda_cert_issuer"

  project_name       = "dev"
  bucket_name        = "quantum-safe-artifacts-dev"
  subordinate_ca_arn = module.pca.subordinate_ca_arn
  device_table_name  = module.device_identity.device_registry_name
}

# ATTESTATION VALIDATOR
module "attestation_validator" {
  source = "../../modules/attestation_validator"

  project_name       = "dev"
  device_table_name  = module.device_identity.device_registry_name
  kms_key_arn        = module.kms.pqc_hybrid_key_arn
  subordinate_ca_arn = module.pca.subordinate_ca_arn
}

# OUTPUTS

output "device_onboard_lambda_name" {
  value = module.device_identity.device_onboard_lambda_name
}

output "device_onboard_lambda_invoke_arn" {
  value = module.device_identity.device_onboard_lambda_invoke_arn
}

output "api_id" {
  value = module.device_api.api_id
}

output "invoke_url" {
  value = module.device_api.invoke_url
}
