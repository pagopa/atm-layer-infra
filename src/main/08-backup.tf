locals {
  vault_name           = "${local.namespace}-${var.vault_name}"
  secondary_vault_name = "${local.namespace}-${var.secondary_vault_name}"
  backup_plan_name     = "${local.namespace}-${var.backup_plan_name}"
}

########
# Backup plan for RDS
########
resource "aws_backup_vault" "vault" {
  name        = local.vault_name
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}

resource "aws_backup_vault" "secondary_vault" {
  provider    = aws.ireland
  name        = local.secondary_vault_name
  kms_key_arn = aws_kms_key.aws_backup_secondary_key.arn
}

resource "aws_backup_plan" "plan" {
  name = local.backup_plan_name

  rule {
    rule_name         = var.backup_plan_rule_name
    target_vault_name = aws_backup_vault.vault.name
    schedule          = var.backup_plan_schedule

    lifecycle {
      delete_after = var.backup_plan_lifecycle_days
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.secondary_vault.arn

      lifecycle {
        delete_after = var.backup_plan_lifecycle_days
      }
    }
  }
}

resource "aws_backup_selection" "resources" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = var.backup_selection_name
  plan_id      = aws_backup_plan.plan.id

  resources = [
    aws_rds_cluster.rds.arn
  ]
}

resource "aws_iam_role" "backup_role" {
  name = "backup-plan-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}
