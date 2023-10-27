locals {
  rds_cluster_name = "${local.namespace}-${var.rds_cluster_name}"
}

########
# Security group for RDS
########
resource "aws_security_group" "rds" {
  name   = "${local.namespace}-rds-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.namespace}-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_rule_ingress_1" {
  type                     = "ingress"
  from_port                = var.rds_cluster_port
  to_port                  = var.rds_cluster_port
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_rule_egress_1" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.rds.id
}

########
# RDS Cluster
########
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_rds_cluster" "rds" {
  cluster_identifier           = local.rds_cluster_name
  engine                       = var.rds_cluster_engine
  engine_version               = var.rds_cluster_engine_version
  availability_zones           = var.azs
  database_name                = var.rds_cluster_db_name
  master_username              = var.rds_cluster_master_username
  master_password              = random_password.password.result
  backup_retention_period      = var.rds_cluster_backup_retention_period
  preferred_backup_window      = var.rds_cluster_preferred_backup_window
  db_subnet_group_name         = aws_db_subnet_group.rds.id
  vpc_security_group_ids       = [aws_security_group.rds.id]
  network_type                 = "IPV4"
  skip_final_snapshot          = true
  apply_immediately            = true
  port                         = var.rds_cluster_port
  kms_key_id                   = aws_kms_key.aws_rds_key.arn
  storage_encrypted            = true
  preferred_maintenance_window = var.rds_cluster_preferred_maintanance_windows
}

resource "aws_rds_cluster_instance" "rds_instances" {
  count                = 3
  identifier           = "aurora-cluster-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.rds.id
  instance_class       = "db.t3.medium"
  engine               = aws_rds_cluster.rds.engine
  engine_version       = aws_rds_cluster.rds.engine_version
  db_subnet_group_name = aws_db_subnet_group.rds.id
}

########
# Secret Manager - RDS
########
resource "aws_secretsmanager_secret" "rds_secret_manager" {
  name        = "${local.namespace}/rds/credentials"
  description = "RDS database credentials"
}

resource "aws_secretsmanager_secret_version" "rds_credentials_version" {
  secret_id = aws_secretsmanager_secret.rds_secret_manager.id
  secret_string = jsonencode({
    username            = "${aws_rds_cluster.rds.master_username}",
    password            = "${random_password.password.result}",
    engine              = "${aws_rds_cluster.rds.engine}",
    host                = "${aws_rds_cluster.rds.endpoint}",
    port                = "${aws_rds_cluster.rds.port}",
    dbClusterIdentifier = "${aws_rds_cluster.rds.id}",
    host-reader         = "${aws_rds_cluster.rds.reader_endpoint}",
    dbName              = "${aws_rds_cluster.rds.database_name}",
  })
}

resource "aws_secretsmanager_secret_policy" "rds_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.rds_secret_manager.arn

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
