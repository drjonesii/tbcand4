# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  project_name = var.project_name
}

# Security Module
module "security" {
  source = "./modules/security"

  vpc_id       = module.vpc.vpc_id
  environment  = var.environment
  project_name = var.project_name
}

# EC2 Module
module "ec2" {
  source = "./modules/ec2"

  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]
  environment   = var.environment
  project_name  = var.project_name
  ami_id        = "ami-0e0bf53f6def86294" # Amazon Linux 2 AMI in us-west-1
  sns_topic_arn = module.vpc.sns_topic_arn
}
