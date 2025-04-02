# Turbot Assignment

This repository contains Terraform code for deploying AWS infrastructure with a focus on security and best practices.

## Architecture

See [architecture.md](architecture.md) for a detailed diagram and description of the infrastructure.

## Prerequisites

- Terraform >= 1.7.0
- AWS CLI configured with appropriate credentials
- GitHub account for CI/CD integration

## Security Features

### S3 Bucket Protection
- Server-side encryption using customer-managed KMS keys
- Versioning enabled for data protection and recovery
- Public access blocks to prevent unauthorized access
- Access logging enabled for audit trails
- Cross-region replication for disaster recovery
- Separate buckets for state, CIS reports, and access logs

### State Management
- Remote state stored in S3 with encryption
- State locking using DynamoDB with encryption
- Separate KMS keys for S3 and DynamoDB encryption
- Point-in-time recovery enabled for DynamoDB

### Network Security
- VPC Flow Logs enabled with CloudWatch integration
- CloudWatch logs encrypted with customer-managed KMS key
- Private subnets for EC2 instances
- NAT Gateway for outbound internet access
- No automatic public IP assignment
- Restricted security group access:
  - SSH access limited to specified CIDR blocks only
  - No public internet access (0.0.0.0/0) allowed
  - Egress traffic restricted to VPC CIDR
  - All security group rules have descriptive names

### Instance Security
- IMDSv2 required with limited hop count
- Detailed monitoring enabled
- EBS optimization enabled
- Root volume encryption
- Security group with least privilege access
- Input validation for all variables:
  - Environment must be one of: dev, staging, prod
  - Project name must contain only lowercase letters, numbers, and hyphens
  - Instance type must be a valid AWS EC2 instance type
  - AMI ID must be a valid AWS AMI ID
  - Subnet ID must be a valid AWS subnet ID
  - VPC ID must be a valid AWS VPC ID
  - Root volume size must be between 8 and 16384 GB
  - SSH CIDR blocks must be valid and not include 0.0.0.0/0

### Monitoring and Audit
- CloudWatch Logs with 1-year retention
- KMS encryption for all logs
- Detailed instance monitoring
- VPC Flow Logs for network traffic analysis
- Security group rule descriptions for audit trail

### Access Control
- IAM roles with least privilege
- KMS key rotation enabled
- Resource tagging for cost and security tracking
- Regular security scanning with tfsec

## Testing

### Local Testing
1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Run tests:
   ```bash
   cd test
   go test -v ./...
   ```

### GitHub Actions CI/CD

The repository includes GitHub Actions workflows for:

1. Terraform Validation:
   - Format checking
   - Configuration validation
   - Security scanning with tfsec
   - Linting with tflint

2. Infrastructure Testing:
   - Automated Go tests
   - Infrastructure validation
   - Security compliance checks

## Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/drjonesii/tbcand4.git
   cd tbcand4
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the plan:
   ```bash
   terraform plan
   ```

4. Apply the changes:
   ```bash
   terraform apply
   ```

## Security Best Practices

1. KMS Key Management:
   - Separate keys for different services (S3, DynamoDB, CloudWatch)
   - Automatic key rotation enabled
   - Custom key policies for access control

2. Data Protection:
   - All data encrypted at rest
   - Versioning enabled for recovery
   - Cross-region replication for DR
   - Access logging for audit trails

3. Access Control:
   - Public access blocked by default
   - IAM roles with minimal permissions
   - Resource policies for additional control
   - IMDSv2 required for EC2 instances

4. Monitoring and Audit:
   - VPC Flow Logs with 1-year retention
   - S3 access logging enabled
   - DynamoDB point-in-time recovery
   - EC2 detailed monitoring
   - Resource tagging for tracking

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests locally
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

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

### EC2 Module

The EC2 module creates a secure EC2 instance with the following features:

- Encrypted root volume
- IMDSv2 required
- Detailed monitoring enabled
- EBS optimization
- Restricted security group access
- CloudWatch logging with KMS encryption

Required variables:
```hcl
module "ec2" {
  source = "./modules/ec2"

  project_name = "my-project"
  environment  = "prod"
  ami_id       = "ami-0c7217cdde317cfec"  # Amazon Linux 2023 AMI
  subnet_id    = module.vpc.private_subnet_ids[0]
  vpc_id       = module.vpc.vpc_id
  allowed_ssh_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]  # Example: Allow access from private IP ranges only
}
```

Note: The `allowed_ssh_cidr_blocks` variable must:
- Not be empty
- Not contain `0.0.0.0/0` (no public access allowed)
- Contain valid CIDR blocks in the format `x.x.x.x/y`

## Security Scanning with Checkov

This project uses [Checkov](https://www.checkov.io/) for static code analysis of Terraform configurations to identify security and compliance issues.

### Running Checkov Locally

1. Make sure you have the Python environment set up:
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. Run Checkov using the provided script:
   ```bash
   ./scripts/run_checkov.py
   ```

3. For more options:
   ```bash
   ./scripts/run_checkov.py --help
   ```

### Checkov Configuration

The project includes a `.checkov` configuration file that:
- Skips specific checks that might be too strict for your environment
- Configures which frameworks to scan
- Sets the output format
- Specifies which paths to include or exclude

### GitHub Actions Integration

Checkov runs automatically as part of the CI/CD pipeline:
- On every push to the main branch
- On pull requests to the main branch
- Daily at midnight

The scan results are uploaded as artifacts and can be viewed in the GitHub Actions logs.
