provider "aws" {
  region = var.region
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  region       = var.region
  vpc_address  = var.vpc_address
}
