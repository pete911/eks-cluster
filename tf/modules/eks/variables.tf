variable "cluster_name" {
  type        = string
  description = "AWS EKS cluster name"
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

variable "subnet_ids" {
  type        = list(string)
  description = "AWS subnets for kubernets worker nodes"
}

variable "ssh_access" {
  type = map(object({
    public_key : string
    allowed_cidrs : list(string)
  }))
  description = "SSH keys for EKS worker nodes, where key is the name"
}
