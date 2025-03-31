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
├── backend.tf       # S3 backend configuration
├── state.tf         # State management resources
├── cis_report.tf    # CIS report bucket configuration
├── architecture.md  # Infrastructure architecture diagram
└── modules/         # Reusable Terraform modules
    ├── vpc/         # VPC module
    ├── ec2/         # EC2 module
    └── security/    # Security module
```

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions
- Go >= 1.20 (for running tests)

## Local Development

1. Configure AWS credentials:
   ```bash
   aws configure --profile turbot
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the planned changes:
   ```bash
   terraform plan
   ```

4. Apply the changes:
   ```bash
   terraform apply
   ```

5. To destroy the infrastructure:
   ```bash
   terraform destroy
   ```

## Testing

### Running Tests Locally

1. Navigate to the test directory:
   ```bash
   cd test
   ```

2. Install dependencies:
   ```bash
   go mod tidy
   ```

3. Run the tests:
   ```bash
   go test -v
   ```

The test suite includes:
- VPC module tests
- Security group tests
- EC2 instance tests
- S3 bucket tests

### Test Coverage

The tests verify:
- VPC creation and configuration
- Subnet creation in different AZs
- Security group rules
- EC2 instance deployment
- S3 bucket creation and configuration

## GitHub Actions

This project includes two GitHub Actions workflows:

### 1. Terraform CI (`terraform.yml`)

Runs on:
- Push to main branch
- Pull requests to main branch

Steps:
1. Configure AWS credentials
2. Setup Go environment
3. Install Terratest
4. Run Terraform operations:
   - Format check
   - Init
   - Validate
   - Plan
5. Run Go tests
6. Apply changes (only on main branch)
7. Show outputs

### 2. Security Scan (`security.yml`)

Runs on:
- Push to main branch
- Pull requests to main branch

Security checks:
- tfsec (Terraform security scanner)
- tflint (Terraform linter)
- checkov (Infrastructure as Code scanner)

### Setting up GitHub Actions

1. Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. The workflows will automatically run on:
   - Push to main branch
   - Pull requests to main branch

## Configuration

Edit `terraform.tfvars` to customize the infrastructure configuration.

## Infrastructure Components

See [architecture.md](architecture.md) for a detailed diagram of resource dependencies.

1. VPC:
   - Deletes default VPC
   - Creates new VPC
   - Creates 2 public subnets in different AZs
   - Creates and attaches Internet Gateway
   - Sets up routing for internet access

2. Security:
   - Creates security group
   - Allows SSH access (port 22)
   - Allows all outbound traffic

3. EC2:
   - Creates t3.micro instance
   - Uses Ubuntu 22.04 LTS
   - Installs Steampipe and Powerpipe
   - Configures AWS plugin
   - Runs CIS v4 benchmark
   - Exports report to CSV
   - Uploads report to S3

4. S3:
   - Creates state bucket for Terraform state
   - Creates bucket for CIS reports
   - Enables versioning
   - Configures encryption
   - Blocks public access
