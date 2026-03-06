# Development environment — relaxed retention and alerting for cost savings.

environment = "dev"
location    = "eastus2"

log_retention_days = 30

grafana_sku              = "Standard"
grafana_admin_object_ids = []

alert_email_recipients = ["platform-dev@example.com"]
slack_webhook_url      = ""
teams_webhook_url      = ""

extra_tags = {
  cost_center = "engineering"
  team        = "platform"
}
