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
  - Instance type must be t3.micro (only t3.micro is allowed)
  - AMI ID must be a valid AWS AMI ID
  - Subnet ID must be a valid AWS private subnet ID
  - VPC ID must be a valid AWS VPC ID
  - Root volume size must be between 8 and 16384 GB

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

#### Prerequisites
- Go 1.21 or later
- Terraform >= 1.7.0
- AWS CLI configured with appropriate credentials
- Python 3.x (for security tools)

#### Environment Setup
1. Set AWS credentials:
   ```bash
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_REGION=your_preferred_region  # Optional, defaults to us-west-1
   ```

2. Install Go dependencies:
   ```bash
   cd test
   go mod download
   ```

#### Running Tests

The project includes a Makefile with various targets for running tests and checks:

1. Run all checks (Terraform, security, and tests):
   ```bash
   make all
   ```

2. Run specific test suites:
   ```bash
   make test-vpc    # Run only VPC tests
   make test-ec2    # Run only EC2 tests
   make test-s3     # Run only S3 tests
   make test        # Run all tests
   ```

3. Run individual checks:
   ```bash
   make terraform   # Run Terraform checks (fmt, init, validate, plan)
   make security    # Run security checks (checkov, tfsec, tflint)
   ```

4. Clean up:
   ```bash
   make clean       # Remove all generated files and directories
   ```

#### Test Details

- **VPC Tests**: Tests VPC creation, subnet configuration, and CIDR block validation
- **EC2 Tests**: Tests EC2 instance creation, networking, and security group configuration
- **S3 Tests**: Tests S3 bucket creation and configuration

Each test suite:
- Creates real AWS resources
- Validates the infrastructure
- Cleans up resources after completion
- Has a 30-minute timeout to account for AWS resource provisioning

### GitHub Actions CI/CD

The repository includes a consolidated CI workflow (`.github/workflows/ci.yml`) that runs on pull requests to the `main` branch. The workflow includes two parallel jobs:

#### 1. Terraform Job
- Checks out the repository
- Sets up Terraform and Go
- Installs Go dependencies
- Runs Terraform commands:
  - `terraform fmt -check -recursive`
  - `terraform init`
  - `terraform validate`
  - `terraform plan`
- Runs Go tests

#### 2. Security Job
- Checks out the repository
- Sets up Python
- Installs security tools:
  - Checkov
  - tfsec
  - tflint
- Runs security checks:
  - Checkov scan
  - tfsec scan
  - tflint scan
- Uploads Checkov report as an artifact

#### Workflow Triggers
- Runs on pull requests to `main` branch
- Runs on push to `main` branch
- Can be manually triggered from the Actions tab

#### Artifacts
- Checkov report is uploaded as an artifact
- Can be downloaded from the GitHub Actions UI

#### Viewing Results
1. Go to the "Actions" tab in your GitHub repository
2. Select the "CI" workflow
3. Click on the latest run
4. View the results of each job and step

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
   - Allows outbound traffic to AWS services only

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
- Deployed only in private subnets
- Only t3.micro instance type allowed

Required variables:
```hcl
module "ec2" {
  source = "./modules/ec2"

  project_name  = var.project_name
  environment   = var.environment
  ami_id        = "ami-0c55b159cbfafe1f0" # Example AMI ID
  instance_type = "t3.micro"
  subnet_id     = module.vpc.private_subnet_ids[0]
  vpc_id        = module.vpc.vpc_id
}
```

### Security Group Configuration
- No public internet access allowed
- Egress traffic restricted to VPC CIDR
- All security group rules have descriptive names

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

## Running CI Checks Locally

You can run the same checks that run in GitHub Actions locally using the provided Makefile.

### Prerequisites

- Make
- Terraform
- Go
- Python 3.11 or later

### Running Checks

1. Run all checks (Terraform and Security):
   ```bash
   make all
   ```

2. Run only Terraform checks:
   ```bash
   make terraform
   ```

3. Run only security checks:
   ```bash
   make security
   ```

4. Run individual checks:
   ```bash
   # Terraform formatting
   make terraform-fmt

   # Terraform validation
   make terraform-validate

   # Go tests
   make test-go

   # Checkov
   make checkov

   # tfsec
   make tfsec

   # tflint
   make tflint
   ```

5. Clean up generated files:
   ```bash
   make clean
   ```

### Environment Variables

Some checks require AWS credentials. Set these environment variables before running the checks:

```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=your_region
```

### Required IAM Roles

The project requires three IAM roles for different GitHub Actions workflows:

1. `github-actions-ci` - For CI workflow
   - Permissions needed:
     - Read access to ECR
     - Read/Write access to S3 for Terraform state
     - Read/Write access to DynamoDB for state locking
     - Access to run security scans

2. `github-actions-test` - For test workflow
   - Permissions needed:
     - Full access to create/destroy test resources
     - Read/Write access to S3 for Terraform state
     - Read/Write access to DynamoDB for state locking

3. `github-actions-destroy` - For destroy workflow
   - Permissions needed:
     - Full access to destroy infrastructure
     - Read/Write access to S3 for state backups
     - Read/Write access to DynamoDB for state locking

Example IAM role trust policy for all roles:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:<GITHUB_ORG>/<REPO_NAME>:*"
                }
            }
        }
    ]
}
```

Each role should have appropriate IAM policies attached based on the least privilege principle.
