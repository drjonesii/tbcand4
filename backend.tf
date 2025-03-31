terraform {
  backend "s3" {
    bucket         = "turbot-assignment-state"
    key            = "terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
} 