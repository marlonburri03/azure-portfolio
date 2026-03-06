# ──────────────────────────────────────────────────────────────────────────────
# Azure Cost Governance — Logic App (Weekly Cost Report)
# ──────────────────────────────────────────────────────────────────────────────
# The Logic App fires on a weekly schedule, invokes the cost-report script
# via the Function App, and pushes the results to Teams / email.

resource "azurerm_logic_app_workflow" "cost_report" {
  name                = "logic-${local.name_prefix}-cost-report"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  # System-assigned identity lets the Logic App call the Function App
  # and read secrets from Key Vault without storing credentials.
  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# ── Recurrence Trigger ─────────────────────────────────────────────────────
# Fires once per week.  The exact day/time is controlled by
# var.cost_report_schedule; we default to Monday 08:00 UTC.

resource "azurerm_logic_app_trigger_recurrence" "weekly" {
  name         = "weekly-trigger"
  logic_app_id = azurerm_logic_app_workflow.cost_report.id

  # Logic Apps recurrence uses ISO-style frequency, not cron.
  frequency = "Week"
  interval  = 1

  # Start on Monday at 08:00 UTC.
  start_time = "2024-01-01T08:00:00Z"
  time_zone  = "UTC"
}

# ── HTTP Action — invoke the Function App ──────────────────────────────────
# Calls the idle-scanner Function's /api/cost-report endpoint, which runs
# generate_cost_report.py and returns JSON.

resource "azurerm_logic_app_action_http" "invoke_function" {
  name         = "invoke-cost-report-function"
  logic_app_id = azurerm_logic_app_workflow.cost_report.id

  method = "POST"
  uri    = "https://${azurerm_linux_function_app.idle_scanner.default_hostname}/api/cost-report"

  headers = {
    "Content-Type" = "application/json"
  }

  body = jsonencode({
    subscription_id = var.subscription_id
    days            = 7
  })

  depends_on = [azurerm_logic_app_trigger_recurrence.weekly]
}

# ── Key Vault access for the Logic App identity ───────────────────────────
# Grants the Logic App permission to read the Teams webhook URL secret.

resource "azurerm_key_vault_access_policy" "logic_app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_logic_app_workflow.cost_report.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
