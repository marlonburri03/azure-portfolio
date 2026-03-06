# ---------------------------------------------------------------------------
# environments/dev.tfvars — Development environment overrides
# ---------------------------------------------------------------------------

environment  = "dev"
project_name = "evtpipe"
location     = "eastus2"

# Smaller/cheaper SKUs for dev to minimise cost.
cosmos_db_throughput = 1000
service_bus_sku      = "Premium" # Premium is required for Private Endpoints
apim_sku             = "Developer"
function_app_sku     = "EP1"

apim_publisher_name  = "Contoso Events (Dev)"
apim_publisher_email = "dev-team@contoso.com"

tags = {
  cost_center = "engineering"
  owner       = "platform-team"
}
