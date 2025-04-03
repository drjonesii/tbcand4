variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "turbot-assignment"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Primary AWS region for resource creation"
  type        = string
  default     = "us-west-1"
}

variable "replica_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
