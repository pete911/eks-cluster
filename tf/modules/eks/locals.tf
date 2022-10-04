locals {
  name     = format("eks-%s", var.cluster_name)
  type_tag = "eks-cluster"

  node_roles = [
    {
      rolearn  = aws_iam_role.node.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }
  ]

  system_master_roles = [
    for role_name in var.system_master_role_names : {
      rolearn  = format("arn:aws:iam::%s:role/%s", data.aws_caller_identity.current.account_id, role_name)
      username = "{{SessionName}}"
      groups   = ["system:masters"]
    }
  ]

  auth_roles = concat(local.node_roles, local.system_master_roles)
  auth_users = []

  kubeconfig = templatefile(format("%s/templates/kubeconfig.tpl", path.module), {
    kubeconfig_name   = format("%s.%s", var.region, var.cluster_name)
    region            = var.region
    cluster_name      = var.cluster_name
    endpoint          = aws_eks_cluster.this.endpoint
    cluster_ca_base64 = aws_eks_cluster.this.certificate_authority[0].data
  })
}
