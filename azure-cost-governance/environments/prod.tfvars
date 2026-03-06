# ──────────────────────────────────────────────────────────────────────────────
# Prod environment — strict governance, limited regions
# ──────────────────────────────────────────────────────────────────────────────

environment        = "prod"
location           = "eastus2"
subscription_id    = "00000000-0000-0000-0000-000000000000"
notification_email = "cloud-ops@example.com"

# Production requires a full set of cost-tracking tags.
required_tags    = ["Environment", "Owner", "CostCenter", "Department"]
allowed_locations = ["eastus2", "westus2"]

extra_tags = {
  CostCenter = "platform"
  Compliance = "SOC2"
}
