variable "cluster_name" {
  type        = string
  description = "AWS EKS cluster name"
}

variable "eks_version" {
  type        = string
  description = "AWS EKS Kubernetes version"
  default     = "1.23"
}

variable "node_groups" {
  type = map(object({
    launch_template_version : string
    instance_type : string
    desired_size : number
    max_size : number
    min_size : number
  }))
  description = "AWS EKS node groups, where key is the node group name. Launch template version is the version to use for node group"
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

variable "subnet_ids" {
  type        = list(string)
  description = "AWS subnets for kubernetes worker nodes"
}

variable "system_master_roles" {
  type        = list(string)
  description = "role names for kubernetes system:master groups"
  default     = ["admin"]
}
