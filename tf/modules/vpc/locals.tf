locals {
  vpc_cidr = format("%s/24", var.vpc_address)
  name     = format("eks-%s", var.cluster_name)
  type_tag = "eks-cluster"
  private_subnets = {
    a : cidrsubnet(local.vpc_cidr, 2, 0)
    b : cidrsubnet(local.vpc_cidr, 2, 1)
    c : cidrsubnet(local.vpc_cidr, 2, 2)
  }
  protected_subnets = {
    a : cidrsubnet(local.vpc_cidr, 5, 24)
    b : cidrsubnet(local.vpc_cidr, 5, 25)
    c : cidrsubnet(local.vpc_cidr, 5, 26)
  }
  firewall_subnets = {
    a : cidrsubnet(local.vpc_cidr, 5, 27)
    b : cidrsubnet(local.vpc_cidr, 5, 28)
    c : cidrsubnet(local.vpc_cidr, 5, 29)
  }
  firewall_sync_states = aws_networkfirewall_firewall.this.firewall_status[0].sync_states
}
