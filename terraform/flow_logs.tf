data "aws_caller_identity" "current" {}

# CSW AWS connector — required VPC flow log fields (plain-text, S3).
# Ref: CSW AWS Connector Guide §3.2 / configure flow logs CLI example.
locals {
  csw_vpc_flow_log_format = "$${version} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${tcp-flags} $${interface-id} $${log-status} $${flow-direction} $${pkt-srcaddr} $${pkt-dstaddr}"
}

resource "aws_s3_bucket" "vpc_flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = "${var.project_name}-vpc-flow-logs-${data.aws_caller_identity.current.account_id}"

  force_destroy = true

  tags = {
    Name    = "${var.project_name}-vpc-flow-logs"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "vpc_flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.vpc_flow_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpc_flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.vpc_flow_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_bucket" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.vpc_flow_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.vpc_flow_logs[0].arn]
  }
}

resource "aws_s3_bucket_policy" "vpc_flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.vpc_flow_logs[0].id
  policy = data.aws_iam_policy_document.vpc_flow_logs_bucket[0].json

  depends_on = [aws_s3_bucket_public_access_block.vpc_flow_logs]
}

resource "aws_s3_bucket_lifecycle_configuration" "vpc_flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.vpc_flow_logs[0].id

  rule {
    id     = "expire-flow-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.flow_logs_retention_days
    }
  }
}

resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.dev_vpc.id
  traffic_type         = "ALL" # CSW requires ACCEPT and REJECT
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.vpc_flow_logs[0].arn

  log_format = local.csw_vpc_flow_log_format

  destination_options {
    file_format                = "plain-text"
    hive_compatible_partitions = false
    per_hour_partition         = true # CSW supports hourly partitions
  }

  max_aggregation_interval = 60

  tags = {
    Name    = "${var.project_name}-vpc-flow-log"
    Project = var.project_name
  }

  depends_on = [aws_s3_bucket_policy.vpc_flow_logs]
}
