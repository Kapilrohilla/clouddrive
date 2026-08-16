resource "aws_s3_bucket" "cloud-drive-bucket" {
  bucket        = "cloud-drive-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    CreatedBy   = "Terraform"
    Environment = "Development"
    Project     = "CloudDrive"
  }
}

resource "aws_s3_bucket_versioning" "cloud-drive-bucket-versioning" {
  bucket = aws_s3_bucket.cloud-drive-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cloud-drive-bucket-public-access-block" {
  bucket = aws_s3_bucket.cloud-drive-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
