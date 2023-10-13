// global node settings, applicable for karpenter nodes and karpenter controller nodes as well

resource "aws_security_group" "node" {
  name        = format("%s-eks-node", var.cluster_name)
  vpc_id      = var.vpc_id
  description = "eks cluster all nodes"

  tags = {
    Name    = format("%s-eks-node", var.cluster_name)
    cluster = local.name
    type    = local.type_tag

    "karpenter.sh/discovery" = aws_eks_cluster.this.name
  }
}

resource "aws_security_group_rule" "node_ingress_kubelet" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow additional traffic from control plane"
}

resource "aws_security_group_rule" "node_ingress_control_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic from control plane"
}

resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.node.id
  self              = true
  description       = "allow traffic from other nodes"
}

resource "aws_security_group_rule" "node_egress_control_plane" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic to control plane"
}

resource "aws_security_group_rule" "node_egress_ntp" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow traffic to ntp"
}

resource "aws_security_group_rule" "node_egress_internet" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow traffic to internet"
}

resource "aws_security_group_rule" "node_egress_self" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.node.id
  self              = true
  description       = "allow traffic to other nodes"
}
