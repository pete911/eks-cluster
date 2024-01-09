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
    Name = var.cluster_name
    type = local.type_tag
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_security_group" "control_plane" {
  name        = format("%s-eks-control-plane", var.cluster_name)
  vpc_id      = var.vpc_id
  description = "eks cluster control plane"

  tags = {
    Name                         = local.name
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
  source_security_group_id = aws_security_group.node_groups.id
  description              = "allow traffic from worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker_extra" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node_groups.id
  description              = "allow traffic to worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node_groups.id
  description              = "allow traffic to worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker_tcp_dns" {
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node_groups.id
  description              = "allow dns traffic to worker nodes"
}

resource "aws_security_group_rule" "control_plane_egress_worker_udp_dns" {
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node_groups.id
  description              = "allow dns traffic to worker nodes"
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for subnet in var.subnets : subnet.id]

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  launch_template {
    id      = aws_launch_template.cluster[each.key].id
    version = aws_launch_template.cluster[each.key].latest_version
  }

  tags = {
    Name = format("%s-%s", local.name, each.key)
    type = local.type_tag
  }

  lifecycle {
    ignore_changes = [scaling_config["desired_size"]]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_autoscaling_schedule" "scale_down" {
  for_each = toset([for k, v in var.node_groups : k if v.ooo_shut_down])

  autoscaling_group_name = aws_eks_node_group.this[each.value].resources[0].autoscaling_groups[0].name
  scheduled_action_name  = "scale down (week)"

  desired_capacity = 0
  max_size         = 0
  min_size         = 0
  recurrence       = "0 22 * * MON-FRI"
}

resource "aws_autoscaling_schedule" "scale_up" {
  for_each = toset([for k, v in var.node_groups : k if v.ooo_shut_down])

  autoscaling_group_name = aws_eks_node_group.this[each.value].resources[0].autoscaling_groups[0].name
  scheduled_action_name  = "scale up (week)"

  desired_capacity = var.node_groups[each.value].desired_size
  max_size         = var.node_groups[each.value].max_size
  min_size         = var.node_groups[each.value].min_size
  recurrence       = "0 6 * * MON-FRI"
}

resource "aws_launch_template" "cluster" {
  for_each = var.node_groups

  name                   = format("%s-%s", local.name, each.key)
  default_version        = each.value.launch_template_version
  instance_type          = each.value.instance_type
  vpc_security_group_ids = [aws_security_group.node_groups.id]
  image_id               = data.aws_ami.eks_node.image_id

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }

  user_data = base64encode(templatefile(format("%s/templates/user_data.tpl", path.module), {
    cluster_name      = var.cluster_name
    endpoint          = aws_eks_cluster.this.endpoint
    cluster_ca_base64 = aws_eks_cluster.this.certificate_authority[0].data
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = format("%s-%s", local.name, each.key)
      type = local.type_tag
    }
  }
}

resource "aws_security_group" "node_groups" {
  name        = format("%s-eks-node-groups", var.cluster_name)
  vpc_id      = var.vpc_id
  description = "eks cluster all node groups"

  tags = {
    Name = local.name
    type = local.type_tag
  }
}

resource "aws_security_group_rule" "node_groups_ingress_control_plane_extra" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_groups.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic from control plane"
}

resource "aws_security_group_rule" "node_groups_ingress_control_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_groups.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic from control plane"
}

resource "aws_security_group_rule" "node_groups_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.node_groups.id
  self              = true
  description       = "allow traffic from other nodes"
}

resource "aws_security_group_rule" "node_groups_egress_control_plane" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_groups.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "allow traffic to control plane"
}

resource "aws_security_group_rule" "node_groups_egress_ecr_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.node_groups.id
  prefix_list_ids   = [aws_vpc_endpoint.s3_ecr.prefix_list_id]
  description       = "allow traffic to ecr s3"
}

resource "aws_security_group_rule" "node_groups_egress_ntp" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  security_group_id = aws_security_group.node_groups.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow traffic to ntp"
}

resource "aws_security_group_rule" "node_groups_egress_internet" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.node_groups.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow traffic to internet"
}

resource "aws_security_group_rule" "node_groups_egress_self" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.node_groups.id
  self              = true
  description       = "allow traffic to other nodes"
}
