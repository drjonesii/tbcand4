terraform {
  required_version = ">= 1.11.3"
  backend "local" {
    path = "terraform.tfstate"
  }
} 