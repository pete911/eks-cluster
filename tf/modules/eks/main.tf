resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.eks_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    endpoint_public_access  = length(var.public_access_cidrs) == 0 ? false : true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
    subnet_ids              = var.subnet_ids
  }

  tags = {
    Name = var.cluster_name
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_launch_template" "cluster" {
  for_each = var.node_groups

  name                   = each.key
  instance_type          = each.value.instance_type
  vpc_security_group_ids = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  image_id               = data.aws_ami.eks_node.image_id

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.node.arn
  }

  user_data = base64encode(templatefile(format("%s/templates/user_data.tpl", path.module), {
    cluster_name      = var.cluster_name
    endpoint          = aws_eks_cluster.this.endpoint
    cluster_ca_base64 = aws_eks_cluster.this.certificate_authority[0].data
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name                                                 = format("%s-%s", local.name, each.key)
      type                                                 = local.type_tag
      format("kubernetes.io/cluster/%s", var.cluster_name) = "owned"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = format("%s-%s", local.name, each.key)
      type = local.type_tag
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_autoscaling_group" "cluster" {
  for_each = var.node_groups

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [suspended_processes, load_balancers, target_group_arns]
  }

  name             = format("%s-%s", local.name, each.key)
  desired_capacity = each.value.desired_size
  max_size         = each.value.max_size
  min_size         = each.value.min_size

  launch_template {
    id      = aws_launch_template.cluster[each.key].id
    version = "$Latest"
  }

  vpc_zone_identifier = var.subnet_ids

  tag {
    key                 = "Name"
    value               = format("%s-%s", local.name, each.key)
    propagate_at_launch = true
  }

  tag {
    key                 = "type"
    value               = local.type_tag
    propagate_at_launch = true
  }
}
