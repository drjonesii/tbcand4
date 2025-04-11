terraform {
  required_version = ">= 1.11.3"
  backend "s3" {
    use_lockfile = true
    encrypt      = true
    region       = "us-west-1"
  }
} 