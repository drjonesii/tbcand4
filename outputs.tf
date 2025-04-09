output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_cidrs" {
  description = "The CIDR blocks of the public subnets"
  value       = module.vpc.public_subnet_cidrs
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "private_subnet_cidrs" {
  description = "The CIDR blocks of the private subnets"
  value       = module.vpc.private_subnet_cidrs
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = module.ec2.instance_id
}

output "instance_private_ip" {
  description = "The private IP of the EC2 instance"
  value       = module.ec2.instance_private_ip
}

output "instance_security_group_id" {
  description = "The ID of the instance security group"
  value       = module.ec2.security_group_id
}

# Remove or fix these outputs if they're not properly defined
# output "cis_report_bucket_name" {
#   description = "The name of the CIS report bucket"
#   value       = aws_s3_bucket.cis_report.id
# }

# output "terraform_state_bucket_name" {
#   description = "The name of the Terraform state bucket"
#   value       = aws_s3_bucket.terraform_state.id
# }
