.PHONY: all terraform security test test-vpc test-ec2 test-s3 clean install-deps venv

# Default target
all: install-deps terraform security test

VENV_DIR := .venv
PYTHON := python3
PIP := pip3

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
terraform:
	@echo "Running Terraform checks..."
	terraform fmt -check -recursive
	terraform init
	terraform validate
	terraform plan

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
	rm -rf $(VENV_DIR)
	rm -f checkov-report.*
	rm -f tfsec 