resource "aws_networkfirewall_rule_group" "allow_list" {
  name        = format("%s-allow-list", local.name)
  description = "allow domain list"
  capacity    = 1000
  type        = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.firewall_allow_list
      }
    }
  }

  tags = {
    Name = "allow-list"
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name        = local.name
  description = "allow domain list"
  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.allow_list.arn
    }
  }

  tags = {
    Name = local.name
  }
}

resource "aws_networkfirewall_firewall" "this" {
  name                = local.name
  description         = "allow domain list"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.this.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value["id"]
    }
  }

  tags = {
    Name = local.name
  }
}

resource "aws_cloudwatch_log_group" "firewall" {
  name              = format("firewall-%s", local.name)
  retention_in_days = 7

  tags = {
    Name = format("firewall-%s", var.cluster_name)
  }
}

resource "aws_networkfirewall_logging_configuration" "this" {
  count        = var.firewall_enable_logging ? 1 : 0
  firewall_arn = aws_networkfirewall_firewall.this.arn
  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}
