// node/worker IAM role

resource "aws_iam_role" "node" {
  name = format("%s-%s-node", local.name, var.region)

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

// node/worker security group

resource "aws_security_group" "node" {
  name        = format("%s-eks-node-groups", var.cluster_name)
  vpc_id      = var.vpc_id
  description = "eks cluster all node groups"

  tags = {
    Name    = local.name
    cluster = local.name
    type    = local.type_tag

    "karpenter.sh/discovery" = aws_eks_cluster.this.name
  }
}

resource "aws_security_group_rule" "node_groups_ingress_control_plane_extra" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic from control plane"
}

resource "aws_security_group_rule" "node_groups_ingress_control_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic from control plane"
}

resource "aws_security_group_rule" "node_groups_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.node.id
  self              = true
  description       = "allow traffic from other nodes"
}

resource "aws_security_group_rule" "node_groups_egress_control_plane" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic to control plane"
}

resource "aws_security_group_rule" "node_groups_egress_ntp" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow traffic to ntp"
}

resource "aws_security_group_rule" "node_groups_egress_internet" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow traffic to internet"
}

resource "aws_security_group_rule" "node_groups_egress_self" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.node.id
  self              = true
  description       = "allow traffic to other nodes"
}
