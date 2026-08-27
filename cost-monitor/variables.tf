variable "aws_region" {
  description = "Region for the SNS topic. Budgets and Cost Explorer are global; the chat integration uses var.chatbot_region."
  type        = string
  default     = "us-east-1"
}

variable "chatbot_region" {
  description = "Region for the Amazon Q Developer in chat applications (AWS Chatbot) API, which only has endpoints in a handful of regions. It forwards SNS topics from any region."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = contains(["us-east-2", "us-west-2", "eu-west-1", "ap-southeast-1"], var.chatbot_region)
    error_message = "The Chatbot API only exists in us-east-2, us-west-2, eu-west-1, and ap-southeast-1."
  }
}

variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
  default     = "cost-alerts"
}

variable "slack_team_id" {
  description = "Slack workspace (team) ID, e.g. T0123456789 — immutable, unlike the workspace name. Shown in the Amazon Q Developer (AWS Chatbot) console after the one-time OAuth authorization."
  type        = string

  validation {
    condition     = can(regex("^[TE][A-Z0-9]{8,}$", var.slack_team_id))
    error_message = "slack_team_id must be a Slack team ID like T0123456789, not the workspace name."
  }
}

variable "slack_channel_id" {
  description = "Slack channel ID (e.g. C0123456789). The ID, not the channel name — right-click the channel in Slack, Copy link, take the last path segment."
  type        = string

  validation {
    condition     = can(regex("^[CG][A-Z0-9]{8,}$", var.slack_channel_id))
    error_message = "slack_channel_id must be a channel ID like C0123456789 (starts with C or G), not a #name or URL."
  }
}

variable "alert_email_addresses" {
  description = "Email addresses that receive budget alerts (Budgets' formatted mail) and a daily Cost Anomaly Detection digest."
  type        = list(string)

  validation {
    condition     = length(var.alert_email_addresses) > 0 && length(var.alert_email_addresses) <= 10
    error_message = "Provide 1-10 email addresses (AWS Budgets allows at most 10 per notification)."
  }

  validation {
    condition     = alltrue([for e in var.alert_email_addresses : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Every entry must be a valid email address."
  }
}

variable "alert_thresholds" {
  description = "Actual-spend alert thresholds, as percentages of the monthly budget."
  type        = list(number)
  default     = [25, 50, 75, 100]

  validation {
    condition     = length(var.alert_thresholds) > 0 && length(var.alert_thresholds) <= 4 && alltrue([for t in var.alert_thresholds : t > 0])
    error_message = "Provide 1-4 positive percentage thresholds. AWS Budgets allows at most 5 notifications per budget, and one is reserved for the forecast alert."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD."
  type        = number
  default     = 3000

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be a positive number."
  }
}

variable "anomaly_impact_threshold_usd" {
  description = "Minimum total anomaly impact in USD before Cost Anomaly Detection sends an alert."
  type        = number
  default     = 100

  validation {
    condition     = var.anomaly_impact_threshold_usd >= 0
    error_message = "anomaly_impact_threshold_usd must be zero or positive."
  }
}

variable "existing_anomaly_monitor_arn" {
  description = "ARN of an existing service-dimension Cost Anomaly Detection monitor to reuse instead of creating one. AWS allows only one per account, and accounts that enabled Cost Explorer after March 2023 usually already have the auto-created 'AWS Services' monitor."
  type        = string
  default     = null
}
