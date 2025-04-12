# Create S3 bucket for terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "tbcand4-terraform-state"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "tbcand4-terraform-state"
    Environment = "bootstrap"
  }
}

variable "project_name" {
    type = string
    description = "candidate4-prod"
}

# Enable versioning for state bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

# Block public access for state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create replica bucket
resource "aws_s3_bucket" "terraform_state_replica" {
  provider = aws.replica
  bucket   = "tbcand4-terraform-state-replica"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "tbcand4-terraform-state-replica"
    Environment = "bootstrap"
  }
}

# Enable versioning for replica bucket
resource "aws_s3_bucket_versioning" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

# Block public access for replica bucket
resource "aws_s3_bucket_public_access_block" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create access logs bucket for primary region
resource "aws_s3_bucket" "access_logs_primary" {
  bucket = "tbcand4-terraform-state-access-logs-primary"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "tbcand4-terraform-state-access-logs-primary"
    Environment = "bootstrap"
  }
}

# Enable versioning for primary access logs bucket
resource "aws_s3_bucket_versioning" "access_logs_primary" {
  bucket = aws_s3_bucket.access_logs_primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for primary access logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_primary" {
  bucket = aws_s3_bucket.access_logs_primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

# Block public access for primary access logs bucket
resource "aws_s3_bucket_public_access_block" "access_logs_primary" {
  bucket = aws_s3_bucket.access_logs_primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create access logs bucket for replica region
resource "aws_s3_bucket" "access_logs_replica" {
  provider = aws.replica
  bucket   = "tbcand4-terraform-state-access-logs-replica"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "tbcand4-terraform-state-access-logs-replica"
    Environment = "bootstrap"
  }
}

# Enable versioning for replica access logs bucket
resource "aws_s3_bucket_versioning" "access_logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.access_logs_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for replica access logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.access_logs_replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

# Add public access block for replica access logs bucket
resource "aws_s3_bucket_public_access_block" "access_logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.access_logs_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Update logging configuration for primary state bucket
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.access_logs_primary.id
  target_prefix = "terraform-state/"
}

# Update logging configuration for replica state bucket
resource "aws_s3_bucket_logging" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id

  target_bucket = aws_s3_bucket.access_logs_replica.id
  target_prefix = "terraform-state-replica/"
}

# Add replication configuration for primary state bucket
resource "aws_s3_bucket_replication_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "state_replication"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.terraform_state_replica.arn
    }
  }
}

# Add replication configuration for primary access logs bucket
resource "aws_s3_bucket_replication_configuration" "access_logs_primary" {
  bucket = aws_s3_bucket.access_logs_primary.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "logs_replication"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.access_logs_replica.arn
    }
  }
}

# Create IAM role for replication
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "s3-replication"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetReplicationConfiguration",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.terraform_state.arn
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObjectVersionForReplication",
            "s3:GetObjectVersionAcl",
            "s3:GetObjectVersionTagging"
          ]
          Resource = [
            "${aws_s3_bucket.terraform_state.arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ReplicateObject",
            "s3:ReplicateDelete",
            "s3:ReplicateTags"
          ]
          Resource = [
            "${aws_s3_bucket.terraform_state_replica.arn}/*"
          ]
        }
      ]
    })
  }
}