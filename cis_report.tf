# Create S3 bucket for CIS reports
resource "aws_s3_bucket" "cis_report" {
  bucket = "${var.project_name}-cis-report"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cis-report"
    Environment = var.environment
  }
}

# Enable versioning for primary bucket
resource "aws_s3_bucket_versioning" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with customer-managed key
resource "aws_s3_bucket_server_side_encryption_configuration" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create replica bucket for CIS reports
resource "aws_s3_bucket" "cis_report_replica" {
  provider = aws.replica
  bucket   = "${var.project_name}-cis-report-replica"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cis-report-replica"
    Environment = var.environment
  }
}

# Enable versioning for replica bucket
resource "aws_s3_bucket_versioning" "cis_report_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.cis_report_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with customer-managed key for replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "cis_report_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.cis_report_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access for replica bucket
resource "aws_s3_bucket_public_access_block" "cis_report_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.cis_report_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure replication
resource "aws_s3_bucket_replication_configuration" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id

  role = aws_iam_role.replication.arn

  rule {
    id     = "cis_report_replication"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.cis_report_replica.arn
    }
  }
}

# Enable logging for primary bucket
resource "aws_s3_bucket_logging" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cis-report/"
}

# Enable logging for replica bucket
resource "aws_s3_bucket_logging" "cis_report_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.cis_report_replica.id

  target_bucket = aws_s3_bucket.access_logs_replica.id
  target_prefix = "cis-report-replica/"
}

# Create S3 bucket for access logs
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-access-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-access-logs"
    Environment = var.environment
  }
}

# Enable versioning for access logs bucket
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with customer-managed key for access logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access for access logs bucket
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create replica bucket for access logs
resource "aws_s3_bucket" "access_logs_replica" {
  provider = aws.replica
  bucket   = "${var.project_name}-access-logs-replica"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-access-logs-replica"
    Environment = var.environment
  }
}

# Enable versioning for access logs replica bucket
resource "aws_s3_bucket_versioning" "access_logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.access_logs_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with customer-managed key for access logs replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.access_logs_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access for access logs replica bucket
resource "aws_s3_bucket_public_access_block" "access_logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.access_logs_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure replication for access logs
resource "aws_s3_bucket_replication_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  role = aws_iam_role.replication.arn

  rule {
    id     = "access_logs_replication"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.access_logs_replica.arn
    }
  }
}

# Enable logging for access logs bucket
resource "aws_s3_bucket_logging" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "access-logs/"
}

# Enable logging for access logs replica bucket
resource "aws_s3_bucket_logging" "access_logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.access_logs_replica.id

  target_bucket = aws_s3_bucket.access_logs_replica.id
  target_prefix = "access-logs-replica/"
} 