# Terraform for EKS cluster

Instead of using [terraform-aws-eks module](https://github.com/terraform-aws-modules/terraform-aws-eks), project uses
only terraform aws provider resources to avoid complexity and increase readability. Also, to make it easy to make
updates and changes.

Terraform is in [tf](tf) directory (`cd tf`):
 - initialize and validate
   - `terraform init`
   - `terraform validate`
   - `terraform plan`
 - apply `terraform apply`
 - destroy `tf destroy`

## AWS VPC

VPC name is `eks-<cluster>` (`<cluster>` defaults to `main` and can be changed with `cluster_name` variable). Default
VPC address is `10.0.0.0` (can be changed with `vpc_address` variable) and VPC netmask is `/24`.

### subnets

| Name                        | AZ  | CIDR            | From         | To           |
| --------------------------- | --- | --------------- | ------------ | ------------ |
| eks-\<cluster>-private-a    | a   | 10.0.0.0/26     | 10.0.0.0     | 10.0.0.63    |
| eks-\<cluster>-private-b    | b   | 10.0.0.64/26    | 10.0.0.64    | 10.0.0.127   |
| eks-\<cluster>-private-c    | c   | 10.0.0.128/26   | 10.0.0.128   | 10.0.0.191   |
| --------------------------- | --- | --------------- | ------------ | ------------ |
| eks-\<cluster>-protected-a  | a   | 10.0.0.192/29   | 10.0.0.192   | 10.0.0.199   |
| eks-\<cluster>-protected-b  | b   | 10.0.0.200/29   | 10.0.0.200   | 10.0.0.207   |
| eks-\<cluster>-protected-c  | c   | 10.0.0.208/29   | 10.0.0.208   | 10.0.0.215   |
| --------------------------- | --- | --------------- | ------------ | ------------ |
| eks-\<cluster>-firewall-a   | a   | 10.0.0.216/29   | 10.0.0.216   | 10.0.0.223   |
| eks-\<cluster>-firewall-b   | b   | 10.0.0.224/29   | 10.0.0.224   | 10.0.0.231   |
| eks-\<cluster>-firewall-c   | c   | 10.0.0.232/29   | 10.0.0.232   | 10.0.0.239   |

Cluster uses [aws network firewall](https://aws.amazon.com/blogs/networking-and-content-delivery/deployment-models-for-aws-network-firewall/)
deployed to `firewall` subnets. In addition, we create 3 private and 3 protected subnets for the cluster. 

<p align="center">
  <img src="https://d2908q01vomqb2.cloudfront.net/5b384ce32d8cdef02bc3a139d4cac0a22bb029e8/2020/11/18/anfw-public-igw-deployment-high-res1-1-1.png">
</p>

## AWS EKS cluster

Cluster name defaults to `main` (can be changed with `cluster_name` variable). Cluster has a public endpoint open to all 
traffic (`0.0.0.0/0`) by default, it is strongly encouraged to change this to list of allowed CIDRs using
`public_access_cidrs` variable: `terraform apply -var='public_access_cidrs=["<your-IP>/32"]'`

We prefix AWS IAM role for a cluster with region (so it doesn't clash if you have a cluster with the same name in
multiple regions). IAM role name is in `<region>-eks-<cluster>` format.

### Node groups

By default, we create one `default` node group with `t2.small` instances. Update [tf/variables.tf](tf/variables.tf) file
to change defaults. Node groups use launch template, so we have managed EKS nodes, but with custom images. To update
image, but let AWS roll the nodes, update launch template (e.g change instance type) and then set node groups launch
template version to the one you want to use.
