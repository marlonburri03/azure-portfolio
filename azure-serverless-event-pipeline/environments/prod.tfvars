# ---------------------------------------------------------------------------
# environments/prod.tfvars — Production environment overrides
# ---------------------------------------------------------------------------

environment  = "prod"
project_name = "evtpipe"
location     = "eastus2"

# Production-grade throughput and SKUs.
cosmos_db_throughput = 4000
service_bus_sku      = "Premium"
apim_sku             = "Standard" # Standard supports higher throughput + SLA
function_app_sku     = "EP1"

apim_publisher_name  = "Contoso Events"
apim_publisher_email = "platform-team@contoso.com"

tags = {
  cost_center = "engineering"
  owner       = "platform-team"
  compliance  = "soc2"
}
