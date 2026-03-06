# --------------------------------------------------------------------------
# Alert Rules & Action Groups
#
# Strategy: Action Groups define WHERE notifications go; Alert Rules define
# WHAT conditions trigger them. This separation lets teams resubscribe to
# existing alerts without modifying rule logic.
# --------------------------------------------------------------------------

# === Action Groups ===========================================================

resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-critical-${var.environment}"
  resource_group_name = azurerm_resource_group.observability.name
  short_name          = "critical"
  enabled             = true

  # Email is always-on — webhook channels are additive when URLs are provided.
  dynamic "email_receiver" {
    for_each = var.alert_email_recipients
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  # Slack via incoming webhook — Common Alert Schema sends a structured JSON
  # payload that Slack can render with a workflow or middleware like Azure Logic Apps.
  dynamic "webhook_receiver" {
    for_each = var.slack_webhook_url != "" ? [1] : []
    content {
      name                    = "slack-webhook"
      service_uri             = var.slack_webhook_url
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.teams_webhook_url != "" ? [1] : []
    content {
      name                    = "teams-webhook"
      service_uri             = var.teams_webhook_url
      use_common_alert_schema = true
    }
  }

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "warning" {
  name                = "ag-warning-${var.environment}"
  resource_group_name = azurerm_resource_group.observability.name
  short_name          = "warning"
  enabled             = true

  dynamic "email_receiver" {
    for_each = var.alert_email_recipients
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  # Warnings only go to Teams — avoids alert fatigue in the Slack critical channel.
  dynamic "webhook_receiver" {
    for_each = var.teams_webhook_url != "" ? [1] : []
    content {
      name                    = "teams-webhook"
      service_uri             = var.teams_webhook_url
      use_common_alert_schema = true
    }
  }

  tags = local.common_tags
}

# === Scheduled Query Alert Rules =============================================
# These fire when a KQL query returns results above a threshold.

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_pod_crash_loop" {
  name                = "alert-aks-crashloop-${var.environment}"
  location            = azurerm_resource_group.observability.location
  resource_group_name = azurerm_resource_group.observability.name

  description  = "Fires when any pod enters CrashLoopBackOff — indicates application or config errors."
  display_name = "AKS Pod CrashLoopBackOff"
  severity     = 1
  enabled      = true

  scopes                    = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency      = "PT5M"
  window_duration           = "PT15M"
  target_resource_types     = ["Microsoft.OperationalInsights/workspaces"]
  skip_query_validation     = false
  auto_mitigation_enabled   = true

  criteria {
    query = <<-KQL
      // Detect pods stuck in CrashLoopBackOff by counting restart events.
      // A pod restarting 5+ times in 15 minutes is almost certainly crash-looping.
      KubePodInventory
      | where PodRestartCount > 0
      | summarize RestartDelta = max(PodRestartCount) - min(PodRestartCount)
          by PodName, Namespace, ClusterName, bin(TimeGenerated, 15m)
      | where RestartDelta >= 5
    KQL

    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.critical.id]
  }

  tags = local.common_tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_heartbeat_lost" {
  name                = "alert-vm-heartbeat-${var.environment}"
  location            = azurerm_resource_group.observability.location
  resource_group_name = azurerm_resource_group.observability.name

  description  = "Fires when a VM stops sending heartbeats — may indicate a crash, network partition, or deallocation."
  display_name = "VM Heartbeat Lost"
  severity     = 0
  enabled      = true

  scopes                    = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency      = "PT5M"
  window_duration           = "PT10M"
  target_resource_types     = ["Microsoft.OperationalInsights/workspaces"]
  auto_mitigation_enabled   = true

  criteria {
    query = <<-KQL
      // Find VMs that sent heartbeats recently but have gone silent.
      // The anti-join pattern: VMs seen in the last 24h minus VMs seen in the last 10m.
      let active_vms = Heartbeat
          | where TimeGenerated > ago(24h)
          | distinct Computer;
      let recent_heartbeats = Heartbeat
          | where TimeGenerated > ago(10m)
          | distinct Computer;
      active_vms
      | join kind=leftanti recent_heartbeats on Computer
    KQL

    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 2
      number_of_evaluation_periods             = 2
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.critical.id]
  }

  tags = local.common_tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "app_service_5xx_spike" {
  name                = "alert-appsvc-5xx-${var.environment}"
  location            = azurerm_resource_group.observability.location
  resource_group_name = azurerm_resource_group.observability.name

  description  = "Fires when HTTP 5xx error rate exceeds 5% of total requests over 15 minutes."
  display_name = "App Service 5xx Error Spike"
  severity     = 1
  enabled      = true

  scopes                    = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency      = "PT5M"
  window_duration           = "PT15M"
  target_resource_types     = ["Microsoft.OperationalInsights/workspaces"]
  auto_mitigation_enabled   = true

  criteria {
    query = <<-KQL
      // Calculate the 5xx error ratio per App Service instance.
      // Threshold of 5% catches real outages while ignoring single-request blips.
      AppServiceHTTPLogs
      | summarize
          TotalRequests = count(),
          ErrorRequests = countif(ScStatus >= 500)
          by CsHost, bin(TimeGenerated, 15m)
      | extend ErrorRate = round(100.0 * ErrorRequests / TotalRequests, 2)
      | where ErrorRate > 5 and TotalRequests > 20
    KQL

    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.critical.id]
  }

  tags = local.common_tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_cpu_sustained" {
  name                = "alert-vm-cpu-${var.environment}"
  location            = azurerm_resource_group.observability.location
  resource_group_name = azurerm_resource_group.observability.name

  description  = "Warning when a VM sustains >85% CPU for 30 minutes — may need scaling or investigation."
  display_name = "VM Sustained High CPU"
  severity     = 2
  enabled      = true

  scopes                    = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency      = "PT10M"
  window_duration           = "PT30M"
  target_resource_types     = ["Microsoft.OperationalInsights/workspaces"]
  auto_mitigation_enabled   = true

  criteria {
    query = <<-KQL
      Perf
      | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
      | summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 30m)
      | where AvgCPU > 85
    KQL

    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 3
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.warning.id]
  }

  tags = local.common_tags
}
