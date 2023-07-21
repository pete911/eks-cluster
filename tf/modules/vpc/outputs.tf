output "vpc_id" {
  description = "The IDs of vpc"
  value       = aws_vpc.this.id
}

output "private_subnets" {
  value       = [for k, v in local.public_subnets : { id = aws_subnet.private[k].id, route_table_id = aws_route_table.private[k].id }]
  description = "The private subnets"
}

output "nat_gateway_cidrs" {
  description = "NAT Gateways elastic IPs CIDR blocks (IP/32)"
  value       = [for ip in aws_eip.nat : format("%s/32", ip.public_ip)]
}
