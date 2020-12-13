data "aws_ami" "eks_node" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.18-v20201126"]
  }
}
