resource "aws_cloudwatch_log_group" "prometheus" {
  name              = format("/aws/eks/%s/prometheus-log", var.cluster_name)
  retention_in_days = 60

  tags = {
    Name    = format("eks-%s", var.cluster_name)
    cluster = local.name
    type    = "eks-cluster"
  }
}

resource "aws_prometheus_workspace" "this" {
  alias = local.name

  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.prometheus.arn}:*"
  }

  tags = {
    Name    = local.name
    cluster = local.name
    type    = local.type_tag
  }
}

resource "aws_prometheus_rule_group_namespace" "this" {
  name         = "rules"
  workspace_id = aws_prometheus_workspace.this.id
  data         = <<EOF
groups:
  - name: test
    rules:
    - record: metric:recording_rule
      expr: avg(rate(container_cpu_usage_seconds_total[5m]))
EOF
}

resource "aws_prometheus_alert_manager_definition" "this" {
  workspace_id = aws_prometheus_workspace.this.id
  definition   = <<EOF
alertmanager_config: |
  route:
    receiver: 'default'
  receivers:
    - name: 'default'
EOF
}

resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = local.prometheus_namespace
  }
}

resource "aws_iam_role" "prometheus" {
  name = format("%s-%s-prometheus", local.name, var.region)
  assume_role_policy = templatefile(format("%s/templates/assume_role_policy.json", path.module), {
    openid_arn      = aws_iam_openid_connect_provider.cluster.arn
    openid_url      = aws_iam_openid_connect_provider.cluster.url
    namespace       = local.prometheus_namespace
    service_account = "amp-iamproxy-ingest-service-account"
  })

  inline_policy {
    name = "controller"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "aps:RemoteWrite",
            "aps:GetSeries",
            "aps:GetLabels",
            "aps:GetMetricMetadata"
          ]
          Effect   = "Allow"
          Resource = "*"
          Sid      = "Prometheus"
        }
      ]
    })
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "25.0.0"
  namespace  = local.prometheus_namespace

  values = [templatefile(format("%s/templates/prometheus/values.yaml", path.module), {
    role_arn     = aws_iam_role.prometheus.arn
    workspace_id = aws_prometheus_workspace.this.id
    region       = var.region
  })]
}
