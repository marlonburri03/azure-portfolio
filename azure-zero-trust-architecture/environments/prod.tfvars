environment = "prod"
location    = "eastus2"
project_name = "zt"

firewall_sku_tier = "Premium"
app_service_sku   = "P2v3"

extra_tags = {
  CostCenter  = "engineering-prod"
  Compliance  = "SOC2"
}
