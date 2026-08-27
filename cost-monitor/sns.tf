resource "aws_sns_topic" "cost_alerts" {
  name = "${var.name_prefix}-topic"

  # If your org requires SSE on SNS topics, use a customer-managed KMS key
  # and grant budgets.amazonaws.com + costalerts.amazonaws.com
  # kms:GenerateDataKey* and kms:Decrypt in the key policy. The AWS-managed
  # aws/sns key will NOT work (its key policy can't be edited).
  # kms_master_key_id = aws_kms_key.cost_alerts.id
}

data "aws_iam_policy_document" "cost_alerts_topic" {
  # aws_sns_topic_policy REPLACES the SNS default policy, so restore the
  # default owner statement: without it, same-account principals and
  # services (console subscriptions, CloudWatch alarms or EventBridge rules
  # pointed at this topic later, the Chatbot service-linked role) are
  # silently unauthorized at runtime.
  statement {
    sid    = "DefaultOwnerAccess"
    effect = "Allow"
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [aws_sns_topic.cost_alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # AWS Budgets -> topic
  statement {
    sid     = "AllowBudgetsPublish"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    resources = [aws_sns_topic.cost_alerts.arn]

    # Confused-deputy hardening: only budgets in *this* account may publish.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Cost Anomaly Detection -> topic
  statement {
    sid     = "AllowCostAnomalyPublish"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["costalerts.amazonaws.com"]
    }

    resources = [aws_sns_topic.cost_alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # No statement for chatbot.amazonaws.com: Amazon Q Developer / Chatbot
  # subscribes topics through its in-account service-linked role, which the
  # DefaultOwnerAccess statement above already covers. An unconditioned
  # service-principal grant would let the service subscribe this topic on
  # behalf of ANY account (confused deputy).
}

resource "aws_sns_topic_policy" "cost_alerts" {
  arn    = aws_sns_topic.cost_alerts.arn
  policy = data.aws_iam_policy_document.cost_alerts_topic.json
}
