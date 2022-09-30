resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = "1.23"
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

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  launch_template {
    id      = aws_launch_template.cluster[each.key].id
    version = aws_launch_template.cluster[each.key].default_version
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

resource "aws_launch_template" "cluster" {
  for_each = var.node_groups

  name                   = each.key
  default_version        = each.value.launch_template_version
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
