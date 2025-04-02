resource "aws_security_group" "main" {
  name        = "${var.project_name}-sg"
  description = "Security group for ${var.project_name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH access from specified CIDR blocks"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  egress {
    description = "Allow outbound HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    prefix_list_ids = [
      data.aws_prefix_list.s3.id,
      data.aws_prefix_list.dynamodb.id
    ]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Environment = var.environment
  }
}

# Get AWS service prefix lists
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.*.s3"
}

data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.*.dynamodb"
}
