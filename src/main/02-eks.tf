locals {
  eks_cluster_name       = "${local.namespace}-${var.eks_cluster_name}"
  eks_node_group_name    = "${local.namespace}-${var.eks_node_group_name}"
  alb_controller_sa_name = "aws-load-balancer-controller"
}

########
# Security group for EKS Cluster - 0.0.0.0 ingress to be updated from external internet (github pipe, etc)
########
resource "aws_security_group" "eks_cluster" {
  name   = "${local.namespace}-eks-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.namespace}-eks-sg"
  }
}

resource "aws_security_group_rule" "eks_rule_ingress_1" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "eks_rule_egress_1" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
}

########
# EKS Cluster
########
resource "aws_eks_cluster" "eks_cluster" {
  name                      = local.eks_cluster_name
  role_arn                  = aws_iam_role.eks_cluster.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  version                   = var.eks_kubernetes_version

  vpc_config {
    subnet_ids = [
      aws_subnet.priv_subnet_1.id,
      aws_subnet.priv_subnet_2.id,
      aws_subnet.priv_subnet_3.id
    ]
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.key["eks"].arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_1,
    aws_iam_role_policy_attachment.eks_cluster_2,
    aws_cloudwatch_log_group.logs,
    aws_cloudwatch_log_group.cluster
  ]
}

resource "aws_eks_addon" "addon" {
  for_each = var.eks_addons

  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = each.value.name
  addon_version               = each.value.version
  resolve_conflicts_on_update = each.value.resolve_conflict
}

########
# EKS namespace
########
resource "kubernetes_namespace" "pagopa" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}

#######
# K8s configmap
########
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = var.k8s_kube_system_namespace
  }

  data = {
    mapRoles = <<YAML
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: ${aws_iam_role.eks_nodes.arn}
  username: system:node:{{EC2PrivateDNSName}}
- rolearn: arn:aws:iam::${local.account_id}:role/${var.k8s_config_map_aws_auth_admin_sso}
  username: admin
  groups:
    - system:masters
- rolearn: arn:aws:iam::${local.account_id}:role/${var.k8s_config_map_aws_auth_github_user}
  username: admin
  groups:
    - system:masters
- rolearn: arn:aws:iam::${local.account_id}:role/${var.k8s_config_map_aws_auth_readonly_sso}
  username: readonly
  groups:
    - readonly
YAML
    mapUsers = <<EOT
- groups:
  - system:masters
  userarn: arn:aws:iam::${local.account_id}:user/${var.k8s_config_map_aws_auth_terraform_user}
EOT
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    kubernetes_cluster_role_binding.readonly_binding
  ]
}

#######
# K8s configmap role binding - ReadOnly 
########
resource "kubernetes_cluster_role_binding" "readonly_binding" {
  metadata {
    name = "readonly-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "User"
    name      = "readonly"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role" "readonly_nodes" {
  metadata {
    name = "readonly-nodes"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "readonly_nodes_binding" {
  metadata {
    name = "readonly-nodes-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.readonly_nodes.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "readonly"
    api_group = "rbac.authorization.k8s.io"
  }
}

########
# IAM role and policy attachment for EKS Cluster
########
resource "aws_iam_role" "eks_cluster" {
  name = "${local.namespace}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_cluster.name
}

########
# Security group for EKS Node group
########
resource "aws_security_group" "eks_node_group" {
  name   = "${local.namespace}-eks-node-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.namespace}-eks-node-sg"
  }
}

resource "aws_security_group_rule" "eks_node_rule_ingress_1" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_node_group.id
  security_group_id        = aws_security_group.eks_node_group.id
}

resource "aws_security_group_rule" "eks_node_rule_egress_1" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node_group.id
}

########
# EKS Node group
########
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = local.eks_node_group_name
  node_role_arn   = aws_iam_role.eks_nodes.arn

  ami_type             = "AL2023_x86_64_STANDARD"
  release_version      = var.eks_node_group_version
  version              = var.eks_kubernetes_version
  force_update_version = false

  subnet_ids = [
    aws_subnet.priv_subnet_1.id,
    aws_subnet.priv_subnet_2.id,
    aws_subnet.priv_subnet_3.id
  ]
  instance_types = var.eks_node_group_type

  scaling_config {
    desired_size = var.eks_cluster_scaling_desired
    max_size     = var.eks_cluster_scaling_max
    min_size     = var.eks_cluster_scaling_min
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_1,
    aws_iam_role_policy_attachment.eks_nodes_2,
    aws_iam_role_policy_attachment.eks_nodes_3,
    aws_iam_role_policy_attachment.eks_nodes_4,
    aws_iam_role_policy_attachment.eks_nodes_5,
    aws_iam_role_policy_attachment.eks_nodes_6
  ]
}

########
# IAM role and policy attachment for EKS Nodes
########
resource "aws_iam_role" "eks_nodes" {
  name = "eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_nodes_1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

#######
# ALB Controller IAM Policy
########
resource "aws_iam_policy" "alb_ingress_controller" {
  name        = "alb-ingress-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "ec2:GetSecurityGroupsForVpc",
                "ec2:DescribeIpamPools",
                "ec2:DescribeRouteTables",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags",
                "elasticloadbalancing:DescribeTrustStores",
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:DescribeCapacityReservation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:ModifyListenerAttributes",
                "elasticloadbalancing:ModifyCapacityReservation",
                "elasticloadbalancing:ModifyIpPools"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "StringEquals": {
                    "elasticloadbalancing:CreateAction": [
                        "CreateTargetGroup",
                        "CreateLoadBalancer"
                    ]
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule",
                "elasticloadbalancing:SetRulePriorities"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

#######
# ALB Controller IAM Role
########

resource "aws_iam_role" "aws_ingress_controller" {
  name = "aws-load-balancer-controller-${aws_eks_cluster.eks_cluster.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.eks.url}:sub" = "system:serviceaccount:kube-system:${local.alb_controller_sa_name}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_ingress_controller_attach" {
  role       = aws_iam_role.aws_ingress_controller.name
  policy_arn = aws_iam_policy.alb_ingress_controller.arn
}

resource "aws_iam_role_policy_attachment" "eks_nodes_4" {
  policy_arn = aws_iam_policy.alb_ingress_controller.arn
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_5" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_6" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodes.name
}

#######
# Cloudwatch - K8s
########
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.eks_cluster_name}/cluster"
  retention_in_days = var.eks_log_retention_in_days

  tags_all = var.tags
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = "/aws/eks/${local.eks_cluster_name}/logs"
  retention_in_days = var.eks_log_retention_in_days

  tags_all = var.tags
}

########
# VPC CNI
########
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

########
# Secret Manager - Camunda (add manually the secrets value after pod deployment)
########
resource "aws_secretsmanager_secret" "camunda_secret_manager" {
  name        = "${local.namespace}/camunda/credentials"
  description = "Camunda web credentials"
}

resource "aws_secretsmanager_secret_policy" "camunda_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.camunda_secret_manager.arn

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
# Secret Manager - MIL Auth (add manually the secrets value after pod deployment)
########
resource "aws_secretsmanager_secret" "mil_secret_manager" {
  name        = "${local.namespace}/mil-auth/credentials"
  description = "MIL Auth credentials"
}

resource "aws_secretsmanager_secret_policy" "mil_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.mil_secret_manager.arn

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
# Secret Manager - idPay (add manually the secrets value after pod deployment)
########
resource "aws_secretsmanager_secret" "idpay_secret_manager" {
  name        = "${local.namespace}/idpay/credentials"
  description = "idPay API Key"
}

resource "aws_secretsmanager_secret_policy" "idpay_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.idpay_secret_manager.arn

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
# Secret Manager - node (add manually the secrets value after pod deployment)
########
resource "aws_secretsmanager_secret" "node_secret_manager" {
  name        = "${local.namespace}/node/credentials"
  description = "node API Key"
}

resource "aws_secretsmanager_secret_policy" "node_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.node_secret_manager.arn

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
# Secret Manager - node (add manually the secrets value after pod deployment)
########
resource "aws_secretsmanager_secret" "reporting_secret_manager" {
  name        = "${local.namespace}/reporting/credentials"
  description = "reporting API Key"
}

resource "aws_secretsmanager_secret_policy" "reporting_secret_manager_policy" {
  secret_arn = aws_secretsmanager_secret.reporting_secret_manager.arn

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