# Production environment — extended retention, zone redundancy, full alerting.

environment = "prod"
location    = "eastus2"

log_retention_days = 90

grafana_sku              = "Standard"
grafana_admin_object_ids = []   # Populate with AAD object IDs of platform team members

alert_email_recipients = ["platform-oncall@example.com", "sre-leads@example.com"]

# Sensitive — pass via TF_VAR_ environment variables in CI rather than storing here.
# slack_webhook_url = ""
# teams_webhook_url = ""

extra_tags = {
  cost_center  = "infrastructure"
  team         = "platform"
  compliance   = "soc2"
}
