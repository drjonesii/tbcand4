variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], lower(var.environment))
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a valid AWS EC2 instance type (e.g., t2.micro, t3.small)"
  }
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ami_id))
    error_message = "AMI ID must be a valid AWS AMI ID (e.g., ami-0c7217cdde317cfec)"
  }
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be created"
  type        = string

  validation {
    condition     = can(regex("^subnet-[0-9a-f]{17}$", var.subnet_id))
    error_message = "Subnet ID must be a valid AWS subnet ID (e.g., subnet-0c7217cdde317cfec)"
  }
}

variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{17}$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID (e.g., vpc-0c7217cdde317cfec)"
  }
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 16384
    error_message = "Root volume size must be between 8 and 16384 GB"
  }
}

variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the instance via SSH. Must not be empty and must not contain 0.0.0.0/0"
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidr_blocks) > 0
    error_message = "allowed_ssh_cidr_blocks must not be empty. At least one CIDR block must be specified."
  }

  validation {
    condition     = !contains(var.allowed_ssh_cidr_blocks, "0.0.0.0/0")
    error_message = "allowed_ssh_cidr_blocks must not contain 0.0.0.0/0. Use specific CIDR blocks instead."
  }

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.allowed_ssh_cidr_blocks[0]))
    error_message = "Each CIDR block must be in the format x.x.x.x/y where x is between 0-255 and y is between 0-32."
  }
}
