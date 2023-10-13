terraform {
  required_version = "~> 1.5.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  profile = "auriga_test"
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  profile = "auriga_test"
  alias = "ireland"

  region = var.aws_secondary_region

  default_tags {
    tags = var.tags
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.kubernetes.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.kubernetes.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.kubernetes.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.kubernetes.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.kubernetes.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.kubernetes.token
  }
}

locals {
  project    = format("%s-%s", var.app_name, var.env_short)
  namespace  = format("pagopa-%s-%s", var.environment, var.app_name)  # pagopa-dev-atm-layer
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "kubernetes" {
  name       = "${local.namespace}-${var.eks_cluster_name}"
  depends_on = [aws_eks_cluster.eks_cluster]
}

data "aws_eks_cluster" "kubernetes" {
  name       = "${local.namespace}-${var.eks_cluster_name}"
  depends_on = [aws_eks_cluster.eks_cluster]
}
