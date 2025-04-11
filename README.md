# Turbot Assignment

## Infrastructure Costs

### Current Monthly Costs
[![Staging Cost](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/yourusername/tbcand4/main/.infracost/staging.json&query=totalMonthlyCost&prefix=$&label=Staging%20Cost)](https://github.com/yourusername/tbcand4/actions)
[![Production Cost](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/yourusername/tbcand4/main/.infracost/prod.json&query=totalMonthlyCost&prefix=$&label=Production%20Cost)](https://github.com/yourusername/tbcand4/actions)

### Cost Breakdown
[![Staging Resources](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/yourusername/tbcand4/main/.infracost/staging.json&query=resourceCount&label=Staging%20Resources)](https://github.com/yourusername/tbcand4/actions)
[![Production Resources](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/yourusername/tbcand4/main/.infracost/prod.json&query=resourceCount&label=Production%20Resources)](https://github.com/yourusername/tbcand4/actions)

### Cost Trends
![Staging Cost Trend](https://raw.githubusercontent.com/yourusername/tbcand4/main/.infracost/staging-trend.svg)
![Production Cost Trend](https://raw.githubusercontent.com/yourusername/tbcand4/main/.infracost/prod-trend.svg)

<details>
<summary>📊 Detailed Cost Information</summary>

#### Staging Environment
- **Monthly Cost**: $XX.XX
- **Hourly Cost**: $X.XX
- **Most Expensive Resources**:
  1. NAT Gateway: $XX.XX/month
  2. EC2 Instance: $XX.XX/month
  3. EBS Volumes: $XX.XX/month

#### Production Environment
- **Monthly Cost**: $XX.XX
- **Hourly Cost**: $X.XX
- **Most Expensive Resources**:
  1. NAT Gateway: $XX.XX/month
  2. EC2 Instance: $XX.XX/month
  3. EBS Volumes: $XX.XX/month

- View cost trends and resource breakdowns in the [.infracost](.infracost) directory
- Cost optimization recommendations are provided in the CI/CD pipeline

</details>

## Overview

This repository contains Terraform code for deploying secure AWS infrastructure. See [architecture.md](architecture.md) for detailed infrastructure design.

## Prerequisites

- Terraform >= 1.7.0
- AWS CLI configured
- Python 3.11 or later
- Go 1.21 or later

## Security Features

### Data Protection
- S3 bucket encryption with KMS
- State management with encryption
- Cross-region replication
- Access logging and audit trails

### Network Security
- VPC Flow Logs
- Private subnets
- Restricted security groups
- NAT Gateway for outbound access

### Instance Security
- IMDSv2 required
- Encrypted volumes
- Detailed monitoring
- Least privilege IAM roles

## Local Development

1. Clone and setup:
   ```bash
   git clone https://github.com/drjonesii/tbcand4.git
   cd tbcand4
   ```

2. Create Python virtual environment:
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. Deploy infrastructure:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Testing

Run all checks:
```bash
make all
```

Individual checks:
```bash
make terraform   # Format, validate, etc
make security    # Checkov, tfsec, tflint
make test       # Run Go tests
```

## Project Structure

```
tbcand4/
├── main.tf           # Main configuration
├── modules/         # Terraform modules
│   ├── vpc/        # VPC configuration
│   └── ec2/        # EC2 configuration
├── test/           # Go tests
└── .github/        # GitHub Actions
```

## GitHub Workflows

### Overview
The repository uses GitHub Actions for automated testing, security scanning, and infrastructure validation.

### Main Workflows

#### 1. CI Workflow (`ci.yml`)
Runs on pull requests and pushes to main branch.

**Job: Terraform**
- Sets up Terraform and Go
- Runs:
  - `terraform fmt -check -recursive`
  - `terraform init`
  - `terraform validate`
  - `terraform plan`
- Executes Go tests

**Job: Security**
- Sets up Python environment
- Runs security tools:
  - Checkov
  - tfsec
  - tflint
- Uploads scan reports as artifacts

#### 2. Cost Analysis (`cost.yml`)
- Generates infrastructure cost estimates
- Updates cost badges in README
- Creates cost breakdown reports

#### 3. Destroy Protection (`destroy.yml`)
- Requires approval for infrastructure destruction
- Validates source IP against ALLOWED_IPS
- Creates state backups before destruction

### IAM Roles

The workflows require three IAM roles:

1. `github-actions-ci`
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${REPO_NAME}:*"
                }
            }
        }
    ]
}
```

2. `github-actions-test`
- Full access to create/destroy test resources
- State management access

3. `github-actions-destroy`
- Restricted to approved destroy operations
- State backup access

### Required Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCOUNT_ID` | AWS Account ID |
| `BACKUP_BUCKET` | S3 bucket for state backups |
| `ALLOWED_IPS` | IPs allowed to destroy infrastructure |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_REGION` | AWS region | us-west-1 |
| `TF_VAR_environment` | Environment (dev/staging/prod) | - |

### Workflow Artifacts

- Security scan reports
- Cost analysis reports
- Test results
- Terraform plans

### Viewing Results

1. Go to the "Actions" tab
2. Select the workflow
3. Choose the latest run
4. View job outputs and artifacts

## CI/CD Pipeline

The repository includes GitHub Actions workflows for:
- Infrastructure validation
- Security scanning
- Cost estimation
- Automated testing

Required GitHub secrets:
- `AWS_ACCOUNT_ID`
- `BACKUP_BUCKET`
- `ALLOWED_IPS`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Submit a pull request

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
   - `AWS_ACCOUNT_ID`: Your AWS account ID
   - `BACKUP_BUCKET`: S3 bucket name for state backups
   - `ALLOWED_IPS`: Allowed IP addresses for infrastructure destruction

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

The following environment variables are used by the workflows:
- `AWS_REGION`: The AWS region to deploy to (defaults to us-west-1)
- `TF_VAR_environment`: The environment to deploy to (dev, staging, prod)

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

### Required GitHub Secrets

- `AWS_ACCOUNT_ID`: Your AWS account ID
- `BACKUP_BUCKET`: S3 bucket name for state backups
- `ALLOWED_IPS`: Allowed IP addresses for infrastructure destruction

Note: AWS access keys are no longer needed as secrets since we use OIDC authentication.

### Environment Setup
1. Configure AWS credentials:
   ```bash
   # No longer needed:
   # export AWS_ACCESS_KEY_ID=your_access_key
   # export AWS_SECRET_ACCESS_KEY=your_secret_key
   
   export AWS_REGION=your_preferred_region  # Optional, defaults to us-west-1
   ```

### Environment Variables

The following environment variables are used by the workflows:
- `AWS_REGION`: The AWS region to deploy to (defaults to us-west-1)
- `TF_VAR_environment`: The environment to deploy to (dev, staging, prod)
