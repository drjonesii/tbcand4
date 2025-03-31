# Create S3 bucket for CIS report
resource "aws_s3_bucket" "cis_report" {
  bucket = "turbot-candidate3"

  tags = {
    Name        = "${var.project_name}-cis-report"
    Environment = var.environment
  }
}

# Enable versioning for CIS report bucket
resource "aws_s3_bucket_versioning" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "cis_report" {
  bucket = aws_s3_bucket.cis_report.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Outputs
output "cis_report_bucket_name" {
  description = "The name of the S3 bucket used for storing CIS reports"
  value       = aws_s3_bucket.cis_report.id
} 