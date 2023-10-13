// karpenter node/worker IAM role

resource "aws_iam_instance_profile" "karpenter_node" {
  name = aws_iam_role.karpenter_node.name
  role = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role" "karpenter_node" {
  name = format("%s-%s-karpenter-node", local.name, var.region)

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
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node.name
}

// karpenter CRDs

resource "kubernetes_manifest" "karpenter_aws_node_template" {
  manifest = yamldecode(templatefile(format("%s/templates/karpenter/aws_node_template.yaml", path.module), {
    iam_role           = aws_iam_role.karpenter_node.name
    subnet_ids         = join(",", [for s in var.subnets : s.id])
    security_group_ids = aws_security_group.node.id
  }))
}

resource "kubernetes_manifest" "karpenter_provisioner" {
  manifest = yamldecode(templatefile(format("%s/templates/karpenter/provisioner.yaml", path.module), {
  }))
}
