output "endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "AWS eks cluster endpoint"
}

output "ca" {
  value       = aws_eks_cluster.this.certificate_authority.0.data
  description = "AWS eks cluster certificate authority"
}

output "openid_cluster_arn" {
  value       = aws_iam_openid_connect_provider.cluster.arn
  description = "AWS eks iam openid connect cluster arn"
}

output "openid_cluster_url" {
  value       = aws_iam_openid_connect_provider.cluster.url
  description = "AWS eks iam openid connect cluster url"
}
