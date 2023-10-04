# Terraform for EKS cluster

Terraform is in [tf](tf) directory (`cd tf`):
 - initialize and validate
   - `terraform init`
   - `terraform validate`
   - `terraform plan`
 - apply (replace `<your-IP>`) `terraform apply -var='public_access_cidrs=["<your-IP>/32"]'`
 - destroy `tf destroy`

## AWS VPC

VPC name is `eks-<cluster>` (`<cluster>` defaults to `main` and can be changed with `cluster_name` variable). Default
VPC address is `10.0.0.0` (can be changed with `vpc_address` variable) and VPC netmask is `/22`.

### subnets

We create 3 public and 3 private subnets in different availability zones. Each public subnet has
[NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) with elastic IP to be used by
private subnets for internet traffic.

| Name                     | Type     | AZ | CIDR          | Hosts | Address    | Broadcast  | Host Min      | Host Max   |
|--------------------------|----------| -- |---------------|-------| ---------- |------------| ------------- |------------|
| eks-\<cluster>-private-a | private  | a  | 10.0.0.0/24   | 254   | 10.0.0.0   | 10.0.0.255 | 10.0.0.1      | 10.0.0.254 |
| eks-\<cluster>-private-b | private  | b  | 10.0.1.0/24   | 254   | 10.0.1.0   | 10.0.1.255 | 10.0.1.1      | 10.0.1.254 |
| eks-\<cluster>-private-c | private  | c  | 10.0.2.0/24   | 254   | 10.0.2.0   | 10.0.2.255 | 10.0.2.1      | 10.0.2.254 |
| eks-\<cluster>-public-a  | public   | a  | 10.0.3.0/26   | 62    | 10.0.3.0   | 10.0.3.63  | 10.0.3.1      | 10.0.3.62  |
| eks-\<cluster>-public-b  | public   | b  | 10.0.3.64/26  | 62    | 10.0.3.64  | 10.0.3.127 | 10.0.3.65     | 10.0.3.126 |
| eks-\<cluster>-public-c  | public   | c  | 10.0.3.128/26 | 62    | 10.0.3.128 | 10.0.3.191 | 10.0.3.129    | 10.0.3.190 |


<p align="center">
  <img alt="eks cluster diagram" src="docs/images/eks-cluster.png">
</p>

## AWS EKS cluster

Cluster name defaults to `main` (can be changed with `cluster_name` variable). Cluster has a public endpoint open to all 
traffic (`0.0.0.0/0`) by default, it is strongly encouraged to change this to list of allowed CIDRs using
`public_access_cidrs` variable: `terraform apply -var='public_access_cidrs=["<your-IP>/32"]'`

We prefix AWS IAM role for a cluster with region (so it doesn't clash if you have a cluster with the same name in
multiple regions). IAM role name is in `<region>-eks-<cluster>` format.
