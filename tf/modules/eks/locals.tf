locals {
  name     = format("eks-%s", var.cluster_name)
  type_tag = "eks-cluster"

  kubeconfig = templatefile(format("%s/templates/kubeconfig.tpl", path.module), {
    kubeconfig_name   = format("%s.%s", var.region, var.cluster_name)
    region            = var.region
    cluster_name      = var.cluster_name
    endpoint          = aws_eks_cluster.this.endpoint
    cluster_ca_base64 = aws_eks_cluster.this.certificate_authority[0].data
  })
}
