locals {
  key_alias_name = {
    "backup"                  = "alias/backup/${local.vault_name}"
    "backup_secondary"        = "alias/backup/${local.secondary_vault_name}"
    "eks"                     = "alias/eks/${local.eks_cluster_name}"
    "rds"                     = "alias/rds/${local.rds_cluster_name}"
    "s3"                      = "alias/s3/${local.s3_name_model}"
    "s3_replica"              = "alias/s3/${local.s3_replica_name}"
    "s3_webconsole_artifacts" = "alias/s3/${local.s3_name_webconsole_artifacts}"
    "s3_webconsole"           = "alias/s3/${local.s3_name_webconsole}"
    "s3_backup_logs"          = "alias/s3/${local.s3_name_backup_logs}"
  }
}

########
# KMS Key 
########
resource "aws_kms_key" "key" {
  for_each = var.kms_keys

  description             = each.value.description
  deletion_window_in_days = each.value.deletion_window
}

resource "aws_kms_alias" "key" {
  for_each = var.kms_keys

  name          = local.key_alias_name[each.key]
  target_key_id = aws_kms_key.key[each.key].key_id
}

resource "aws_kms_key" "key_ireland" {
  for_each = var.kms_keys_ireland

  provider                = aws.ireland
  description             = each.value.description
  deletion_window_in_days = each.value.deletion_window
}

resource "aws_kms_alias" "key_ireland" {
  for_each = var.kms_keys_ireland

  provider      = aws.ireland
  name          = local.key_alias_name[each.key]
  target_key_id = aws_kms_key.key_ireland[each.key].key_id
}

resource "aws_kms_key_policy" "aws_s3_key" {
  key_id = aws_kms_key.key["s3"].key_id
  policy = jsonencode({
    Id = "key-default"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ]
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Resource = "*"
        Sid      = "Enable CDN to Decrypt S3 Object"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudfront::${local.account_id}:distribution/${aws_cloudfront_distribution.s3_distribution.id}"
          }
        }
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_kms_key_policy" "aws_s3_webconsole_key" {
  key_id = aws_kms_key.key["s3_webconsole"].key_id
  policy = jsonencode({
    Id = "key-default"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ]
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Resource = "*"
        Sid      = "Enable CDN to Decrypt S3 Object"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudfront::${local.account_id}:distribution/${aws_cloudfront_distribution.s3_webconsole_distribution.id}"
          }
        }
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_kms_key_policy" "aws_s3_backup_logs_key" {
  key_id = aws_kms_key.key["s3_backup_logs"].key_id
  policy = jsonencode({
    Id = "key-default"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
      {
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Resource = "*"
        Sid      = "Allow CWL Service Principal usage"
      }
    ]
    Version = "2012-10-17"
  })
}
