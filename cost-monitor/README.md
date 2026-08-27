# AWS cost alerts → Slack + email (OpenTofu)

Budgets + Cost Anomaly Detection → SNS → Amazon Q Developer in chat
applications (formerly AWS Chatbot) → Slack, with every alert also
delivered to email.

## What this creates

- SNS topic with an access policy allowing `budgets.amazonaws.com` and
  `costalerts.amazonaws.com` to publish, plus the restored SNS default
  owner statement (so future same-account publishers and the Chatbot
  service-linked role keep working)
- A monthly cost budget alerting at **25%, 50%, 75%, and 100% of actual
  spend** (configurable via `alert_thresholds`) plus **100% forecasted**,
  each notification going to both the SNS topic (→ Slack) and
  `alert_email_addresses` directly
- A Cost Anomaly Detection monitor (per-service, or reuse an existing one
  via `existing_anomaly_monitor_arn`) with an immediate SNS subscription
  and a daily email digest, both gated on a minimum dollar impact
- The Slack channel configuration plus a notifications-only IAM channel
  role (CloudWatch read only, `ReadOnlyAccess` guardrail)

## One-time manual steps (before first apply)

1. **Enable Cost Explorer** (Console → Billing and Cost Management → Cost
   Explorer) if the account never has. Anomaly Detection rides on it, and
   AWS takes up to ~24h to prepare data after enablement — the anomaly
   resources fail to apply until then. If the account already has the
   auto-created "AWS Services" anomaly monitor (default for accounts that
   enabled Cost Explorer after March 2023), pass its ARN as
   `existing_anomaly_monitor_arn` — AWS allows only one service-dimension
   monitor per account.
2. **Authorize the Slack workspace.** Console → Amazon Q Developer in chat
   applications → Configure new client → Slack → complete the OAuth grant.
   This is an interactive OAuth handshake and cannot be done in OpenTofu.
   The console shows the workspace's **team ID** (`T…`) afterwards — that's
   `slack_team_id`.
3. **Invite the app to the channel.** In Slack: `/invite @Amazon Q` in the
   target channel. Without this, messages are silently dropped.
4. **Grab the channel ID.** Right-click the channel in Slack → Copy link →
   the ID is the last path segment (starts with `C`).

## Usage

```hcl
# terraform.tfvars
slack_team_id         = "T0123456789"
slack_channel_id      = "C0123456789"
alert_email_addresses = ["billing@example.org"]
monthly_budget_usd    = 3000
# alert_thresholds    = [25, 50, 75, 100]  # the default
```

```bash
tofu init
tofu plan
tofu apply
```

## Testing

Use **Send test message** on the channel configuration in the console.
Do **not** test with `aws sns publish` — the chat integration only forwards
recognized notification formats (Budgets, CloudWatch, Cost Anomaly
Detection, ...) and silently drops arbitrary hand-published messages. If
you want a CLI test, publish a payload matching the chatbot custom
notification schema (`"version": "1.0"`, `"source": "custom"`).

Budget emails come straight from AWS Budgets (no confirmation step);
anomaly digest emails come from Cost Anomaly Detection.

## Notes

- **Alert thresholds** live in `alert_thresholds` (max 4: AWS Budgets
  allows 5 notifications per budget and one is reserved for the forecast
  alert).
- **Forecast warm-up:** Budgets needs ~5 weeks of usage history before it
  produces forecasts, so the 100%-forecasted alert is silently inactive in
  a new account until then.
- **Regions:** the Chatbot API only has endpoints in us-east-2, us-west-2,
  eu-west-1, and ap-southeast-1 (`chatbot_region`, default us-east-2 — NOT
  us-east-1); it forwards SNS topics from any region. The SNS topic lives
  in `aws_region`; Budgets and Cost Explorer are global.
- Budget alerts lag billing data by up to ~a day — this is threshold
  awareness, not real-time runaway-instance protection.
- If your org mandates SSE on SNS topics, use a customer-managed KMS key
  and grant the two publishing service principals `kms:GenerateDataKey*`
  and `kms:Decrypt` in the key policy (see comment in `sns.tf`). The
  AWS-managed `aws/sns` key won't work.
- The provider is pinned `~> 6.0`: the per-resource `region` override on
  the channel configuration needs v6.0+.
- To add per-account budgets later (e.g. a split-out backup account), copy
  the budget resource with a `LinkedAccount` cost filter (see comment in
  `budget.tf`).
