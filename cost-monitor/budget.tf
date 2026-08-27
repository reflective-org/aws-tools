resource "aws_budgets_budget" "monthly_total" {
  name         = "${var.name_prefix}-monthly-total"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Budgets validates publish permission against the topic at create time,
  # so the topic policy must exist before the budget does.
  depends_on = [aws_sns_topic_policy.cost_alerts]

  # Actual-spend alerts at each threshold (default 25/50/75/100%). AWS
  # allows at most 5 notifications per budget: up to 4 here plus the
  # forecast alert below.
  dynamic "notification" {
    for_each = toset(var.alert_thresholds)

    content {
      comparison_operator        = "GREATER_THAN"
      notification_type          = "ACTUAL"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
      subscriber_email_addresses = var.alert_email_addresses
    }
  }

  # Trajectory warning: month-end forecast exceeds budget. Budgets needs
  # roughly 5 weeks of usage history before it produces forecasts, so in a
  # new account this alert is silently inactive until then — the actual
  # thresholds above are the only coverage during warm-up.
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
    subscriber_email_addresses = var.alert_email_addresses
  }

  # To scope a budget to a single linked account (e.g. if the Glacier
  # backup account gets split out), copy this resource and add:
  #
  # cost_filter {
  #   name   = "LinkedAccount"
  #   values = ["222233334444"]
  # }
}
