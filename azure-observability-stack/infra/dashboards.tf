# --------------------------------------------------------------------------
# Azure Portal Dashboard
#
# Dashboards are ARM-template JSON wrapped in a Terraform resource.
# This provides a high-level "single pane of glass" for operators who
# prefer the Azure Portal over Grafana.
# --------------------------------------------------------------------------

resource "azurerm_portal_dashboard" "observability_overview" {
  name                = "dash-${local.name_prefix}-overview"
  resource_group_name = azurerm_resource_group.observability.name
  location            = azurerm_resource_group.observability.location
  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          # --- Part 0: Log Analytics query — Active VMs by heartbeat count ---
          "0" = {
            position = { x = 0, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
              inputs = [
                {
                  name  = "resourceTypeMode"
                  value = "workspace"
                },
                {
                  name = "ComponentId"
                  value = {
                    ResourceId = azurerm_log_analytics_workspace.main.id
                  }
                },
                {
                  name  = "Query"
                  value = "Heartbeat | summarize LastHeartbeat = max(TimeGenerated) by Computer | order by LastHeartbeat desc | take 20"
                },
                {
                  name  = "TimeRange"
                  value = "PT1H"
                }
              ]
              settings = {
                content = {
                  dashboardPartTitle   = "Active VMs (Last Hour)"
                  dashboardPartSubTitle = "Top 20 by most recent heartbeat"
                }
              }
            }
          }

          # --- Part 1: AKS pod count trend ---
          "1" = {
            position = { x = 6, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
              inputs = [
                {
                  name  = "resourceTypeMode"
                  value = "workspace"
                },
                {
                  name = "ComponentId"
                  value = {
                    ResourceId = azurerm_log_analytics_workspace.main.id
                  }
                },
                {
                  name  = "Query"
                  value = "KubePodInventory | where PodStatus == 'Running' | summarize PodCount = dcount(PodUid) by ClusterName, bin(TimeGenerated, 5m) | render timechart"
                },
                {
                  name  = "TimeRange"
                  value = "PT6H"
                }
              ]
              settings = {
                content = {
                  dashboardPartTitle   = "AKS Running Pod Count"
                  dashboardPartSubTitle = "6-hour trend per cluster"
                }
              }
            }
          }

          # --- Part 2: App Service error rate ---
          "2" = {
            position = { x = 0, y = 4, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
              inputs = [
                {
                  name  = "resourceTypeMode"
                  value = "workspace"
                },
                {
                  name = "ComponentId"
                  value = {
                    ResourceId = azurerm_log_analytics_workspace.main.id
                  }
                },
                {
                  name  = "Query"
                  value = "AppServiceHTTPLogs | summarize Requests = count(), Errors = countif(ScStatus >= 500) by CsHost, bin(TimeGenerated, 15m) | extend ErrorPct = round(100.0 * Errors / Requests, 2) | project TimeGenerated, CsHost, ErrorPct | render timechart"
                },
                {
                  name  = "TimeRange"
                  value = "PT6H"
                }
              ]
              settings = {
                content = {
                  dashboardPartTitle   = "App Service 5xx Error Rate"
                  dashboardPartSubTitle = "Percentage of server errors per host"
                }
              }
            }
          }

          # --- Part 3: VM CPU utilization ---
          "3" = {
            position = { x = 6, y = 4, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
              inputs = [
                {
                  name  = "resourceTypeMode"
                  value = "workspace"
                },
                {
                  name = "ComponentId"
                  value = {
                    ResourceId = azurerm_log_analytics_workspace.main.id
                  }
                },
                {
                  name  = "Query"
                  value = "Perf | where ObjectName == 'Processor' and CounterName == '% Processor Time' and InstanceName == '_Total' | summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m) | render timechart"
                },
                {
                  name  = "TimeRange"
                  value = "PT6H"
                }
              ]
              settings = {
                content = {
                  dashboardPartTitle   = "VM CPU Utilization"
                  dashboardPartSubTitle = "Average CPU per VM (5-min bins)"
                }
              }
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          type  = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
          value = { relative = { duration = 6, timeUnit = 1 } }
        }
      }
    }
  })

  tags = local.common_tags
}
