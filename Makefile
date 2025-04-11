.PHONY: all terraform security test test-vpc test-ec2 test-s3 clean install-deps venv terraform-fmt terraform-init terraform-validate bootstrap bootstrap-destroy

# Default target
all: install-deps terraform-fmt terraform-init terraform-validate security test

VENV_DIR := .venv
PYTHON := python3
PIP := pip3

# Add environment variable with a default value
ENV ?= test

# Create and activate virtual environment
venv:
	@echo "Creating virtual environment..."
	@test -d $(VENV_DIR) || $(PYTHON) -m venv $(VENV_DIR)
	@. $(VENV_DIR)/bin/activate && $(PIP) install --upgrade pip

# Install dependencies
install-deps: venv
	@echo "Installing dependencies..."
	@. $(VENV_DIR)/bin/activate && \
		$(PIP) install --upgrade pip && \
		$(PIP) install -r requirements.txt && \
		$(PIP) install --upgrade checkov

	@if ! command -v tflint >/dev/null 2>&1; then \
		echo "Installing tflint..."; \
		curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; \
	fi

	@if ! command -v tfsec >/dev/null 2>&1; then \
		echo "Installing tfsec..."; \
		curl -L https://github.com/aquasecurity/tfsec/releases/download/v1.28.1/tfsec-linux-amd64 -o tfsec && \
		chmod +x tfsec && \
		sudo mv tfsec /usr/local/bin/; \
	fi

# Terraform checks
terraform: terraform-fmt terraform-init terraform-validate

terraform-fmt:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive

terraform-init:
	@echo "Initializing Terraform..."
	terraform init -migrate-state -backend-config=backends/backend-$(ENV).tfvars

terraform-validate:
	@echo "Validating Terraform configuration..."
	terraform validate

# Security checks
security:
	@echo "Running security checks..."
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "Virtual environment not found. Run 'make install-deps' first"; \
		exit 1; \
	fi
	@echo "Running Checkov..."
	@. $(VENV_DIR)/bin/activate && checkov --directory . --framework terraform --config-file .checkov.yml
	@echo "Running tfsec..."
	@if ! command -v tfsec >/dev/null 2>&1; then \
		echo "tfsec not found. Run 'make install-deps' first"; \
		exit 1; \
	fi
	tfsec .
	@echo "Running tflint..."
	@if ! command -v tflint >/dev/null 2>&1; then \
		echo "tflint not found. Run 'make install-deps' first"; \
		exit 1; \
	fi
	tflint --init
	tflint --recursive

# Test targets
test: test-vpc test-ec2 test-s3

test-vpc:
	@echo "Running VPC tests..."
	cd test && ENV=test go test -v -run TestVPCModule -timeout 30m

test-ec2:
	@echo "Running EC2 tests..."
	cd test && ENV=test go test -v -run TestEC2Module -timeout 30m

test-s3:
	@echo "Running S3 tests..."
	cd test && ENV=test go test -v -run TestS3Module -timeout 30m

# Clean up
clean:
	@echo "Cleaning up..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	find . -type f -name "*.tfplan" -delete
	find . -type d -name ".terraform" -exec rm -rf {} +
	rm -rf $(VENV_DIR)
	rm -f checkov-report.*
	rm -f tfsec

# Update other terraform commands to ensure they use the right environment
plan:
	terraform plan -var-file=env/$(ENV).tfvars

apply:
	terraform apply -var-file=env/$(ENV).tfvars -auto-approve

# Add bootstrap-destroy target
bootstrap:
	@echo "Creating backend infrastructure..."
	cd bootstrap && terraform init && terraform apply -auto-approve

bootstrap-destroy:
	@echo "Destroying backend infrastructure..."
	cd bootstrap && terraform init && terraform destroy -auto-approve 