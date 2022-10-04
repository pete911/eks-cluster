resource "kubernetes_config_map" "aws_auth_configmap" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.auth_roles)
    mapUsers = yamlencode(local.auth_users)
  }
}
