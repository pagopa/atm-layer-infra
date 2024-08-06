locals {
  jaeger_cluster_name     = "${local.namespace}-jaeger"
  opensearch_cluster_name = "${local.namespace}-elastic"
}

########
# Jaeger - Tracer as a pod on EKS
########
resource "helm_release" "jeager" {
  count = var.tracing_pod_enabled == true ? 1 : 0

  name       = var.helm_jaeger_name
  repository = var.helm_jaeger_chart_repository
  chart      = var.helm_jaeger_chart_name
  namespace  = "default"
  version    = var.helm_jaeger_chart_version

  set {
    name  = "provisionDataStore.cassandra"
    value = var.helm_jaeger_provisionDataStore_cassandra
  }

  set {
    name  = "allInOne.enabled"
    value = var.helm_jaeger_allinone_enabled
  }

  set {
    name  = "allInOne.resources.limits.memory"
    value = var.helm_jaeger_allinone_limits_memory
  }

  set {
    name  = "storage.type"
    value = var.helm_jaeger_storage_type
  }

  set {
    name  = "agent.enabled"
    value = var.helm_jaeger_agent_enabled
  }

  set {
    name  = "collector.enabled"
    value = var.helm_jaeger_collector_enabled
  }

  set {
    name  = "query.enabled"
    value = var.helm_jaeger_query_enabled
  }
}

########
# Jaeger - Tracer on ECS
########
resource "aws_ecs_cluster" "jaeger_cluster" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name = local.jaeger_cluster_name

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }
}

resource "aws_ecs_capacity_provider" "jaeger_capacity_provider" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name = "${local.namespace}-jaeger-capacity-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.jaeger_asg[0].arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  cluster_name       = aws_ecs_cluster.jaeger_cluster[0].name
  capacity_providers = [aws_ecs_capacity_provider.jaeger_capacity_provider[0].name]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 1
    capacity_provider = aws_ecs_capacity_provider.jaeger_capacity_provider[0].name
  }
}

########
# Launch template for Jaeger 
########
resource "aws_launch_template" "jaeger" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name          = "${local.namespace}-jaeger-launch-configuration"
  image_id      = var.tracing_cluster_ami
  instance_type = var.tracing_cluster_instance_type

  lifecycle {
    create_before_destroy = true
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.jaeger[0].id]
  }

  iam_instance_profile {
    arn = "arn:aws:iam::${local.account_id}:instance-profile/ecsInstanceRole"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
    }
  }

  user_data = base64encode("#!/bin/bash \necho ECS_CLUSTER=${local.jaeger_cluster_name} >> /etc/ecs/ecs.config;")
}

resource "aws_autoscaling_group" "jaeger_asg" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id]

  target_group_arns = [aws_lb_target_group.jaeger_tg[0].arn, aws_lb_target_group.jaeger_trace_tg[0].arn]

  launch_template {
    id      = aws_launch_template.jaeger[0].id
    version = "$Latest"
  }

  depends_on = [aws_ecs_cluster.jaeger_cluster[0]]
}

resource "aws_security_group" "jaeger" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name   = "${local.namespace}-jaeger-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.namespace}-jaeger-sg"
  }
}

resource "aws_security_group_rule" "jaeger_ecs_rule_ingress_1" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jaeger[0].id
}

resource "aws_security_group_rule" "jaeger_ecs_rule_egress_1" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jaeger[0].id
}

########
# ECS Task definition for Jaeger service 
########
resource "aws_ecs_task_definition" "jaeger" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  family                   = "${local.namespace}-jaeger-task-definition"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "2048"
  memory                   = "2048"
  execution_role_arn       = "arn:aws:iam::${local.account_id}:role/ecsTaskExecutionRole"
  container_definitions    = <<DEFINITION
[
  {
    "name": "${local.namespace}-jaeger",
    "image": "jaegertracing/all-in-one:1.53.0",
    "cpu": 2048,
    "memory": 2048,
    "essential": true,
    "portMappings": [
        {
            "containerPort": 5775,
            "hostPort": 5775,
            "protocol": "udp"
        },
        {
            "containerPort": 6831,
            "hostPort": 6831,
            "protocol": "udp"
        },
        {
            "containerPort": 6832,
            "hostPort": 6832,
            "protocol": "udp"
        },
        {
            "name": "jaeger-5778-tcp",
            "containerPort": 5778,
            "hostPort": 5778,
            "protocol": "tcp"
        },
        {
            "name": "jaeger-16686-tcp",
            "containerPort": 16686,
            "hostPort": 16686,
            "protocol": "tcp"
        },
        {
            "name": "jaeger-16685-tcp",
            "containerPort": 16685,
            "hostPort": 16685,
            "protocol": "tcp"
        },
        {
            "name": "jaeger-9411-tcp",
            "containerPort": 9411,
            "hostPort": 9411,
            "protocol": "tcp"
        },
        {
            "name": "jaeger-4317-tcp",
            "containerPort": 4317,
            "hostPort": 4317,
            "protocol": "tcp"
        },
        {
            "name": "jaeger-4318-tcp",
            "containerPort": 4318,
            "hostPort": 4318,
            "protocol": "tcp"
        }
    ],
    "environment": [
      {
        "name": "SPAN_STORAGE_TYPE",
        "value": "elasticsearch"
      },
      {
        "name": "COLLECTOR_ZIPKIN_HOST_PORT",
        "value": ":9411"
      },
      {
        "name": "COLLECTOR_OTLP_ENABLED",
        "value": "true"
      },
      {
        "name": "ES_SERVER_URLS",
        "value": "https://${aws_opensearch_domain.jaeger_backend[0].endpoint}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
          "awslogs-group": "/aws/ecs/${local.jaeger_cluster_name}/task",
          "awslogs-create-group": "true",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "ecs"
      },
      "secretOptions": []
    }
  }
]
DEFINITION

  depends_on = [aws_cloudwatch_log_group.jaeger[0]]
}

resource "aws_cloudwatch_log_group" "jaeger" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name              = "/aws/ecs/${local.jaeger_cluster_name}/task"
  retention_in_days = var.eks_log_retention_in_days

  tags_all = var.tags
}

resource "aws_ecs_service" "jaeger_service" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name    = "${local.namespace}-jaeger-service"
  cluster = aws_ecs_cluster.jaeger_cluster[0].id
  # task_definition = "arn:aws:ecs:eu-south-1:${local.account_id}:task-definition/jaeger:14"
  task_definition = aws_ecs_task_definition.jaeger[0].arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [aws_autoscaling_group.jaeger_asg[0]]
}

########
# ALB - Internal for Jaeger WebUI 
########
resource "aws_lb" "jaeger_alb" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name               = "${local.namespace}-jaeger-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jaeger[0].id]
  subnets            = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "jaeger_tg" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name        = "jaeger-alb-tg"
  port        = 16686
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = 16686
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "jaeger_listener" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  load_balancer_arn = aws_lb.jaeger_alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger_tg[0].arn
  }
}

########
# NLB - Internal for Jaeger collector on 4317 
########
resource "aws_lb" "jaeger_nlb" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name               = "${local.namespace}-jaeger-nlb"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.jaeger[0].id]
  subnets            = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "jaeger_trace_tg" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  name        = "jaeger-nlb-tg"
  port        = 4317
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol            = "TCP"
    port                = 4317
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "jaeger_trace_listener" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  load_balancer_arn = aws_lb.jaeger_nlb[0].arn
  port              = "4317"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger_trace_tg[0].arn
  }
}

########
# Opensearch - Backend storage for Jaeger 
########
resource "aws_opensearch_domain" "jaeger_backend" {
  count = var.tracing_cluster_enabled == true ? 1 : 0

  domain_name    = local.opensearch_cluster_name
  engine_version = var.tracing_opensearch_engine

  cluster_config {
    dedicated_master_count        = 0
    instance_count                = var.tracing_opensearch_instance_count
    instance_type                 = var.tracing_opensearch_instance_type
    multi_az_with_standby_enabled = false
    zone_awareness_enabled        = true

    cold_storage_options {
      enabled = false
    }

    zone_awareness_config {
      availability_zone_count = 2
    }
  }

  auto_tune_options {
    desired_state       = "DISABLED"
    rollback_on_disable = "NO_ROLLBACK"
  }

  vpc_options {
    security_group_ids = [aws_security_group.jaeger[0].id]
    subnet_ids         = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id]
  }

  advanced_options = {
    "indices.fielddata.cache.size"        = "20"
    "indices.query.bool.max_clause_count" = "1024"
  }

  access_policies = jsonencode({
    Statement = [{
      Action = "es:*"
      Effect = "Allow"
      Principal = {
        AWS = "*"
      }
      Resource = "arn:aws:es:eu-south-1:${local.account_id}:domain/${local.opensearch_cluster_name}/*"
    }]
    Version = "2012-10-17"
  })
}
