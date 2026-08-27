# AWS allows only one service-dimension anomaly monitor per account, and
# accounts that enabled Cost Explorer after March 2023 usually already have
# the auto-created "AWS Services" monitor. Set
# var.existing_anomaly_monitor_arn to reuse it instead of creating one.
resource "aws_ce_anomaly_monitor" "services" {
  count = var.existing_anomaly_monitor_arn == null ? 1 : 0

  name              = "${var.name_prefix}-service-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

locals {
  anomaly_monitor_arn = var.existing_anomaly_monitor_arn != null ? var.existing_anomaly_monitor_arn : one(aws_ce_anomaly_monitor.services[*].arn)
}

resource "aws_ce_anomaly_subscription" "immediate" {
  name             = "${var.name_prefix}-anomaly-alerts"
  frequency        = "IMMEDIATE" # SNS subscribers require IMMEDIATE
  monitor_arn_list = [local.anomaly_monitor_arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }

  # Only alert when the anomaly's total impact clears this floor,
  # so small blips don't page the channel.
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_impact_threshold_usd)]
    }
  }

  depends_on = [aws_sns_topic_policy.cost_alerts]
}

# Email leg for anomaly alerts. The AnomalySubscription API couples
# subscriber type to frequency — EMAIL is only valid with DAILY/WEEKLY, SNS
# only with IMMEDIATE — so email delivery needs this second subscription
# rather than an EMAIL subscriber on the immediate one.
resource "aws_ce_anomaly_subscription" "daily_email" {
  name             = "${var.name_prefix}-anomaly-email"
  frequency        = "DAILY"
  monitor_arn_list = [local.anomaly_monitor_arn]

  dynamic "subscriber" {
    for_each = toset(var.alert_email_addresses)

    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_impact_threshold_usd)]
    }
  }
}
