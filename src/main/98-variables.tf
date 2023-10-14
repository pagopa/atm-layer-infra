variable "aws_region" {
  type        = string
  default     = "eu-south-1"
  description = "AWS region to create resources. Default Milan"
}

variable "aws_secondary_region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region to create resources. Default Ireland"
}

variable "app_name" {
  type        = string
  default     = "atm-layer"
  description = "App name."
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "env_short" {
  type        = string
  description = "Environment short."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC cidr."
}

variable "azs" {
  type        = list(string)
  default     = ["eu-south-1a", "eu-south-1b", "eu-south-1c"]
  description = "Availability zones"
}

variable "vpc_private_subnets_cidr" {
  type        = list(string)
  description = "Private subnets list of cidr."
}

variable "vpc_public_subnets_cidr" {
  type        = list(string)
  description = "Private subnets list of cidr."
}

variable "vpc_endpoints" {
  type = map(object({
    name = string
    type = string
  }))
  description = "Map of VPC Endpoints"
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS Cluster name."
}

variable "eks_cluster_scaling_min" {
  type        = number
  default     = 3
  description = "EKS Cluster min number of nodes."
}

variable "eks_cluster_scaling_max" {
  type        = number
  default     = 3
  description = "EKS Cluster max number of nodes."
}

variable "eks_cluster_scaling_desired" {
  type        = number
  default     = 3
  description = "EKS Cluster desired number of nodes."
}

variable "eks_node_group_name" {
  type        = string
  description = "EKS Cluster node group name."
}

variable "eks_node_group_type" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EKS Cluster node group type."
}

variable "eks_log_retention_in_days" {
  type        = number
  default     = 5
  description = "EKS Cluster Log Retention in days."
}

variable "eks_scale_down_cron" {
  type        = string
  description = "EKS Cluster node group scaling down the cluster for dev env during the night."
}

variable "eks_scale_up_cron" {
  type        = string
  description = "EKS Cluster node group scaling up the cluster for dev env during the morning."
}

variable "eks_addons" {
  type = map(object({
    name = string
  }))
  description = "Map of EKS Addons"
}

variable "alb_https_port" {
  type        = number
  default     = 443
  description = "HTTPS Port for alb."
}

variable "alb_http_port" {
  type        = number
  default     = 80
  description = "HTTP Port for alb."
}

variable "rds_cluster_name" {
  type        = string
  description = "EKS Cluster name."
}

variable "rds_cluster_port" {
  type        = number
  default     = 5431
  description = "RDS Cluster port."
}

variable "rds_cluster_engine" {
  type        = string
  default     = "aurora-postgresql"
  description = "RDS Cluster engine."
}

variable "rds_cluster_engine_version" {
  type        = string
  default     = "15.3"
  description = "RDS Cluster engine version."
}

variable "rds_cluster_db_name" {
  type        = string
  description = "RDS Cluster db name."
}

variable "rds_cluster_master_username" {
  type        = string
  description = "RDS Cluster master username."
}

variable "rds_cluster_backup_retention_period" {
  type        = number
  default     = 5
  description = "RDS Cluster backup retention period."
}

variable "rds_cluster_preferred_backup_window" {
  type        = string
  default     = "07:00-09:00"
  description = "RDS Cluster backup retention period."
}

variable "rds_cluster_preferred_maintanance_windows" {
  type        = string
  default     = "Sun:02:00-Sun:04:00"
  description = "RDS Cluster mainanance windows slot"
}

variable "redis_cluster_name" {
  type        = string
  description = "Redis Cluster name."
}

variable "redis_cluster_description" {
  type        = string
  default     = "Redis cluster"
  description = "Redis Cluster name."
}

variable "redis_cluster_port" {
  type        = number
  default     = 6379
  description = "Redis Cluster port."
}

variable "redis_cluster_engine" {
  type        = string
  default     = "redis"
  description = "Redis Cluster engine."
}

variable "redis_cluster_engine_version" {
  type        = string
  default     = "7.0"
  description = "Redis Cluster engine version."
}

variable "redis_cluster_node_type" {
  type        = string
  default     = "cache.t3.micro"
  description = "Redis Cluster node type."
}

variable "redis_cluster_node_number" {
  type        = number
  default     = 1
  description = "Redis Cluster node number."
}

variable "redis_cluster_node_replica_number" {
  type        = number
  default     = 2
  description = "Redis Cluster node replica number."
}

variable "redis_cluster_parameter_group_name" {
  type        = string
  default     = "default.redis7"
  description = "Redis Cluster paramter group name."
}

variable "redis_cluster_maintenance_window" {
  type        = string
  default     = "sun:01:00-sun:03:00"
  description = "Redis Cluster maintenance window."
}

variable "helm_alb_controller_name" {
  type        = string
  default     = "alb-controller"
  description = "Helm name for ALB Controller."
}

variable "helm_alb_controller_chart_repository" {
  type        = string
  default     = "https://aws.github.io/eks-charts"
  description = "Helm chart repository for ALB Controller."
}

variable "helm_alb_controller_chart_name" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "Helm chart name for ALB Controller."
}

variable "helm_alb_controller_chart_version" {
  type        = string
  default     = "1.6.0"
  description = "Helm chart version for ALB Controller."
}

variable "helm_alb_controller_chart_settings" {
  default     = {}
  description = "Additional settings which will be passed to the Helm chart values."
}

variable "helm_fluent_bit_name" {
  type        = string
  default     = "fluent-bit"
  description = "Helm name for fluent bit."
}

variable "helm_fluent_bit_chart_repository" {
  type        = string
  default     = "https://aws.github.io/eks-charts"
  description = "Helm chart repository for fluent bit."
}

variable "helm_fluent_bit_chart_name" {
  type        = string
  default     = "aws-for-fluent-bit"
  description = "Helm chart name for fluent bit."
}

variable "helm_fluent_bit_chart_version" {
  type        = string
  description = "Helm chart version for fluent bit."
}

variable "helm_fluent_bit_create_serviceaccount" {
  type        = bool
  description = "Helm chart create service account for fluent bit."
}

variable "helm_fluent_bit_enabled_cloudwatchlogs" {
  type        = bool
  description = "Helm chart enable cloudwatch logs for fluent bit."
}

variable "helm_fluent_bit_logretentiondays_cloudwatchlogs" {
  type        = number
  description = "Helm chart log retention days for fluent bit."
}

variable "helm_fluent_bit_enabled_elasticsearch" {
  type        = bool
  description = "Helm chart enabled elasticsearch for fluent bit."
}

variable "k8s_kube_system_namespace" {
  type        = string
  default     = "kube-system"
  description = "Kubernetes namespace."
}

variable "k8s_nlb_name_int" {
  type        = string
  description = "Kubernetes ALB Internal."
}

variable "k8s_alb_name_int" {
  type        = string
  description = "Kubernetes ALB Internal."
}

variable "k8s_alb_name_ext" {
  type        = string
  description = "Kubernetes ALB Public."
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes Namespace."
}

variable "k8s_config_map_aws_auth_sso" {
  type        = string
  description = "SSO AWS Admin."
}

variable "k8s_config_map_aws_auth_terraform_user" {
  type        = string
  description = "AWS Terraform user."
}

variable "k8s_config_map_aws_auth_github_user" {
  type        = string
  description = "AWS Github user."
}

variable "kms_deletion_window_in_days" {
  type        = number
  default     = 10
  description = "KMS deletion windows in days."
}

variable "vault_name" {
  type        = string
  description = "AWS Backup vault name."
}

variable "secondary_vault_name" {
  type        = string
  description = "Secondary AWS Backup vault name."
}

variable "backup_plan_name" {
  type        = string
  description = "AWS Backup plan name."
}

variable "backup_plan_rule_name" {
  type        = string
  description = "AWS Backup plan name."
}

variable "backup_plan_schedule" {
  type        = string
  description = "AWS Backup plan schedule."
}

variable "backup_plan_lifecycle_days" {
  type        = number
  default     = 2
  description = "AWS Backup plan backup lifecycle days."
}

variable "backup_selection_name" {
  type        = string
  description = "AWS Backup selection name."
}

variable "lambda_function_name" {
  type        = string
  default     = "rds-autoscaling"
  description = "Lambda function name."
}

variable "lambda_function_runtime" {
  type        = string
  default     = "python3.9"
  description = "Lambda function runtime."
}

variable "cloudwatch_rule_turn_off" {
  type        = string
  description = "Cloudwatch turn off cron."
}

variable "cloudwatch_rule_turn_on" {
  type        = string
  description = "Cloudwatch turn on cron."
}

variable "night_shutdown" {
  type        = bool
  description = "Boolean to choose if shutdown EKS and RDS the night"
}

variable "services" {
  type = map(object({
    name              = string,
    ecr_registry_name = string
  }))
  description = "Map of Services"
}

variable "api_gateway_name" {
  type        = string
  description = "Api Gateway name."
}

variable "tags" {
  type = map(any)
  default = {
    CreatedBy = "Terraform"
  }
}
