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

  project_name  = var.project_name
  environment   = var.environment
  ami_id        = "ami-0c55b159cbfafe1f0" # Example AMI ID
  instance_type = "t3.micro"
  subnet_id     = module.vpc.private_subnet_ids[0]
  vpc_id        = module.vpc.vpc_id
  cloudwatch_kms_key_arn  = module.vpc.cloudwatch_kms_key_arn
  s3_kms_key_arn         = aws_kms_key.s3_encryption.arn
  dynamodb_kms_key_arn   = aws_kms_key.dynamodb_encryption.arn
}
