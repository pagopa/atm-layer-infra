locals {
  rds_cluster_name                   = "${local.namespace}-${var.rds_cluster_name}"
  lambda_function_name_create_schema = "${local.namespace}-${var.lambda_function_name_create_schema}"
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
  cluster_identifier = local.rds_cluster_name
  engine             = var.rds_cluster_engine
  engine_version     = var.rds_cluster_engine_version
  availability_zones = var.azs
  database_name      = var.rds_cluster_db_name
  master_username    = var.rds_cluster_master_username
  master_password    = random_password.password.result
  # manage_master_user_password  = true
  # master_user_secret_kms_key_id = aws_kms_key.aws_rds_key.arn
  backup_retention_period      = var.rds_cluster_backup_retention_period
  preferred_backup_window      = var.rds_cluster_preferred_backup_window
  db_subnet_group_name         = aws_db_subnet_group.rds.id
  vpc_security_group_ids       = [aws_security_group.rds.id]
  network_type                 = "IPV4"
  skip_final_snapshot          = true
  apply_immediately            = true
  port                         = var.rds_cluster_port
  kms_key_id                   = aws_kms_key.key["rds"].arn
  storage_encrypted            = true
  preferred_maintenance_window = var.rds_cluster_preferred_maintanance_windows
}

resource "aws_rds_cluster_instance" "rds_instances" {
  count                = 3
  identifier           = "aurora-cluster-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.rds.id
  instance_class       = var.rds_instance_type
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

########
# Lambda to create DB schema
########
resource "aws_iam_role" "lambda_role_rds_create_schema" {
  name = "RDS-CreateSchema-Lambda-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role_rds_create_schema.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_vpc_policy" {
  name = "lambda_vpc_policy"
  role = aws_iam_role.lambda_role_rds_create_schema.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*",
        Effect   = "Allow",
      },
    ],
  })
}

resource "aws_lambda_function" "rds_create_schemas" {
  function_name = local.lambda_function_name_create_schema
  role          = aws_iam_role.lambda_role_rds_create_schema.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_function_runtime
  filename      = "lambdas/${var.environment}/rds_create_schemas/lambda_function_payload.zip"
  timeout       = 10

  vpc_config {
    subnet_ids         = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id, aws_subnet.priv_subnet_3.id]
    security_group_ids = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
  }

  environment {
    variables = {
      DB_HOST     = aws_rds_cluster.rds.endpoint
      DB_USER     = aws_rds_cluster.rds.master_username
      DB_PASSWORD = random_password.password.result
      DB_NAME     = aws_rds_cluster.rds.database_name
      DB_PORT     = aws_rds_cluster.rds.port
      DB_SCHEMAS  = var.rds_db_schemas
    }
  }

  depends_on = [aws_rds_cluster.rds]
}

resource "aws_lambda_invocation" "rds_create_schemas" {
  function_name = aws_lambda_function.rds_create_schemas.function_name

  triggers = {
    redeployment = sha1(jsonencode([
      aws_lambda_function.rds_create_schemas.environment
    ]))
  }

  input = jsonencode({
    key1 = "value1"
  })
}
