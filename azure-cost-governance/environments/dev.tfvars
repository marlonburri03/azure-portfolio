# ──────────────────────────────────────────────────────────────────────────────
# Dev environment — lower guardrails, broader region list for experimentation
# ──────────────────────────────────────────────────────────────────────────────

environment        = "dev"
location           = "eastus2"
subscription_id    = "00000000-0000-0000-0000-000000000000"
notification_email = "dev-team@example.com"

required_tags    = ["Environment", "Owner"]
allowed_locations = ["eastus2", "westus2", "centralus", "westeurope"]

extra_tags = {
  CostCenter = "engineering"
}
