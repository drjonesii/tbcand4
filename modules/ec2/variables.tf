variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string

  validation {
    condition     = contains(["test", "dev", "staging", "prod"], lower(var.environment))
    error_message = "Environment must be one of: test, dev, staging, prod"
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
  description = "The EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = var.instance_type == "t3.micro"
    error_message = "Only t3.micro instance type is allowed."
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

variable "cis_report_bucket" {
  description = "Name of the S3 bucket where CIS reports will be stored"
  type        = string
  default     = "cis-reports"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.cis_report_bucket))
    error_message = "S3 bucket name must be valid according to AWS naming rules."
  }
}

variable "cloudwatch_kms_key_arn" {
  description = "ARN of the KMS key used for CloudWatch logs encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]{36}$", var.cloudwatch_kms_key_arn))
    error_message = "Must be a valid KMS key ARN"
  }
}

variable "s3_kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]{36}$", var.s3_kms_key_arn))
    error_message = "Must be a valid KMS key ARN"
  }
}

variable "dynamodb_kms_key_arn" {
  description = "ARN of the KMS key used for DynamoDB encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]{36}$", var.dynamodb_kms_key_arn))
    error_message = "Must be a valid KMS key ARN"
  }
}
