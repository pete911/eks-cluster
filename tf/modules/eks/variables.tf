variable "cluster_name" {
  type        = string
  description = "AWS EKS cluster name"
}

variable "node_groups" {
  type = map(object({
    instance_type : string
    desired_size : number
    max_size : number
    min_size : number
  }))
  description = "AWS EKS nod groups, where key is the node group name"
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks can access the Amazon EKS public API server endpoint"
}

variable "region" {
  type        = string
  description = "AWS Region to use"
}

variable "subnet_ids" {
  type        = list(string)
  description = "AWS subnets for kubernets worker nodes"
}
