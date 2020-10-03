# Terraform for EKS cluster

Terraform is in [tf](tf) directory (`cd tf`):
 - `terraform init`
 - `terraform validate`
 - `terraform plan`
 - `terraform apply`

## vpc

VPC name is `eks-<cluster>` (`<cluster>` defaults to `main` and can be changed with `cluster_name` variable). Default
VPC address is `10.0.0.0` (can be changed with `vpc_address` variable) and VPC netmask is `/24`.

### subnets

We create 3 public and 3 private subnets in different availability zones. Each public subnet has
[NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) with elastic IP to be used by
private subnets for internet traffic.

| Name                      | Type    | AZ | CIDR          | Hosts | Address        | Broadcast     | Host Min      | Host Max      |
| ------------------------- | ------- | -- | ------------- | ----- | -------------- | ------------- | ------------- | ------------- |
| eks-\<cluster>-private-a  | private | a  | 10.0.0.0/26   | 62    | 10.0.0.0       | 10.0.0.63     | 10.0.0.1      | 10.0.0.62     |
| eks-\<cluster>-private-b  | private | b  | 10.0.0.64/26  | 62    | 10.0.0.64      | 10.0.0.127    | 10.0.0.65     | 10.0.0.126    |
| eks-\<cluster>-private-c  | private | c  | 10.0.0.128/26 | 62    | 10.0.0.128     | 10.0.0.191    | 10.0.0.129    | 10.0.0.190    |
| eks-\<cluster>-public-a   | public  | a  | 10.0.0.192/28 | 14    | 10.0.0.192     | 10.0.0.207    | 10.0.0.193    | 10.0.0.206    |
| eks-\<cluster>-public-b   | public  | b  | 10.0.0.208/28 | 14    | 10.0.0.208     | 10.0.0.223    | 10.0.0.209    | 10.0.0.222    |
| eks-\<cluster>-public-c   | public  | c  | 10.0.0.224/28 | 14    | 10.0.0.224     | 10.0.0.239    | 10.0.0.225    | 10.0.0.238    |
