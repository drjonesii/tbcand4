variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "tbcand4-dmi"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "environment" {
  description = "Environment name (e.g., test, dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["test", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: test, dev, staging, prod"
  }
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

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block"
  }
}
