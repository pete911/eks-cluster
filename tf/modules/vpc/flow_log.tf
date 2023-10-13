resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
  log_format      = "$${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${flow-direction} $${traffic-path}"
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = local.cloudwatch_log_group
  retention_in_days = 60

  tags = {
    Name = format("eks-%s", var.cluster_name)
    type = "eks-cluster"
  }
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flow_log" {
  name               = format("%s-%s-flow-log-cloudwatch", var.cluster_name, var.region)
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json

  inline_policy {
    name = "flow-log-cloudwatch"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
          ]
          Effect   = "Allow"
          Resource = format("arn:aws:logs:%s:%s:log-group:*", var.region, data.aws_caller_identity.current.account_id)
        },
      ]
    })
  }
}

resource "aws_cloudwatch_query_definition" "kubelet" {
  name            = "flow-log-reject"
  log_group_names = [local.cloudwatch_log_group]
  query_string    = <<EOF
fields @timestamp, instanceId, interfaceId, srcAddr, srcPort, dstAddr, dstPort
| filter (action="REJECT")
| sort @timestamp desc
| limit 50
EOF
}
