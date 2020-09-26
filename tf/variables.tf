variable "region" {
  description = "AWS Region to use"
  default     = "eu-west-2"
}

variable "vpc_address" {
  description = "AWS VPC address for EKS cluster (CIDR block without netmask)"
  default     = "10.0.0.0"
}

variable "cluster_name" {
  description = "AWS EKS cluster name"
  default     = "main"
}
