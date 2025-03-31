terraform {
  required_version = ">= 1.7.0"
  
  backend "s3" {
    bucket         = "turbot-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
} 