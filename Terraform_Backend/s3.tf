resource "aws_s3_bucket" "in_bucket_gmezgs" {
  bucket = "in-bucket-gmezgs"

  tags = {
    Name        = "Unprocessed"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "out_bucket_gmezgs" {
  bucket = "out-bucket-gmezgs"

  tags = {
    Name        = "Processed"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = aws_s3_bucket.in_bucket_gmezgs.id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "console" {
  name        = "s3-upload-trigger"
  description = "Trigger for S3 uploads"

  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "detail" : {
      "bucket" : {
        "name" : [aws_s3_bucket.in_bucket_gmezgs.id]
      }
    }
  })
}

resource "aws_s3_bucket_public_access_block" "public_out_bucket" {
  bucket = aws_s3_bucket.out_bucket_gmezgs.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "out_bucket_policy" {
  bucket = aws_s3_bucket.out_bucket_gmezgs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.out_bucket_gmezgs.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.public_out_bucket]
}

resource "aws_s3_bucket_cors_configuration" "in_bucket_cors" {
  bucket = aws_s3_bucket.in_bucket_gmezgs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_cors_configuration" "out_bucket_cors" {
  bucket = aws_s3_bucket.out_bucket_gmezgs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}