resource "aws_vpc_endpoint" "ecr" {
  vpc_id              = var.vpc_id
  service_name        = format("com.amazonaws.%s.ecr.dkr", var.region)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.control_plane.id]
  subnet_ids          = [for subnet in var.subnets : subnet.id]

  tags = {
    Name = local.name
    type = local.type_tag
  }
}

# image content is stored on S3
resource "aws_vpc_endpoint" "s3_ecr" {
  vpc_id            = var.vpc_id
  service_name      = format("com.amazonaws.%s.s3", var.region)
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for subnet in var.subnets : subnet.route_table_id]
  policy            = templatefile(format("%s/templates/s3_ecr_policy.json", path.module), { region = var.region })
}

resource "aws_ecr_repository" "this" {
  for_each = var.ecr_repositories

  name                 = format("%s/%s", local.name, each.value)
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = local.name
    type = local.type_tag
  }
}

resource "aws_ecr_registry_scanning_configuration" "this" {
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "SCAN_ON_PUSH"
    repository_filter {
      filter      = local.name
      filter_type = "WILDCARD"
    }
  }
}
