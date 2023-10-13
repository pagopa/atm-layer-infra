########
# KMS Key 
########
resource "aws_kms_key" "aws_backup_key" {
  description             = "PAGOPA - KMS Backup key 1"
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_alias" "aws_backup_key" {
  name          = "alias/backup/${local.vault_name}"
  target_key_id = aws_kms_key.aws_backup_key.key_id
}

resource "aws_kms_key" "aws_backup_secondary_key" {
  provider                = aws.ireland
  description             = "PAGOPA - KMS Backup key 2"
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_alias" "aws_backup_secondary_key" {
  provider                = aws.ireland
  name          = "alias/backup/${local.secondary_vault_name}"
  target_key_id = aws_kms_key.aws_backup_secondary_key.key_id
}

resource "aws_kms_key" "aws_eks_key" {
  description             = "PAGOPA - KMS EKS key"
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_alias" "aws_eks_key" {
  name          = "alias/eks/${local.eks_cluster_name}"
  target_key_id = aws_kms_key.aws_eks_key.key_id
}

resource "aws_kms_key" "aws_rds_key" {
  description             = "PAGOPA - KMS RDS key"
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_alias" "aws_rds_key" {
  name          = "alias/rds/${local.rds_cluster_name}"
  target_key_id = aws_kms_key.aws_rds_key.key_id
}
