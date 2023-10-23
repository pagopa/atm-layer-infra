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

vpc_cidr                 = "10.110.0.0/22"
vpc_private_subnets_cidr = ["10.110.0.0/24", "10.110.1.0/24", "10.110.2.0/24"]
vpc_public_subnets_cidr  = ["10.110.3.0/26", "10.110.3.64/26", "10.110.3.128/26"]
vpc_endpoints = {
  # sns = {
  #   name     = "sns"
  #   type     = "Interface"
  # },
  backup = {
    name     = "backup"
    type     = "Interface"
  },
  # ecr_api = {
  #   name     = "ecr.api"
  #   type     = "Interface"
  # },
  ecr_dkr = {
    name     = "ecr.dkr"
    type     = "Interface"
  },
  kms = {
    name     = "kms"
    type     = "Interface"
  },
  secretsmanager = {
    name     = "secretsmanager"
    type     = "Interface"
  },
  # sqs = {
  #   name     = "sqs"
  #   type     = "Interface"
  # },
  # config = {
  #   name     = "config"
  #   type     = "Interface"
  # },
  logs = {
    name     = "logs"
    type     = "Interface"
  }
}

eks_cluster_name            = "eks"
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

rds_cluster_name                    = "rds"
rds_cluster_engine_version          = "15.3"
rds_cluster_db_name                 = "pagopadb"
rds_cluster_master_username         = "pagopaadmin"
rds_cluster_backup_retention_period = 1
rds_cluster_preferred_backup_window = "07:00-09:00"

redis_cluster_name                 = "redis"
redis_cluster_engine_version       = "7.0"
redis_cluster_node_type            = "cache.t3.micro"
redis_cluster_node_number          = 1
redis_cluster_node_replica_number  = 2
redis_cluster_parameter_group_name = "default.redis7"
redis_cluster_maintenance_window   = "sun:01:00-sun:03:00"

helm_alb_controller_chart_version               = "1.6.0"
helm_fluent_bit_chart_version                   = "0.1.30"
helm_fluent_bit_create_serviceaccount           = "true"
helm_fluent_bit_enabled_cloudwatchlogs          = "true"
helm_fluent_bit_logretentiondays_cloudwatchlogs = 7
helm_fluent_bit_enabled_elasticsearch           = "false"

k8s_nlb_name_int = "pagopa-dev-atm-layer-nlb-int"
k8s_alb_name_int = "pagopa-dev-atm-layer-alb-int"
k8s_alb_name_ext = "pagopa-dev-atm-layer-alb-ext"
k8s_namespace    = "pagopa"

k8s_config_map_aws_auth_sso            = "AWSReservedSSO_AWSAdministratorAccess_37cb6a51d1076702"
k8s_config_map_aws_auth_terraform_user = "terraform_user"
k8s_config_map_aws_auth_github_user    = "GitHubActionIACRole"

kms_deletion_window_in_days = 10

vault_name                 = "vault"
secondary_vault_name       = "secondary-vault"
backup_plan_name           = "backup-plan"
backup_plan_rule_name      = "backup-plan-rule"
backup_plan_schedule       = "cron(0 12 * * ? *)"
backup_plan_lifecycle_days = 2
backup_selection_name      = "backup-selection"

cloudwatch_rule_turn_off = "cron(0 18 * * ? *)"      # TURN OFF Ogni giorno alle 20:00 Rome
cloudwatch_rule_turn_on  = "cron(0 6 ? * MON-FRI *)" # TURN ON Ogni giorno, Lun-Ven, alle 08:00 Rome
night_shutdown           = true

services = {
  quarkus_hello_world = {
    name = "helloworld",
    ecr_registry_name = "helloworld"
  },
  atm_layer_wf_engine = {
    name = "wf-engine",
    ecr_registry_name = "atm-layer-wf-engine"
  },
  atm_layer_wf_task = {
    name = "wf-task",
    ecr_registry_name = "atm-layer-wf-task"
  },
  atm_layer_mil_adapter = {
    name = "mil-adapter",
    ecr_registry_name = "atm-layer-mil-adapter"
  },
  atm_layer_wf_process = {
    name = "wf-process",
    ecr_registry_name = "atm-layer-wf-process"
  }
}

api_gateway_name             = "api-rest"