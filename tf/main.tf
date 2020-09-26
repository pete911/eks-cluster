locals {
  vpc_cidr = format("%s/24", var.vpc_address)
  vpc_name = format("eks-%s", var.cluster_name)
  private_subnets = {
    a : cidrsubnet(local.vpc_cidr, 2, 0)
    b : cidrsubnet(local.vpc_cidr, 2, 1)
    c : cidrsubnet(local.vpc_cidr, 2, 2)
  }
  public_subnets = {
    a : cidrsubnet(local.vpc_cidr, 4, 12)
    b : cidrsubnet(local.vpc_cidr, 4, 13)
    c : cidrsubnet(local.vpc_cidr, 4, 14)
  }
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "this" {
  cidr_block = local.vpc_cidr

  tags = {
    Name = local.vpc_name
    type = "eks-cluster"

    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = format("%s%s", var.region, each.key)

  tags = {
    Name = format("%s-private-%s", local.vpc_name, each.key)
    type = "eks-cluster"

    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = format("%s%s", var.region, each.key)

  tags = {
    Name = format("%s-public-%s", local.vpc_name, each.key)
    type = "eks-cluster"

    "kubernetes.io/role/elb" = "1"
  }
}
