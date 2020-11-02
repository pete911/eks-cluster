provider "aws" {
  region = var.region
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  region       = var.region
  vpc_address  = var.vpc_address
}

module "eks" {
  source = "./modules/eks"

  cluster_name        = var.cluster_name
  node_groups         = var.node_groups
  public_access_cidrs = concat(var.public_access_cidrs, module.vpc.nat_gateway_cidrs)
  region              = var.region
  subnet_ids          = module.vpc.private_subnet_ids
}
