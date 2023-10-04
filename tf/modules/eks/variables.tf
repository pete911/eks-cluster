variable "cluster_name" {
  type        = string
  description = "AWS EKS cluster name"
}

variable "eks_version" {
  type        = string
  description = "AWS EKS Kubernetes version"
}

variable "karpenter_node_group" {
  type = object({
    launch_template_version : string
    instance_type : string
    desired_size : number
    max_size : number
    min_size : number
  })
  description = "node group for karpenter controller and webhook"
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks that can access the Amazon EKS public API server endpoint"
}

variable "region" {
  type        = string
  description = "AWS Region to use"
}

variable "vpc_id" {
  type        = string
  description = "AWS vpc for kubernetes worker nodes"
}

variable "subnets" {
  type = list(object({
    id: string
    route_table_id: string
  }))
  description = "AWS subnets for kubernetes worker nodes"
}
