variable "region" {
  description = "AWS Region to use"
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "AWS VPC CIDR block to create for EKS cluster"
  default     = "10.0.0.0/24"
}

variable "cluster_name" {
  description = "AWS EKS cluster name"
  default     = "main"
}
