locals {
  name     = format("eks-%s", var.cluster_name)
  type_tag = "eks-cluster"

  karpenter_namespace  = "karpenter"
  prometheus_namespace = "prometheus"
}
