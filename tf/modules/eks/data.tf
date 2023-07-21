data "aws_ami" "eks_node" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = [format("amazon-eks-node-%s-*", var.eks_version)]
  }
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
