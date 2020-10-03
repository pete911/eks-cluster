output "kubeconfig" {
  description = "AWS EKS cluster kubeconfig file"
  value       = module.eks.kubeconfig
}
