# Create EC2 instance
resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = var.subnet_ids[0]  # Using first subnet

  vpc_security_group_ids = var.security_groups

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              apt-get update
              apt-get upgrade -y

              # Install Steampipe
              /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/turbot/steampipe/main/install.sh)"

              # Install Powerpipe
              /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/turbot/powerpipe/main/install.sh)"

              # Configure Steampipe AWS plugin
              steampipe plugin install aws

              # Install AWS compliance mod
              powerpipe mod install github.com/turbot/powerpipe-mod-aws-compliance

              # Run CIS benchmark and export to CSV
              powerpipe benchmark run aws_compliance.benchmark.cis_v400 --export csv > /tmp/cis_report.csv

              # Install AWS CLI
              apt-get install -y awscli

              # Upload report to S3
              aws s3 cp /tmp/cis_report.csv s3://turbot-candidate3/cis_report.csv
              EOF

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
