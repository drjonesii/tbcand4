# Create KMS key for DynamoDB encryption
resource "aws_kms_key" "dynamodb_encryption" {
  description             = "KMS key for DynamoDB table encryption"
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
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-dynamodb-encryption-key"
    Environment = var.environment
  }
}

# Create KMS key for S3 encryption
resource "aws_kms_key" "s3_encryption" {
  description             = "KMS key for S3 bucket encryption"
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
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-s3-encryption-key"
    Environment = var.environment
  }
}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state"

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Environment = var.environment
  }
}

# Enable versioning for primary bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with customer-managed key for primary bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access for primary bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create S3 bucket for state replication (DR)
resource "aws_s3_bucket" "terraform_state_replica" {
  provider = aws.replica
  bucket   = "${var.project_name}-terraform-state-replica"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-replica"
    Environment = var.environment
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

# Enable server-side encryption with customer-managed key for replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
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

# Enable replication
resource "aws_s3_bucket_replication_configuration" "terraform_state" {
  depends_on = [aws_s3_bucket_versioning.terraform_state]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "replicate_all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.terraform_state_replica.arn
      storage_class = "STANDARD"
    }
  }
}

# Create IAM role for replication
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-s3-bucket-replication"

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
}

# Create IAM policy for replication
resource "aws_iam_role_policy" "replication" {
  name = "${var.project_name}-s3-bucket-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.terraform_state.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.terraform_state_replica.arn}/*"
        ]
      }
    ]
  })
}

# Enable bucket logging
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "terraform-state/"
}

# Enable bucket logging for replica
resource "aws_s3_bucket_logging" "terraform_state_replica" {
  provider      = aws.replica
  bucket        = aws_s3_bucket.terraform_state_replica.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "terraform-state-replica/"
}

# Create DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-state-lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_encryption.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-lock"
    Environment = var.environment
  }
} 