locals {
  name     = format("eks-%s", var.cluster_name)
  type_tag = "eks-cluster"
}
