terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr        = var.vpc_cidr
  environment     = var.environment
  project_name    = var.project_name
}

# Security Module
module "security" {
  source = "./modules/security"
  
  vpc_id          = module.vpc.vpc_id
  environment     = var.environment
  project_name    = var.project_name
}

# EC2 Module
module "ec2" {
  source = "./modules/ec2"
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  security_groups = [module.security.security_group_id]
  environment     = var.environment
  project_name    = var.project_name
}
