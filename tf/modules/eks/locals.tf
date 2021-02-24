locals {
  name                       = format("eks-%s", var.cluster_name)
  type_tag                   = "eks-cluster"
  ssh_security_group_id      = length(aws_security_group.cluster_ssh) == 0 ? "" : aws_security_group.cluster_ssh[0].id
  cluster_security_group_id  = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  vpc_security_group_ids     = compact([local.ssh_security_group_id, local.cluster_security_group_id])

  kubeconfig = templatefile(format("%s/templates/kubeconfig.tpl", path.module), {
    kubeconfig_name   = format("%s.%s", var.region, var.cluster_name)
    region            = var.region
    cluster_name      = var.cluster_name
    endpoint          = aws_eks_cluster.this.endpoint
    cluster_ca_base64 = aws_eks_cluster.this.certificate_authority[0].data
  })
}
