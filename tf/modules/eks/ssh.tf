resource "aws_key_pair" "cluster" {
  for_each = var.ssh_access

  key_name   = format("%s-%s", local.name, each.key)
  public_key = each.value.public_key

  tags = {
    Name = format("%s-%s", local.name, each.key)
    type = local.type_tag
  }
}
resource "aws_security_group" "cluster_ssh" {
  count = length(var.ssh_access) == 0 ? 0 : 1

  name        = format("%s-SSH", local.name)
  description = "Allow EKS cluster SSH access"

  tags = {
    Name = format("%s-SSH", local.name)
    type = local.type_tag
  }
}

resource "aws_security_group_rule" "cluster_ssh" {
  for_each = var.ssh_access

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [each.value.allowed_cidrs]
  security_group_id = aws_security_group.cluster_ssh[0].id
  description       = format("SSH access %s", each.key)
}
