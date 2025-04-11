terraform {
  required_version = ">= 1.11.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"

  default_tags {
    tags = {
      Project     = "turbot"
      Environment = "bootstrap"
      Owner       = "candidate4"
      Terraform   = "true"
    }
  }
}

# Add replica provider for cross-region replication
provider "aws" {
  alias  = "replica"
  region = "us-west-2" # Different region for replication

  default_tags {
    tags = {
      Project     = "turbot"
      Environment = "bootstrap"
      Owner       = "candidate4"
      Terraform   = "true"
    }
  }
} 