provider "aws" {
  region = var.region
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = format("eks-%s", var.cluster_name)
    type = "eks-cluster"
  }
}
