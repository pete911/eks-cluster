locals {
  cloudwatch_log_group = format("/aws/eks/%s/flow-log", var.cluster_name)
}
