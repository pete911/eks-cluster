// karpenter node group

resource "aws_eks_node_group" "karpenter_controller" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "karpenter-controller"
  node_role_arn   = aws_iam_role.karpenter_controller_node.arn
  subnet_ids      = [for subnet in var.subnets : subnet.id]

  taint {
    effect = "NO_SCHEDULE"
    key    = "CriticalAddonsOnly"
  }

  scaling_config {
    desired_size = var.karpenter_controller_node_group.desired_size
    max_size     = var.karpenter_controller_node_group.max_size
    min_size     = var.karpenter_controller_node_group.min_size
  }

  launch_template {
    id      = aws_launch_template.karpenter_controller.id
    version = aws_launch_template.karpenter_controller.latest_version
  }

  tags = {
    Name    = "karpenter-controller"
    cluster = local.name
    type    = local.type_tag
  }

  lifecycle {
    ignore_changes = [scaling_config["desired_size"]]
  }

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.karpenter_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.karpenter_AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_launch_template" "karpenter_controller" {
  name                   = format("%s-karpenter-controller", local.name)
  default_version        = var.karpenter_controller_node_group.launch_template_version
  instance_type          = var.karpenter_controller_node_group.instance_type
  vpc_security_group_ids = [aws_security_group.node.id]
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
      Name    = "karpenter-controller"
      cluster = local.name
      type    = local.type_tag
    }
  }
}

// karpenter controller node role

resource "aws_iam_role" "karpenter_controller_node" {
  name = format("%s-%s-karpenter-controller-node", local.name, var.region)

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

resource "aws_iam_role_policy_attachment" "karpenter_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_controller_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_controller_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_controller_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_controller_node.name
}

resource "aws_iam_role_policy_attachment" "ebs_csi_AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.karpenter_controller_node.name
}

// karpenter namespace

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = local.karpenter_namespace
  }
}

// karpenter controller role (used by karpenter service account)

resource "aws_iam_role" "karpenter_controller_svc_acc" {
  name = format("%s-%s-karpenter-controller", local.name, var.region)
  assume_role_policy = templatefile(format("%s/templates/assume_role_policy.json", path.module), {
    openid_arn      = aws_iam_openid_connect_provider.cluster.arn
    openid_url      = aws_iam_openid_connect_provider.cluster.url
    namespace       = local.karpenter_namespace
    service_account = "karpenter"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_controler_AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_controller_svc_acc.name
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v0.31.1"
  namespace  = local.karpenter_namespace

  values = [templatefile(format("%s/templates/karpenter/values.yaml", path.module), {
    svc_acc_role_arn = aws_iam_role.karpenter_controller_svc_acc.arn
    cluster_name     = aws_eks_cluster.this.name
    cluster_endpoint = aws_eks_cluster.this.endpoint
    instance_profile = aws_iam_instance_profile.karpenter_node.name
  })]
}

// ebs csi controller role (used by ebs csi service account)

resource "aws_iam_role" "ebs_csi_controller_svc_acc" {
  name = format("%s-%s-ebs-csi-controller", local.name, var.region)
  assume_role_policy = templatefile(format("%s/templates/assume_role_policy.json", path.module), {
    openid_arn      = aws_iam_openid_connect_provider.cluster.arn
    openid_url      = aws_iam_openid_connect_provider.cluster.url
    namespace       = "kube-system"
    service_account = "ebs-csi-controller-sa"
  })

  inline_policy {
    name = "controller"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ssm:GetParameter",
            "iam:PassRole",
            "ec2:DescribeImages",
            "ec2:RunInstances",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeAvailabilityZones",
            "ec2:DeleteLaunchTemplate",
            "ec2:CreateTags",
            "ec2:CreateLaunchTemplate",
            "ec2:CreateFleet",
            "ec2:DescribeSpotPriceHistory",
            "eks:DescribeCluster",
            "pricing:GetProducts"
          ]
          Effect   = "Allow"
          Resource = "*"
          Sid      = "Karpenter"
        },
        {
          Action = ["ec2:TerminateInstances"]
          Condition = {
            "StringLike" = {
              "ec2:ResourceTag/Name" : "*karpenter*"
            }
          }
          Effect   = "Allow"
          Resource = "*"
          Sid      = "ConditionalEC2Termination"
        },
      ]
    })
  }
}

resource "helm_release" "ebs_csi" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.24.1"

  values = [templatefile(format("%s/templates/ebs_csi/values.yaml", path.module), {
    svc_acc_role_arn = aws_iam_role.ebs_csi_controller_svc_acc.arn
  })]
}
