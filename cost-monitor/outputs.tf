output "sns_topic_arn" {
  description = "Topic that Budgets and Cost Anomaly Detection publish to."
  value       = aws_sns_topic.cost_alerts.arn
}

output "slack_channel_configuration_arn" {
  description = "Channel configuration forwarding the topic to Slack."
  value       = aws_chatbot_slack_channel_configuration.cost_alerts.chat_configuration_arn
}
