variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the EC2 instance can be created"
  type        = list(string)
}

variable "security_groups" {
  description = "List of security group IDs to attach to the EC2 instance"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}
