########
# Secrets store - CSI driver
########
resource "helm_release" "csi_secrets_store" {
  name       = "csi-secrets-store"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.3.4"

  depends_on = [ aws_eks_cluster.eks_cluster ]
}

resource "helm_release" "secrets_provider_aws" {
  name       = "secrets-provider-aws"
  namespace  = "kube-system"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = "0.3.4"

  depends_on = [ helm_release.csi_secrets_store ]
}
