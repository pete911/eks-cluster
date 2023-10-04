variable "cluster_name" {
  description = "AWS EKS cluster name"
  default     = "main"
}

variable "eks_version" {
  type        = string
  description = "AWS EKS Kubernetes version"
  default     = "1.28"
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
  default = {
    launch_template_version : 1
    instance_type : "t3.medium"
    desired_size : 3
    max_size : 10
    min_size : 3
  }
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks can access the Amazon EKS public API server endpoint"
  default     = ["0.0.0.0/0"]
}

variable "region" {
  description = "AWS Region to use"
  default     = "eu-west-2"
}

variable "vpc_address" {
  description = "AWS VPC address for EKS cluster (CIDR block without netmask)"
  default     = "10.0.0.0"
}
