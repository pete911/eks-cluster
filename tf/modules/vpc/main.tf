# --- VPC plus private and public subnets in 3 AZs ---

resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = local.name
    type = local.type_tag
  }
}

resource "aws_subnet" "firewall" {
  for_each = local.firewall_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = format("%s%s", var.region, each.key)

  tags = {
    Name = format("%s-firewall-%s", local.name, each.key)
  }
}

resource "aws_subnet" "protected" {
  for_each = local.protected_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = format("%s%s", var.region, each.key)

  tags = {
    Name = format("%s-protected-%s", local.name, each.key)
    type = local.type_tag

    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = format("%s%s", var.region, each.key)

  tags = {
    Name = format("%s-private-%s", local.name, each.key)
    type = local.type_tag

    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# --- internet gateway ---

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = local.name
    type = local.type_tag
  }
}

resource "aws_route_table" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = format("%s-igw", local.name)
    private = "true"
  }
}

resource "aws_route" "igw" {
  for_each = aws_subnet.protected

  route_table_id = aws_route_table.igw.id

  destination_cidr_block = each.value.cidr_block
  vpc_endpoint_id        = join("", [for s in local.firewall_sync_states : s.attachment[0].endpoint_id if s.availability_zone == each.value.availability_zone])

  depends_on = [aws_networkfirewall_firewall.this]
}

resource "aws_route_table_association" "igw" {
  route_table_id = aws_route_table.igw.id
  gateway_id     = aws_internet_gateway.this.id
}

# --- firewall route table ---

resource "aws_route_table" "firewall" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name   = format("%s-firewall", local.name)
    public = "true"
  }
}

resource "aws_route_table_association" "firewall" {
  for_each = local.firewall_subnets

  subnet_id      = aws_subnet.firewall[each.key].id
  route_table_id = aws_route_table.firewall.id
}

# --- protected route table ---

resource "aws_route_table" "protected" {
  for_each = aws_subnet.protected

  vpc_id = aws_vpc.this.id

  tags = {
    Name = format("%s-protected-%s", local.name, each.value.availability_zone)
    type = local.type_tag
  }
}

resource "aws_route" "protected" {
  for_each = aws_subnet.protected

  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.protected[each.key].id
  vpc_endpoint_id        = join("", [for s in local.firewall_sync_states : s.attachment[0].endpoint_id if s.availability_zone == each.value.availability_zone])

  depends_on = [aws_networkfirewall_firewall.this]
}

resource "aws_route_table_association" "protected" {
  for_each = local.protected_subnets

  subnet_id      = aws_subnet.protected[each.key].id
  route_table_id = aws_route_table.protected[each.key].id
}

# --- NAT gateway ---

resource "aws_eip" "nat" {
  for_each = local.protected_subnets

  vpc = true

  tags = {
    Name = format("%s-%s", local.name, each.key)
    type = local.type_tag
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.protected_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.protected[each.key].id

  tags = {
    Name = format("%s-%s", local.name, each.key)
    type = local.type_tag
  }
}

# --- private route table ---

resource "aws_route_table" "private" {
  for_each = local.protected_subnets

  vpc_id = aws_vpc.this.id

  tags = {
    Name    = format("%s-private-%s", local.name, each.key)
    type    = local.type_tag
    private = "true"
  }
}

resource "aws_route" "private" {
  for_each = local.protected_subnets

  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private[each.key].id
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = local.protected_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
