########
# KMS Key 
########
resource "aws_kms_key" "aws_backup_key" {
  description             = "KMS Backup key 1"
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_key" "aws_backup_secondary_key" {
  provider                = aws.ireland
  description             = "KMS Backup key 2"
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_key" "aws_eks_key" {
  description             = "KMS EKS key"
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_key" "aws_rds_key" {
  description             = "KMS RDS key"
  deletion_window_in_days = var.kms_deletion_window_in_days
}
