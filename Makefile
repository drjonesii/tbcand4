.PHONY: all terraform security test test-vpc test-ec2 test-s3 clean

# Default target
all: terraform security test

# Terraform checks
terraform:
	@echo "Running Terraform checks..."
	terraform fmt -check -recursive
	terraform init
	terraform validate
	terraform plan

# Security checks
security:
	@echo "Running security checks..."
	checkov --directory .
	tfsec .
	tflint

# Test targets
test: test-vpc test-ec2 test-s3

test-vpc:
	@echo "Running VPC tests..."
	cd test && go test -v -timeout 30m -run TestVPCModule

test-ec2:
	@echo "Running EC2 tests..."
	cd test && go test -v -timeout 30m -run TestEC2Module

test-s3:
	@echo "Running S3 tests..."
	cd test && go test -v -timeout 30m -run TestS3Module

# Clean up
clean:
	@echo "Cleaning up..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	find . -type f -name "*.tfplan" -delete
	find . -type d -name ".terraform" -exec rm -rf {} +
	rm -rf .venv
	rm -f checkov-report.* 