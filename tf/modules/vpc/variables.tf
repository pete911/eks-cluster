variable "cluster_name" {
  type        = string
  description = "AWS EKS cluster name"
  default     = ""
}

variable "region" {
  type        = string
  description = "AWS Region to use"
}

variable "vpc_address" {
  type        = string
  description = "AWS VPC address for EKS cluster (CIDR block without netmask)"
}
