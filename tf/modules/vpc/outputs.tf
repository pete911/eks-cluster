output "private_subnet_ids" {
  description = "The IDs of private subnets"
  value       = [for s in aws_subnet.private : s.id]
}
