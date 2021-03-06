variable "cluster_name" {
  description = "AWS EKS cluster name"
  default     = "main"
}

variable "node_groups" {
  type = map(object({
    launch_template_version : string
    instance_type : string
    desired_size : number
    max_size : number
    min_size : number
  }))
  description = "AWS EKS node groups, where key is the node group name"
  default = {
    "default" = {
      launch_template_version : 1
      instance_type : "t2.small"
      desired_size : 1
      max_size : 3
      min_size : 1
    }
  }
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks can access the Amazon EKS public API server endpoint"
  default     = ["0.0.0.0/0"]
}

variable "region" {
  description = "AWS Region to use"
  default     = "eu-west-1"
}

variable "vpc_address" {
  description = "AWS VPC address for EKS cluster (CIDR block without netmask)"
  default     = "10.0.0.0"
}
