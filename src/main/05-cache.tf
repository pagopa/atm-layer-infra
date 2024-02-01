locals {
  redis_cluster_name = "${local.namespace}-${var.redis_cluster_name}"
}

########
# Security group for ElastiCache
########
resource "aws_security_group" "redis" {
  name   = "${local.namespace}-redis-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.namespace}-redis-sg"
  }
}

resource "aws_security_group_rule" "redis_rule_ingress_1" {
  type                     = "ingress"
  from_port                = var.redis_cluster_port
  to_port                  = var.redis_cluster_port
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.redis.id
}

resource "aws_security_group_rule" "redis_rule_egress_1" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.redis.id
}

########
# Redis Cluster
########
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = local.redis_cluster_name
  description                = var.redis_cluster_description
  engine                     = var.redis_cluster_engine
  engine_version             = var.redis_cluster_engine_version
  node_type                  = var.redis_cluster_node_type
  num_node_groups            = var.redis_cluster_node_number
  replicas_per_node_group    = var.redis_cluster_node_replica_number
  parameter_group_name       = var.redis_cluster_parameter_group_name
  port                       = var.redis_cluster_port
  maintenance_window         = var.redis_cluster_maintenance_window
  multi_az_enabled           = true
  automatic_failover_enabled = true
  subnet_group_name          = aws_elasticache_subnet_group.redis.id
  security_group_ids         = [aws_security_group.redis.id]
}

########
# Secret Manager - Redis
########
resource "aws_secretsmanager_secret" "redis_secret_manager" {
  name                    = "${local.namespace}/redis/credentials"
  description             = "Redis credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "redis_credentials_version" {
  secret_id = aws_secretsmanager_secret.redis_secret_manager.id
  secret_string = jsonencode({
    host        = "${aws_elasticache_replication_group.redis.primary_endpoint_address}",
    host-reader = "${aws_elasticache_replication_group.redis.reader_endpoint_address}",
    port        = "${var.redis_cluster_port}",
  })
}

resource "aws_secretsmanager_secret_policy" "redis_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.redis_secret_manager.arn

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
