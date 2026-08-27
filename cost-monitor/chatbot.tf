# The Slack workspace OAuth authorization is the ONE step that can't be done
# in OpenTofu — it's an interactive grant. Authorize the workspace once in
# the console (Amazon Q Developer in chat applications -> Configure new
# client -> Slack); the channel configuration below fails until that's done.
# The workspace's team ID (var.slack_team_id) is shown there afterwards.

data "aws_iam_policy_document" "chatbot_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }

    # Deliberately no aws:SourceAccount/aws:SourceArn condition: Chatbot is
    # not documented to set either key on its AssumeRole calls (the
    # console-generated trust policy is unconditioned), and StringEquals
    # against an absent key silently denies every assumption.
  }
}

# Notifications-only channel role: CloudWatch read lets the channel render
# alarm context/graphs; nothing else is granted.
data "aws_iam_policy_document" "chatbot_notifications_only" {
  statement {
    sid    = "CloudWatchRead"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "chatbot_channel" {
  name               = "${var.name_prefix}-chatbot-channel"
  assume_role_policy = data.aws_iam_policy_document.chatbot_assume.json
}

resource "aws_iam_role_policy" "chatbot_channel" {
  name   = "notifications-only"
  role   = aws_iam_role.chatbot_channel.id
  policy = data.aws_iam_policy_document.chatbot_notifications_only.json
}

resource "aws_chatbot_slack_channel_configuration" "cost_alerts" {
  # The Chatbot API only has endpoints in a few regions (us-east-2,
  # us-west-2, eu-west-1, ap-southeast-1 — NOT us-east-1); it forwards SNS
  # topics from any region.
  region = var.chatbot_region

  configuration_name = "${var.name_prefix}-slack"
  iam_role_arn       = aws_iam_role.chatbot_channel.arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_team_id
  sns_topic_arns     = [aws_sns_topic.cost_alerts.arn]
  logging_level      = "ERROR"

  # If unset, AWS applies AdministratorAccess as the default guardrail.
  # This channel only receives notifications, so clamp it.
  guardrail_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
