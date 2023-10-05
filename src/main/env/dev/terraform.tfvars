env_short   = "d"
environment = "dev"

# Ref: https://pagopa.atlassian.net/wiki/spaces/DEVOPS/pages/132810155/Azure+-+Naming+Tagging+Convention#Tagging
tags = {
  CreatedBy   = "Terraform"
  Environment = "Dev"
  Owner       = "ATM Layer"
  Source      = ""
  CostCenter  = ""
}

vpc_cidr                 = "10.110.0.0/16"
vpc_private_subnets_cidr = ["10.110.4.0/22", "10.110.8.0/22", "10.110.12.0/22"]
vpc_public_subnets_cidr  = ["10.110.16.0/22", "10.110.20.0/22", "10.110.24.0/22"]
vpc_endpoints = {
  sns = {
    name     = "sns"
    type     = "Interface"
    tag_name = "SNS - PagoPA VPC"
  },
  backup = {
    name     = "backup"
    type     = "Interface"
    tag_name = "Backup - PagoPA VPC"
  },
  ecr_api = {
    name     = "ecr.api"
    type     = "Interface"
    tag_name = "ECR API - PagoPA VPC"
  },
  ecr_dkr = {
    name     = "ecr.dkr"
    type     = "Interface"
    tag_name = "ECR DKR - PagoPA VPC"
  },
  kms = {
    name     = "kms"
    type     = "Interface"
    tag_name = "KMS - PagoPA VPC"
  },
  secretsmanager = {
    name     = "secretsmanager"
    type     = "Interface"
    tag_name = "Secrets - PagoPA VPC"
  },
  sqs = {
    name     = "sqs"
    type     = "Interface"
    tag_name = "SQS - PagoPA VPC"
  },
  config = {
    name     = "config"
    type     = "Interface"
    tag_name = "Config - PagoPA VPC"
  },
  logs = {
    name     = "logs"
    type     = "Interface"
    tag_name = "Logs - PagoPA VPC"
  },
}

eks_cluster_name            = "eks-name"
eks_cluster_scaling_min     = 3
eks_cluster_scaling_max     = 3
eks_cluster_scaling_desired = 3
eks_node_group_name         = "eks-node-group"
eks_node_group_type         = ["t3.medium"]
eks_scale_down_cron         = "0 18 * * *"
eks_scale_up_cron           = "0 6 * * 1-5"
eks_addons = {
  coredns = {
    name = "coredns"
  },
  kube-proxy = {
    name = "kube-proxy"
  },
  vpc-cni = {
    name = "vpc-cni"
  }
}

rds_cluster_name                    = "rds-name"
rds_cluster_engine_version          = "15.3"
rds_cluster_db_name                 = "pagopadb"
rds_cluster_master_username         = "pagopaadmin"
rds_cluster_backup_retention_period = 1
rds_cluster_preferred_backup_window = "07:00-09:00"

redis_cluster_name                 = "redis-name"
redis_cluster_engine_version       = "7.0"
redis_cluster_node_type            = "cache.t3.micro"
redis_cluster_node_number          = 1
redis_cluster_node_replica_number  = 2
redis_cluster_parameter_group_name = "default.redis7"
redis_cluster_maintenance_window   = "sun:01:00-sun:03:00"

helm_alb_controller_chart_version = "1.6.0"

k8s_alb_name_int = "alb-name-int"
k8s_alb_name_ext = "alb-name-ext"
k8s_namespace    = "pagopa"

k8s_config_map_aws_auth_sso            = "AWSReservedSSO_AWSAdministratorAccess_37cb6a51d1076702"
k8s_config_map_aws_auth_terraform_user = "terraform_user"
k8s_config_map_aws_auth_github_user    = "GitHubActionIACRole"

kms_deletion_window_in_days = 10

vault_name                 = "vault-name"
secondary_vault_name       = "secondary-vault-name"
backup_plan_name           = "backup-plan-name"
backup_plan_rule_name      = "backup-plan-rule-name"
backup_plan_schedule       = "cron(0 12 * * ? *)"
backup_plan_lifecycle_days = 2
backup_selection_name      = "backup-selection-name"

cloudwatch_rule_turn_off = "cron(0 18 * * ? *)"      # TURN OFF Ogni giorno alle 20:00 Rome
cloudwatch_rule_turn_on  = "cron(0 6 ? * MON-FRI *)" # TURN ON Ogni giorno, Lun-Ven, alle 08:00 Rome

microservice5 = "microservice5"
