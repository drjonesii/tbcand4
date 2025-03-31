# Turbot Assignment

This is a Terraform project for infrastructure deployment.

## Project Structure

```
turbot-assignment/
├── main.tf           # Main Terraform configuration
├── variables.tf      # Variable definitions
├── outputs.tf        # Output definitions
├── terraform.tfvars  # Variable values
├── .gitignore       # Git ignore file
└── modules/         # Reusable Terraform modules
    ├── vpc/         # VPC module
    ├── ec2/         # EC2 module
    └── security/    # Security module
```

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the planned changes:
   ```bash
   terraform plan
   ```

3. Apply the changes:
   ```bash
   terraform apply
   ```

4. To destroy the infrastructure:
   ```bash
   terraform destroy
   ```

## Configuration

Edit `terraform.tfvars` to customize the infrastructure configuration.
