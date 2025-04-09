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

# Create KMS key for CloudWatch logs encryption
resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key for CloudWatch logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-cloudwatch-key"
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
  retention_in_days = 365 # 1 year retention
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc-flow-logs"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
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
}

# Attach policy to allow VPC Flow Logs to write to CloudWatch
resource "aws_iam_role_policy_attachment" "vpc_flow_log_policy" {
  role       = aws_iam_role.vpc_flow_log_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonVPCFlowLogsRole"
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

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

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place in first public subnet

  tags = {
    Name        = "${var.project_name}-nat-gateway"
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

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}

# Associate route tables with subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS region
data "aws_region" "current" {}

# Create SSM VPC endpoints
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

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

  tags = {
    Name        = "${var.project_name}-default-sg"
    Environment = var.environment
    Owner       = "candidate4"
    Project     = "turbot"
  }
}
