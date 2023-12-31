########
# KMS Key 
########
resource "aws_kms_key" "aws_backup_key" {
  description             = var.kms_keys["backup"].description
  deletion_window_in_days = var.kms_keys["backup"].deletion_window
}

resource "aws_kms_alias" "aws_backup_key" {
  name          = "alias/backup/${local.vault_name}"
  target_key_id = aws_kms_key.aws_backup_key.key_id
}

resource "aws_kms_key" "aws_backup_secondary_key" {
  provider                = aws.ireland
  description             = var.kms_keys["backup_secondary"].description
  deletion_window_in_days = var.kms_keys["backup_secondary"].deletion_window
}

resource "aws_kms_alias" "aws_backup_secondary_key" {
  provider      = aws.ireland
  name          = "alias/backup/${local.secondary_vault_name}"
  target_key_id = aws_kms_key.aws_backup_secondary_key.key_id
}

resource "aws_kms_key" "aws_eks_key" {
  description             = var.kms_keys["eks"].description
  deletion_window_in_days = var.kms_keys["eks"].deletion_window
}

resource "aws_kms_alias" "aws_eks_key" {
  name          = "alias/eks/${local.eks_cluster_name}"
  target_key_id = aws_kms_key.aws_eks_key.key_id
}

resource "aws_kms_key" "aws_rds_key" {
  description             = var.kms_keys["rds"].description
  deletion_window_in_days = var.kms_keys["rds"].deletion_window
}

resource "aws_kms_alias" "aws_rds_key" {
  name          = "alias/rds/${local.rds_cluster_name}"
  target_key_id = aws_kms_key.aws_rds_key.key_id
}

resource "aws_kms_key" "aws_s3_key" {
  description             = var.kms_keys["s3"].description
  deletion_window_in_days = var.kms_keys["s3"].deletion_window
}

resource "aws_kms_alias" "aws_s3_key" {
  name          = "alias/s3/${local.s3_name}"
  target_key_id = aws_kms_key.aws_s3_key.key_id
}

resource "aws_kms_key_policy" "aws_s3_key" {
  key_id = aws_kms_key.aws_s3_key.key_id
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
      },

    ]
    Version = "2012-10-17"
  })
}

resource "aws_kms_key" "aws_s3_replica_key" {
  provider                = aws.ireland
  description             = var.kms_keys["s3_replica"].description
  deletion_window_in_days = var.kms_keys["s3_replica"].deletion_window
}

resource "aws_kms_alias" "aws_s3_replica_key" {
  provider      = aws.ireland
  name          = "alias/s3/${local.s3_replica_name}"
  target_key_id = aws_kms_key.aws_s3_replica_key.key_id
}
