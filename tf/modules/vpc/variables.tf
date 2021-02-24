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

variable "firewall_allow_list" {
  type        = set(string)
  description = "Set of allowed domain names"
}

variable "firewall_enable_logging" {
  type        = bool
  default     = false
  description = "Controls whether to enable firewall dropped packets logging"
}
