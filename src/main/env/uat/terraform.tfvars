env_short   = "u"
environment = "uat"

# Ref: https://pagopa.atlassian.net/wiki/spaces/DEVOPS/pages/132810155/Azure+-+Naming+Tagging+Convention#Tagging
tags = {
  CreatedBy   = "Terraform"
  Environment = "Uat"
  Owner       = "ATM Layer"
  Source      = ""
  CostCenter  = ""
}

vpc_account_default      = "vpc-0a2f5a36caa4d5a27"
vpc_cidr                 = "10.110.4.0/22"
vpc_private_subnets_cidr = ["10.110.4.0/24", "10.110.5.0/24", "10.110.6.0/24"]
vpc_public_subnets_cidr  = ["10.110.7.0/26", "10.110.7.64/26", "10.110.7.128/26"]
vpc_endpoints = {
  ecr_dkr = {
    name     = "ecr.dkr"
    type     = "Interface"
    priv_dns = true
  },
  secretsmanager = {
    name     = "secretsmanager"
    type     = "Interface"
    priv_dns = true
  },
  logs = {
    name     = "logs"
    type     = "Interface"
    priv_dns = true
  },
  s3 = {
    name     = "s3"
    type     = "Gateway"
    priv_dns = false
  },
  lambda = {
    name     = "lambda"
    type     = "Interface"
    priv_dns = true
  },
  dynamodb = {
    name     = "dynamodb"
    type     = "Gateway"
    priv_dns = false
  },
  sns = {
    name     = "sns"
    type     = "Interface"
    priv_dns = true
  },
  rds = {
    name     = "rds"
    type     = "Interface"
    priv_dns = true
  },
  # ec2 = {
  #   name     = "ec2"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  # sts = {
  #   name     = "sts"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  # elasticloadbalancing = {
  #   name     = "elasticloadbalancing"
  #   type     = "Interface"
  #   priv_dns = true
  # },
  # eks = {
  #   name     = "eks"
  #   type     = "Interface"
  #   priv_dns = true
  # }
}

prefix_list_entries = [
  {
    cidr        = "172.211.209.126/32"
    description = "MIL DEV"
  },
  {
    cidr        = "172.211.156.166/32"
    description = "MIL UAT"
  },
  {
    cidr        = "20.71.68.43/32"
    description = "IDPay DEV"
  },
  {
    cidr        = "20.31.11.237/32"
    description = "IDPay UAT"
  },
  {
    cidr        = "20.86.224.30/32"
    description = "Node UAT"
  }
]

# Night autoscaling cronjob
night_shutdown = true

# DB CronJob
cloudwatch_rule_turn_off = "cron(30 18 * * ? *)"      # TURN OFF Ogni giorno alle 20:30 Rome
cloudwatch_rule_turn_on  = "cron(30 5 ? * MON-FRI *)" # TURN ON Ogni giorno, Lun-Ven, alle 07:30 Rome

eks_cluster_name            = "eks"
eks_cluster_scaling_min     = 3
eks_cluster_scaling_max     = 3
eks_cluster_scaling_desired = 3
eks_node_group_name         = "eks-node-group"
eks_node_group_type         = ["c6i.xlarge"] # c6i.xlarge t3.large

# EKS Cronjob
eks_scale_down_cron = "30 20 * * *"   # TURN OFF Ogni giorno alle 20:30 Rome
eks_scale_up_cron   = "35 07 * * 1-5" # TURN ON Ogni giorno alle 07:35 Rome

# POD Cronjob
helm_kube_downscaler_cronjob = "Mon-Fri 07:50-20:15 Europe/Rome"

eks_addons = {
  coredns = {
    name             = "coredns"
    version          = "v1.11.1-eksbuild.8"
    resolve_conflict = "NONE"
  },
  kube-proxy = {
    name             = "kube-proxy"
    version          = "v1.30.0-eksbuild.3"
    resolve_conflict = "NONE"
  },
  vpc-cni = {
    name             = "vpc-cni"
    version          = "v1.18.1-eksbuild.3"
    resolve_conflict = "PRESERVE"
  }
}
eks_node_group_version = "1.32.7-20250821"
eks_kubernetes_version = "1.32"

rds_cluster_name                    = "rds"
rds_cluster_engine_version          = "15.12"
rds_cluster_db_name                 = "pagopadb"
rds_cluster_port                    = 5432
rds_cluster_master_username         = "pagopaadmin"
rds_cluster_backup_retention_period = 1
rds_cluster_preferred_backup_window = "07:00-09:00"
rds_instance_type                   = "db.t4g.large" # da mettere db.r6g.large
rds_instance_replicas               = 1              # da mettere 2
rds_db_schemas                      = "atm_layer_engine,atm_layer_model_schema"

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

helm_metrics_server_chart_version = "3.10.0"

helm_jaeger_chart_version          = "0.74.1"
helm_jaeger_allinone_limits_memory = "4Gi"

tracing_pod_enabled           = true
tracing_cluster_enabled       = false
tracing_cluster_instance_type = "t3.medium"
tracing_cluster_ami           = "ami-074dca56a76155183"

tracing_opensearch_instance_type  = "t3.medium.search"
tracing_opensearch_engine         = "Elasticsearch_7.10"
tracing_opensearch_instance_count = 2

helm_csi_secrets_chart_version          = "1.3.4"
helm_csi_secrets_sync_secret            = true
helm_csi_secrets_rotation_poll_interval = "10s"
helm_csi_secrets_enable_secret_rotation = true

helm_secrets_provider_aws_chart_version = "0.3.4"

helm_reloader_chart_version                      = "1.0.46"
helm_reloader_enable_deployment_reload_on_change = true

k8s_nlb_name_int = "pagopa-uat-atm-layer-nlb-int"
k8s_alb_name_int = "pagopa-uat-atm-layer-alb-int"
k8s_alb_name_ext = "pagopa-uat-atm-layer-alb-ext"
k8s_namespace    = "pagopa"

k8s_config_map_aws_auth_admin_sso      = "AWSReservedSSO_AWSAdministratorAccess_33eeac608dd7ce5e"
k8s_config_map_aws_auth_readonly_sso   = "AWSReservedSSO_AWSReadOnlyAccess_484101b818892426"
k8s_config_map_aws_auth_terraform_user = "terraform_user"
k8s_config_map_aws_auth_github_user    = "GitHubActionIACRole"

cdn_path                    = "RESOURCE"
cdn_resources_alias_prefix  = "resources.uat"
cdn_webconsole_alias_prefix = "webconsole.uat"
cdn_emulator_alias_prefix   = "emulator.uat"
acm_prefix_domain           = "*.uat"

kms_keys = {
  backup = {
    description     = "PAGOPA - KMS Backup key 1",
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
  redis = {
    description     = "PAGOPA - KMS ElastiCache key",
    deletion_window = 10
  },
  s3 = {
    description     = "PAGOPA - KMS S3 key",
    deletion_window = 10
  },
  s3_task_logs = {
    description     = "PAGOPA - KMS S3 Task logs key",
    deletion_window = 10
  },
  s3_webconsole_artifacts = {
    description     = "PAGOPA - KMS S3 WebConsole artifacts key",
    deletion_window = 10
  },
  s3_webconsole = {
    description     = "PAGOPA - KMS S3 WebConsole key",
    deletion_window = 10
  },
  s3_emulator_artifacts = {
    description     = "PAGOPA - KMS S3 Emulator artifacts key",
    deletion_window = 10
  },
  s3_emulator = {
    description     = "PAGOPA - KMS S3 Emulator key",
    deletion_window = 10
  },
  s3_backup_logs = {
    description     = "PAGOPA - KMS S3 Backup logs key",
    deletion_window = 10
  }
}

kms_keys_ireland = {
  backup_secondary = {
    description     = "PAGOPA - KMS Backup key 2",
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

# Add service here to create ECR and IAM Role for service account
services = {
  atm_layer_wf_engine = {
    name = "wf-engine"
  },
  atm_layer_wf_task = {
    name = "wf-task"
  },
  atm_layer_mil_adapter = {
    name = "mil-adapter"
  },
  # atm_layer_mil_authenticator = {
  #   name = "mil-authenticator"
  # },
  atm_layer_wf_process = {
    name = "wf-process"
  },
  atm_layer_model = {
    name = "model"
  },
  atm_layer_schema = {
    name = "schema"
  },
  atm_layer_console_service = {
    name = "console-service"
  },
  atm_layer_transaction_service = {
    name = "transaction-service"
  },
  atm_layer_user_service = {
    name = "user-service"
  },
  atm_layer_reporting_service = {
    name = "reporting-service"
  }
}

api_gateway_name         = "api-rest"
api_gateway_key_enabled  = true
api_gateway_xray_enabled = false
api_gateway_authorizers = {
  task = {
    name = "jwt"
  },
  backoffice = {
    name = "jwt-backoffice"
  }
}

# Add service here to create API Gateway integrations and Cloudwatch dashboard
api_gateway_integrations = {
  atm_layer_wf_task = {
    api_path         = "tasks",
    api_uri          = "api/v1/tasks/{proxy}/",
    api_key_required = false,
    methods_allowed  = ["GET", "PUT", "POST", "DELETE"]
    authorization    = true,
    authorizer       = "task"
  },
  atm_layer_console_service = {
    api_path         = "console-service",
    api_uri          = "api/v1/console-service/{proxy}/",
    api_key_required = false,
    methods_allowed  = ["GET", "PUT", "POST", "DELETE", "OPTIONS"]
    authorization    = false,
    authorizer       = "backoffice"
  }
}

cloudwatch_dashboard_availability_query = "| fields @timestamp, @message\r\n| filter @message like /HTTP Method: POST - Resource Path: \\/.*\\/api\\/v.*\\/console-service\\/task\\/.* - Status: / or @message like /HTTP Method: POST - Resource Path: \\/.*\\/api\\/v.*\\/tasks\\/.* - Status: /\r\n| parse @message /Status: (?<status_code>\\d+)/\r\n| fields (status_code != 408 AND status_code != 500 AND status_code != 501 AND status_code != 502 AND status_code != 503 AND status_code != 504 AND status_code != 209) as request_ok\r\n| stats count(*) as total_requests, sum(request_ok) as successfull_requests, avg(request_ok) * 100 as Availability"

wafv2_enabled              = true
monitoring_changes_enabled = false