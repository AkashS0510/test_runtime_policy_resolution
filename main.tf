terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. CloudWatch Log Group - FAIL (retention_in_days omitted => null)
resource "aws_cloudwatch_log_group" "bad_logs" {
  name = "bad-log-group"
  # retention_in_days intentionally omitted
}

# 2. CloudFront Distribution with S3 origin - FAIL (no origin_access_identity)
resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "bad_bucket" {
  bucket = "bad-bucket-for-cloudfront-${random_id.rand.hex}"
}

resource "aws_cloudfront_distribution" "bad_distribution" {
  origin {
    domain_name = aws_s3_bucket.bad_bucket.bucket_regional_domain_name
    origin_id   = "badS3Origin"

    s3_origin_config {
      origin_access_identity = "" # FAIL: left empty
    }
  }

  enabled             = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "badS3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 3. DynamoDB Table - FAIL (SSE disabled and no kms_key_arn)
resource "aws_dynamodb_table" "bad_table" {
  name         = "bad-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = false # FAIL
    kms_key_arn = ""    # FAIL
  }
}

# 4. Redshift Cluster - FAIL (allow_version_upgrade=false, snapshot retention=1)
resource "aws_redshift_cluster" "bad_cluster" {
  cluster_identifier                  = "bad-cluster"
  master_username                     = "admin"
  master_password                     = "SuperSecretPass123"
  node_type                           = "dc2.large"
  cluster_type                        = "single-node"
  allow_version_upgrade               = false   # FAIL
  automated_snapshot_retention_period = 1       # FAIL
}

# 5. CloudWatch Alarm - FAIL (all actions empty => IsEmpty)
resource "aws_cloudwatch_metric_alarm" "bad_alarm" {
  alarm_name          = "bad-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  alarm_actions             = [] # FAIL: empty
  ok_actions                = [] # FAIL: empty
  insufficient_data_actions = [] # FAIL: empty
}
