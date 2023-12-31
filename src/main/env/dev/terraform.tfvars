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
  #   priv_dns = true
  # },
  # backup = {
  #   name     = "backup"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  # ecr_api = {
  #   name     = "ecr.api"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  ecr_dkr = {
    name     = "ecr.dkr"
    type     = "Interface"
    priv_dns = true
  },
  # kms = {
  #   name     = "kms"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  secretsmanager = {
    name     = "secretsmanager"
    type     = "Interface"
    priv_dns = true
  },
  # sqs = {
  #   name     = "sqs"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  # config = {
  #   name     = "config"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  logs = {
    name     = "logs"
    type     = "Interface"
    priv_dns = true
  },
  s3 = {
    name     = "s3"
    type     = "Interface"
    priv_dns = false
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
rds_cluster_port                    = 5431
rds_cluster_master_username         = "pagopaadmin"
rds_cluster_backup_retention_period = 1
rds_cluster_preferred_backup_window = "07:00-09:00"
rds_instance_type                   = "db.t4g.medium"

redis_cluster_name                 = "redis"
redis_cluster_engine_version       = "7.0"
redis_cluster_node_type            = "cache.t4g.micro"
redis_cluster_node_number          = 1
redis_cluster_node_replica_number  = 2
redis_cluster_parameter_group_name = "default.redis7"
redis_cluster_maintenance_window   = "sun:01:00-sun:03:00"

helm_alb_controller_chart_version               = "1.6.0"
helm_fluent_bit_chart_version                   = "0.1.30"
helm_fluent_bit_create_serviceaccount           = true
helm_fluent_bit_enabled_cloudwatchlogs          = true
helm_fluent_bit_logretentiondays_cloudwatchlogs = 7
helm_fluent_bit_enabled_elasticsearch           = false

helm_csi_secrets_chart_version          = "1.3.4"
helm_csi_secrets_sync_secret            = true
helm_csi_secrets_rotation_poll_interval = "10s"
helm_csi_secrets_enable_secret_rotation = true

helm_secrets_provider_aws_chart_version = "0.3.4"

helm_reloader_chart_version                      = "1.0.46"
helm_reloader_enable_deployment_reload_on_change = true

k8s_nlb_name_int = "pagopa-dev-atm-layer-nlb-int"
k8s_alb_name_int = "pagopa-dev-atm-layer-alb-int"
k8s_alb_name_ext = "pagopa-dev-atm-layer-alb-ext"
k8s_namespace    = "pagopa"

k8s_config_map_aws_auth_sso            = "AWSReservedSSO_AWSAdministratorAccess_37cb6a51d1076702"
k8s_config_map_aws_auth_terraform_user = "terraform_user"
k8s_config_map_aws_auth_github_user    = "GitHubActionIACRole"

kms_keys = {
  backup = {
    description     = "PAGOPA - KMS Backup key 1",
    deletion_window = 10
  },
  backup_secondary = {
    description     = "PAGOPA - KMS Backup key 2",
    deletion_window = 10
  },
  eks = {
    description     = "PAGOPA - KMS EKS key",
    deletion_window = 10
  },
  rds = {
    description     = "PAGOPA - KMS RDS key",
    deletion_window = 10
  },
  s3 = {
    description     = "PAGOPA - KMS S3 key",
    deletion_window = 10
  },
  s3_replica = {
    description     = "PAGOPA - KMS S3 Replica key",
    deletion_window = 10
  }
}

vault_name                 = "vault"
secondary_vault_name       = "secondary-vault"
backup_plan_name           = "backup-plan"
backup_plan_rule_name      = "backup-plan-rule"
backup_plan_schedule       = "cron(0 12 * * ? *)"
backup_plan_lifecycle_days = 2
backup_selection_name      = "backup-selection"

cloudwatch_rule_turn_off = "cron(0 20 * * ? *)"      # TURN OFF Ogni giorno alle 21:00 Rome
cloudwatch_rule_turn_on  = "cron(0 6 ? * MON-FRI *)" # TURN ON Ogni giorno, Lun-Ven, alle 07:00 Rome
night_shutdown           = true

services = {
  quarkus_hello_world = {
    name              = "helloworld",
    ecr_registry_name = "helloworld",
    api_path          = "microservice5",
    api_uri           = "microservice5/{proxy}/",
    api_key_required  = false,
    authorization     = true,
    api_enabled       = true
  },
  atm_layer_wf_engine = {
    name              = "wf-engine",
    ecr_registry_name = "atm-layer-wf-engine",
    api_path          = "",
    api_uri           = "",
    api_key_required  = false,
    authorization     = false,
    api_enabled       = false
  },
  atm_layer_wf_task = {
    name              = "wf-task",
    ecr_registry_name = "atm-layer-wf-task",
    api_path          = "tasks",
    api_uri           = "api/v1/tasks/{proxy}/",
    api_key_required  = false,
    authorization     = false,
    api_enabled       = true
  },
  atm_layer_mil_adapter = {
    name              = "mil-adapter",
    ecr_registry_name = "atm-layer-mil-adapter",
    api_path          = "",
    api_uri           = "",
    api_key_required  = false,
    authorization     = false,
    api_enabled       = false
  },
  atm_layer_wf_process = {
    name              = "wf-process",
    ecr_registry_name = "atm-layer-wf-process",
    api_path          = "processes",
    api_uri           = "api/v1/processes/{proxy}/",
    api_key_required  = false,
    authorization     = false,
    api_enabled       = true
  },
  atm_layer_model = {
    name              = "model",
    ecr_registry_name = "atm-layer-model",
    api_path          = "model",
    api_uri           = "api/v1/model/{proxy}/",
    api_key_required  = false,
    authorization     = false,
    api_enabled       = true
  },
  atm_layer_schema = {
    name              = "schema",
    ecr_registry_name = "atm-layer-schema",
    api_path          = "",
    api_uri           = "",
    api_key_required  = false,
    authorization     = false,
    api_enabled       = false
  }
}

api_gateway_name        = "api-rest"
api_gateway_key_enabled = true
