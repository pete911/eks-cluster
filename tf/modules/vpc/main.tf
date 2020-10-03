locals {
  vpc_cidr = format("%s/24", var.vpc_address)
  vpc_name = format("eks-%s", var.cluster_name)
  type_tag = "eks-cluster"
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

# --- VPC plus private and public subnets in 3 AZs ---

resource "aws_vpc" "this" {
  cidr_block = local.vpc_cidr

  tags = {
    Name = local.vpc_name
    type = local.type_tag
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = format("%s%s", var.region, each.key)

  tags = {
    Name = format("%s-private-%s", local.vpc_name, each.key)
    type = local.type_tag

    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = format("%s%s", var.region, each.key)

  tags = {
    Name = format("%s-public-%s", local.vpc_name, each.key)
    type = local.type_tag

    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# --- internet gateway ---

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = local.vpc_name
    type = local.type_tag
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = format("%s-public", local.vpc_name)
    type = local.type_tag
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# --- NAT gateway ---

resource "aws_eip" "nat" {
  for_each = local.public_subnets

  vpc = true

  tags = {
    Name = format("%s-%s", local.vpc_name, each.key)
    type = local.type_tag
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.public_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = format("%s-%s", local.vpc_name, each.key)
    type = local.type_tag
  }
}

resource "aws_route_table" "private" {
  for_each = local.public_subnets

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = {
    Name = format("%s-private-%s", local.vpc_name, each.key)
    type = local.type_tag
  }
}

resource "aws_route_table_association" "private" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
