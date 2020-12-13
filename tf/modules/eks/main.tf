locals {
  name     = format("eks-%s", var.cluster_name)
  type_tag = "eks-cluster"

  kubeconfig = templatefile(format("%s/templates/kubeconfig.tpl", path.module), {
    kubeconfig_name   = format("%s.%s", var.region, var.cluster_name)
    region            = var.region
    cluster_name      = var.cluster_name
    endpoint          = aws_eks_cluster.this.endpoint
    cluster_ca_base64 = aws_eks_cluster.this.certificate_authority[0].data
  })
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
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
    cluster_name = var.cluster_name
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = format("%s-%s", local.name, each.key)
      type = local.type_tag
    }
  }
}

# --- EKS Service IAM ---
# https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html

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

# --- EKS Node IAM ---
# https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html

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

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}
