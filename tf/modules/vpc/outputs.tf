output "vpc_id" {
  description = "The IDs of vpc"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "The IDs of private subnets"
  value       = [for s in aws_subnet.private : s.id]
}

output "nat_gateway_cidrs" {
  description = "NAT Gateways elastic IPs CIDR blocks (IP/32)"
  value = [for ip in aws_eip.nat : format("%s/32", ip.public_ip)]
}
