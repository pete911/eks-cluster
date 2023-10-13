resource "aws_iam_role" "cluster" {
  name                  = format("%s-%s-cluster", local.name, var.region)
  force_detach_policies = true
  assume_role_policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = {
    Name = local.name
    type = local.type_tag
  }
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.eks_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    endpoint_public_access  = length(var.public_access_cidrs) == 0 ? false : true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
    subnet_ids              = [for subnet in var.subnets : subnet.id]
    security_group_ids      = [aws_security_group.control_plane.id]
  }

  tags = {
    Name    = local.name
    cluster = local.name
    type    = local.type_tag
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

// control plane security group

resource "aws_security_group" "control_plane" {
  name        = format("%s-eks-control-plane", var.cluster_name)
  vpc_id      = var.vpc_id
  description = "eks cluster control plane"

  tags = {
    Name                         = format("%s-eks-control-plane", var.cluster_name)
    cluster                      = local.name
    "kubernetes.io/cluster/main" = "owned"
    type                         = local.type_tag
  }

  tags_all = {
    "aws:eks:cluster-name" = var.cluster_name
  }
}

resource "aws_security_group_rule" "control_plane_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
  description              = "allow traffic from worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker_extra" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
  description              = "allow traffic to worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
  description              = "allow traffic to worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker_tcp_dns" {
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
  description              = "allow dns traffic to worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker_udp_dns" {
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
  description              = "allow dns traffic to worker nodes"
}
