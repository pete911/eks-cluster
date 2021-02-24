data "aws_ami" "eks_node" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.19-v20210208"]
  }
}
