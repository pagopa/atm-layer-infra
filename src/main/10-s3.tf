locals {
  s3_name_model                = "${local.namespace}-s3-model"
  s3_name_webconsole           = "${local.namespace}-s3-web-console"
  s3_name_webconsole_artifacts = "${local.namespace}-s3-web-console-artifacts"
  s3_replica_name              = "${local.namespace}-s3-model-replica"
}

########
# S3 Bucket - Model
########
resource "aws_s3_bucket" "s3" {
  bucket = local.s3_name_model

  tags_all = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3" {
  bucket = aws_s3_bucket.s3.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.aws_s3_key.key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "s3" {
  bucket = aws_s3_bucket.s3.id
  versioning_configuration {
    status = "Enabled"
  }
}

#######
# IAM Policy - Manage s3 from eks pods
########
resource "aws_iam_policy" "s3_eks_pod" {
  name        = "s3-model-eks-pods-policy"
  description = "IAM policy to manage s3 from pods"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
              "${aws_s3_bucket.s3.arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
              "${aws_s3_bucket.s3.arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:GenerateDataKey"
            ],
            "Resource": "${aws_kms_key.aws_s3_key.arn}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_pod_1" {
  policy_arn = aws_iam_policy.s3_eks_pod.arn
  role       = aws_iam_role.eks_serviceaccount["atm_layer_model"].name
}

########
# S3 Bucket replica
########
resource "aws_s3_bucket" "s3_replica" {
  provider = aws.ireland
  bucket   = "${local.s3_name_model}-replica"

  tags_all = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_replica" {
  provider = aws.ireland
  bucket   = aws_s3_bucket.s3_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.aws_s3_replica_key.key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "s3_replica" {
  provider = aws.ireland
  bucket   = aws_s3_bucket.s3_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

########
# S3 Bucket REPLICATION
########
resource "aws_iam_role" "s3_replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_replication_policy" {
  name = "s3-replication-policy"
  role = aws_iam_role.s3_replication_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["s3:GetObject*", "s3:ListBucket", "s3:PutObject", "s3:Replicate*"],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.s3.arn}/*",
          "${aws_s3_bucket.s3.arn}",
          "${aws_s3_bucket.s3_replica.arn}/*",
          "${aws_s3_bucket.s3_replica.arn}"
        ]
      },
      {
        Action = "kms:Decrypt",
        Effect = "Allow",
        Resource = [
          "${aws_kms_key.aws_s3_key.arn}"
        ]
      },
      {
        Action = ["kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"],
        Effect = "Allow",
        Resource = [
          "${aws_kms_key.aws_s3_replica_key.arn}"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "s3_replication" {
  bucket = aws_s3_bucket.s3.id

  role = aws_iam_role.s3_replication_role.arn

  rule {
    id       = "ReplicateToIreland"
    status   = "Enabled"
    priority = 0

    destination {
      bucket        = aws_s3_bucket.s3_replica.arn
      storage_class = "STANDARD"
      encryption_configuration {
        replica_kms_key_id = aws_kms_alias.aws_s3_replica_key.arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.s3]
}

########
# Cloudfront - CDN for primary S3 bucket
########
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.s3.bucket_regional_domain_name
    origin_id                = local.s3_name_model
    origin_path              = "/${var.cdn_path}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CDN for ATM BMPN"
  http_version    = "http2"

  default_cache_behavior {
    cache_policy_id  = var.cdn_cache_policy_disabled_id
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_name_model

    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "S3OAC"
  description                       = "S3OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.s3.arn}/${var.cdn_path}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${local.account_id}:distribution/${aws_cloudfront_distribution.s3_distribution.id}"
          }
        }
      }
    ]
  })
}

########
# Secret Manager - Cloudfront
########
resource "aws_secretsmanager_secret" "cdn_secret_manager" {
  name        = "${local.namespace}/cloudfront"
  description = "Cloudfront dns"
}

resource "aws_secretsmanager_secret_version" "cdn_credentials_version" {
  secret_id = aws_secretsmanager_secret.cdn_secret_manager.id
  secret_string = jsonencode({
    url = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
  })
}

resource "aws_secretsmanager_secret_policy" "cdn_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.cdn_secret_manager.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = "${aws_iam_role.eks_cluster.arn}"
      },
      Action   = "secretsmanager:GetSecretValue",
      Resource = "*"
    }]
  })
}

########
# S3 Bucket - web console artifacts
########
resource "aws_s3_bucket" "s3_webconsole_artifacts" {
  bucket = local.s3_name_webconsole_artifacts

  tags_all = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_webconsole_artifacts" {
  bucket = aws_s3_bucket.s3_webconsole_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.aws_s3_webconsole_artifacts_key.key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "s3_webconsole_artifacts" {
  bucket = aws_s3_bucket.s3_webconsole_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

########
# S3 Bucket - web console
########
resource "aws_s3_bucket" "s3_webconsole" {
  bucket = local.s3_name_webconsole

  tags_all = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_webconsole" {
  bucket = aws_s3_bucket.s3_webconsole.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.aws_s3_webconsole_key.key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "s3_webconsole" {
  bucket = aws_s3_bucket.s3_webconsole.id
  versioning_configuration {
    status = "Enabled"
  }
}

########
# Cloudfront - CDN for S3 bucket web console
########
resource "aws_cloudfront_distribution" "s3_webconsole_distribution" {
  origin {
    domain_name              = aws_s3_bucket.s3_webconsole.bucket_regional_domain_name
    origin_id                = local.s3_name_webconsole
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_webconsole.id
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CDN for ATM Web console"
  http_version    = "http2"

  default_cache_behavior {
    cache_policy_id  = var.cdn_cache_policy_enabled_id
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_name_webconsole

    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 403
    response_code         = 200
    response_page_path    = "/webconsole/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/webconsole/index.html"
  }
}

resource "aws_cloudfront_origin_access_control" "s3_webconsole" {
  name                              = "S3WebConsoleOAC"
  description                       = "S3WebConsoleOAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "s3_webconsole_policy" {
  bucket = aws_s3_bucket.s3_webconsole.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.s3_webconsole.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${local.account_id}:distribution/${aws_cloudfront_distribution.s3_webconsole_distribution.id}"
          }
        }
      }
    ]
  })
}
