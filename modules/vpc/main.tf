# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Enable VPC Flow Logs
resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# Create CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}/flow-logs"
  retention_in_days = 365
  kms_key_id        = "alias/aws/logs" # Use AWS managed key
}

# Create a specific log stream for VPC flow logs
resource "aws_cloudwatch_log_stream" "vpc_flow_log_stream" {
  name           = "${var.project_name}-${var.environment}-flow-logs"
  log_group_name = aws_cloudwatch_log_group.vpc_flow_log.name
}

# Create IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "${var.project_name}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "vpc-flow-log-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "${aws_cloudwatch_log_group.vpc_flow_log.arn}:*"
        }
      ]
    })
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create NAT Gateways in each public subnet for high availability
resource "aws_nat_gateway" "main" {
  count = 2 # Create a NAT Gateway in each public subnet

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.project_name}-nat-gateway-${count.index + 1}"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }

  depends_on = [aws_internet_gateway.main]
}

# Create S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = {
    Name        = "${var.project_name}-s3-endpoint"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create NAT Gateway route tables with failover
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-private-rt-${count.index + 1}"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create routes separately to avoid conflicts
resource "aws_route" "private_nat" {
  count                  = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Update private subnet route table associations
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Create SSM VPC endpoints
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  # Enable cross-zone connectivity
  tags = {
    Name        = "${var.project_name}-ssm-endpoint"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ssmmessages-endpoint"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ec2messages-endpoint"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-vpc-endpoints-sg"
  vpc_id      = aws_vpc.main.id
  description = "Security group for VPC endpoints"

  ingress {
    description = "Allow HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name        = "${var.project_name}-vpc-endpoints-sg"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Add after the VPC resource
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # Explicitly deny all traffic
  ingress = []
  egress  = []

  tags = {
    Name        = "${var.project_name}-default-sg"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create KMS key for SNS encryption
resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS topic encryption"
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
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-sns-key"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create KMS alias for easier reference
resource "aws_kms_alias" "sns" {
  name          = "alias/${var.project_name}-sns-key"
  target_key_id = aws_kms_key.sns.key_id
}

# Update SNS topic to use CMK
resource "aws_sns_topic" "infrastructure_alerts" {
  name              = "${var.project_name}-infrastructure-alerts"
  kms_master_key_id = aws_kms_key.sns.id # Use our CMK instead of AWS managed key

  tags = {
    Name        = "${var.project_name}-infrastructure-alerts"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Update NAT Gateway alarms to notify SNS
resource "aws_cloudwatch_metric_alarm" "nat_gateway" {
  count               = 2
  alarm_name          = "${var.project_name}-nat-gateway-${count.index + 1}-health"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorPortAllocation"
  namespace           = "AWS/NATGateway"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "NAT Gateway port allocation errors"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    NatGatewayId = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-nat-gateway-${count.index + 1}-alarm"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Update VPC endpoint alarms to notify SNS
resource "aws_cloudwatch_metric_alarm" "vpc_endpoint" {
  alarm_name          = "${var.project_name}-vpc-endpoint-ssm-health"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EndpointConnectionError"
  namespace           = "AWS/PrivateLink"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "VPC endpoint connection errors"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    EndpointId = aws_vpc_endpoint.ssm.id
  }

  tags = {
    Name        = "${var.project_name}-vpc-endpoint-ssm-alarm"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Fix the VPC endpoint latency monitoring
resource "aws_cloudwatch_metric_alarm" "vpc_endpoint_latency" {
  alarm_name          = "${var.project_name}-vpc-endpoint-ssm-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "ConnectionAttemptDelay"
  namespace           = "AWS/PrivateLink"
  period              = "300"
  statistic           = "Average"
  threshold           = "1" # 1 second
  alarm_description   = "VPC endpoint is experiencing high latency"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    EndpointId = aws_vpc_endpoint.ssm.id
  }

  tags = {
    Name        = "${var.project_name}-vpc-endpoint-ssm-latency-alarm"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Add NAT Gateway bandwidth monitoring
resource "aws_cloudwatch_metric_alarm" "nat_gateway_bandwidth" {
  count               = 2
  alarm_name          = "${var.project_name}-nat-gateway-${count.index + 1}-bandwidth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "BytesOutToDestination"
  namespace           = "AWS/NATGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000000000" # 5GB
  alarm_description   = "NAT Gateway is experiencing high bandwidth usage"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    NatGatewayId = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-nat-gateway-${count.index + 1}-bandwidth-alarm"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create IAM policy for VPC operations
resource "aws_iam_policy" "vpc_operations" {
  name = "${var.project_name}-vpc-operations"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/vpc/${var.project_name}-${var.environment}/*",
          "arn:aws:logs:*:*:log-group:/aws/vpc/${var.project_name}-${var.environment}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:SetTopicAttributes",
          "sns:GetTopicAttributes",
          "sns:Publish"
        ]
        Resource = [
          "arn:aws:sns:*:*:${var.project_name}-*"
        ]
      }
    ]
  })
}

# Attach policy to the VPC flow log role
resource "aws_iam_role_policy_attachment" "vpc_operations" {
  role       = aws_iam_role.vpc_flow_log_role.name
  policy_arn = aws_iam_policy.vpc_operations.arn
}
