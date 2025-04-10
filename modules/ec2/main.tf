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

  # Enable auto recovery
  maintenance_options {
    auto_recovery = "default"
  }

  # Add instance health check
  credit_specification {
    cpu_credits = "standard"
  }

  # Add instance recovery alarm
  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
    #!/bin/bash
    # Install SSM agent
    if command -v yum >/dev/null; then
      yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
      yum install -y amazon-cloudwatch-agent
    elif command -v apt-get >/dev/null; then
      snap install amazon-ssm-agent --classic
      apt-get update && apt-get install -y amazon-cloudwatch-agent
    fi
    
    # Configure CloudWatch agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOL'
    {
      "metrics": {
        "metrics_collected": {
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          },
          "swap": {
            "measurement": ["swap_used_percent"],
            "metrics_collection_interval": 60
          },
          "disk": {
            "measurement": ["used_percent"],
            "resources": ["/"],
            "metrics_collection_interval": 60
          }
        }
      }
    }
    EOL

    # Start agents
    systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
    systemctl enable amazon-cloudwatch-agent && systemctl start amazon-cloudwatch-agent
  EOF

  tags = {
    Name        = "${var.project_name}-instance"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create security group
resource "aws_security_group" "instance" {
  name_prefix = "${var.project_name}-instance-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.project_name} EC2 instance in ${var.environment} environment"

  # Allow HTTPS traffic for SSM
  ingress {
    description = "Allow HTTPS for SSM"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  # Replace existing egress rule with specific ports
  egress {
    description = "Allow HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow high ports outbound"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Keep VPC endpoint access
  egress {
    description = "Allow access to VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  tags = {
    Name        = "${var.project_name}-instance-sg"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
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

  tags = {
    Name        = "${var.project_name}-instance-role"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
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

  tags = {
    Name        = "${var.project_name}-s3-access-policy"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
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
    Owner       = "candidate4"
    Project     = "turbot"
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
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Create KMS policy for EC2 instance
resource "aws_iam_role_policy" "kms_policy" {
  name = "${var.project_name}-kms-policy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = [
          var.cloudwatch_kms_key_arn,  # For CloudWatch logs
          var.s3_kms_key_arn,          # For S3 access
          var.dynamodb_kms_key_arn     # For DynamoDB access
        ]
      }
    ]
  })
}

# Replace CloudWatch Logs full access with specific permissions
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}-cloudwatch-logs-policy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.instance_logs.arn}:*",
          aws_cloudwatch_log_group.instance_logs.arn
        ]
      }
    ]
  })
}

# Add CloudWatch alarm for instance recovery
resource "aws_cloudwatch_metric_alarm" "instance_recovery" {
  alarm_name          = "${var.project_name}-instance-recovery"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic          = "Minimum"
  threshold          = "0"
  alarm_description  = "Recover EC2 instance when system status check fails"
  alarm_actions      = ["arn:aws:automate:${data.aws_region.current.name}:ec2:recover"]

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  tags = {
    Name        = "${var.project_name}-instance-recovery-alarm"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Add CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "${var.project_name}-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "CPU utilization is too high"
  alarm_actions      = [var.sns_topic_arn]

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  tags = {
    Name        = "${var.project_name}-cpu-utilization-alarm"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Add memory utilization monitoring
resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  alarm_name          = "${var.project_name}-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace          = "CWAgent"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "Memory utilization is too high"
  alarm_actions      = [var.sns_topic_arn]

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  tags = {
    Name        = "${var.project_name}-memory-utilization-alarm"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}
