output "cluster_endpoint" {
  description = "AWS EKS cluster API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate" {
  description = "AWS EKS cluster endpoint certificate"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}
