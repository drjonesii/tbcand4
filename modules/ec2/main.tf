# Create EC2 instance
resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.instance.id]

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  root_block_device {
    volume_size = var.root_volume_size
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Require IMDSv2
    http_put_response_hop_limit = 2
  }

  monitoring    = true # Enable detailed monitoring
  ebs_optimized = true # Enable EBS optimization

  user_data = <<-EOF
    #!/bin/bash
    # Install SSM agent
    if command -v yum >/dev/null; then
      yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    elif command -v apt-get >/dev/null; then
      snap install amazon-ssm-agent --classic
    fi
    
    # Start SSM agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF

  tags = {
    Name        = "${var.project_name}-instance"
    Environment = var.environment
  }
}

# Create security group
resource "aws_security_group" "instance" {
  name_prefix = "${var.project_name}-instance-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.project_name} EC2 instance in ${var.environment} environment"

  # Allow SSM traffic
  ingress {
    description      = "Allow SSM traffic"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.ssm.id]
  }

  egress {
    description = "Allow outbound access to VPC endpoints and AWS services only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.selected.cidr_block] # Restrict to VPC CIDR
  }

  tags = {
    Name        = "${var.project_name}-instance-sg"
    Environment = var.environment
  }
}

# Get VPC details for CIDR block
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Create IAM role for EC2 instance
resource "aws_iam_role" "instance_role" {
  name = "${var.project_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.instance_role.name
}

# Attach policy to allow CloudWatch Logs
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Attach policy to allow SSM
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create IAM policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Policy to allow EC2 instance to write CIS reports to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.cis_report_bucket}",
          "arn:aws:s3:::${var.cis_report_bucket}/*"
        ]
      }
    ]
  })
}

# Attach S3 access policy to EC2 role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Create KMS key for CloudWatch logs encryption
resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key for CloudWatch logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudwatch-key"
    Environment = var.environment
  }
}

# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "instance_logs" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}/instance-logs"
  retention_in_days = 365 # 1 year retention
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-instance-logs"
    Environment = var.environment
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get SSM prefix list
data "aws_ec2_managed_prefix_list" "ssm" {
  name = "com.amazonaws.${data.aws_region.current.name}.ssm"
}
