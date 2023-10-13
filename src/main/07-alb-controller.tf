########
# EKS Cluster - ALB controller
########
resource "helm_release" "alb_controller" {
  name       = var.helm_alb_controller_name
  repository = var.helm_alb_controller_chart_repository
  chart      = var.helm_alb_controller_chart_name
  namespace  = var.k8s_kube_system_namespace
  version    = var.helm_alb_controller_chart_version

  values = [
    yamlencode(var.helm_alb_controller_chart_settings)
  ]

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks_cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }
}

# Following data resource needs Helm chart deployed

# data "aws_lb" "alb_controller_int" {
#   name = var.k8s_alb_name_int
# }

# #########
# # NLB for VPC Link used into the Api Gateway to forward traffic to Internal ALB
# #########
# resource "aws_lb" "nlb_int" {
#   name               = var.k8s_nlb_name_int
#   internal           = true
#   load_balancer_type = "network"
#   subnets = [
#     aws_subnet.priv_subnet_1.id,
#     aws_subnet.priv_subnet_2.id,
#     aws_subnet.priv_subnet_3.id
#   ]
#   security_groups = [aws_security_group.nlb_int.id]

#   enable_deletion_protection = false
# }

# # Following resource needs Internal ALB

# #########
# # NLB Target Group
# #########
# resource "aws_lb_target_group" "nlb_int_target_group" {
#   name        = "${local.namespace}-nlb-int-tg"
#   port        = var.alb_http_port
#   protocol    = "TCP"
#   target_type = "alb"
#   vpc_id      = aws_vpc.main.id

#   health_check {
#     protocol            = "HTTP"
#     path                = "/"
#     port                = "traffic-port"
#     healthy_threshold   = 5
#     unhealthy_threshold = 2
#     timeout             = 6
#     interval            = 30
#     matcher             = "200-399"
#   }
# }

# resource "aws_lb_listener" "nlb_int_target_group_listener" {
#   load_balancer_arn = aws_lb.nlb_int.arn
#   port              = var.alb_http_port
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.nlb_int_target_group.arn
#   }
# }

# resource "aws_lb_target_group_attachment" "nlb_int_target_group_attachment" {
#   target_group_arn = aws_lb_target_group.nlb_int_target_group.arn
#   target_id        = data.aws_lb.alb_controller_int.arn
#   port             = var.alb_http_port

#   depends_on = [aws_lb_listener.nlb_int_target_group_listener]
# }

# ########
# # Security group for NLB
# ########
# resource "aws_security_group" "nlb_int" {
#   name   = "${local.namespace}-nlb-int-sg"
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "${local.namespace}-nlb-int-sg"
#   }
# }

# resource "aws_security_group_rule" "nlb_int_rule_ingress_1" {
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nlb_int.id
# }

# resource "aws_security_group_rule" "nlb_int_rule_egress_1" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nlb_int.id
# }
