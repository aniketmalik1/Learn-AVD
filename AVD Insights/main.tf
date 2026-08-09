terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# ------------------------------------------------------------
# Variables
# Everything is kept in main.tf because the requested repo has only:
# main.tf, terraform.tfvars, and readme.md.
# ------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID used for this lab."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID associated with the Azure subscription."
  type        = string
}

variable "location" {
  description = "Azure region where the existing AVD environment was deployed. Example: eastus, centralindia, westeurope."
  type        = string
}

variable "monitoring_resource_group_name" {
  description = "Resource group for the Log Analytics workspace and monitoring resources."
  type        = string
  default     = "az140-411e-RG"
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name for AVD Insights."
  type        = string
  default     = "az140-laworkspace41e"
}

variable "log_analytics_sku" {
  description = "Log Analytics workspace SKU."
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_in_days" {
  description = "Retention period for Log Analytics data."
  type        = number
  default     = 30
}

variable "avd_resource_group_name" {
  description = "Existing resource group that contains the AVD host pool, workspace, and application groups."
  type        = string
  default     = "az140-21e-RG"
}

variable "host_pool_name" {
  description = "Existing Azure Virtual Desktop host pool name."
  type        = string
  default     = "az140-21-hp1"
}

variable "workspace_name" {
  description = "Existing Azure Virtual Desktop workspace name."
  type        = string
  default     = "az140-21-ws1"
}

variable "application_group_names" {
  description = "Existing AVD application groups for which diagnostic settings should be enabled."
  type        = list(string)
  default = [
    "az140-21-hp1-DAG",
    "az140-21-hp1-Office365-RAG",
    "az140-21-hp1-Utilities-RAG"
  ]
}

variable "session_host_resource_group_name" {
  description = "Resource group that contains the session host VMs. In the lab this is normally az140-21e-RG."
  type        = string
  default     = "az140-21e-RG"
}

variable "session_host_prefix" {
  description = "Session host naming prefix."
  type        = string
}

variable "session_host_count" {
  description = "Number of session hosts."
  type        = number
}

variable "data_collection_rule_name" {
  description = "DCR name used by AVD Insights session host data collection."
  type        = string
  default     = "microsoft-avdi-az140-21-hp1-dcr"
}

variable "performance_counter_sampling_frequency_seconds" {
  description = "Sampling interval for Windows performance counters collected by Azure Monitor Agent."
  type        = number
  default     = 60
}

variable "performance_counter_specifiers" {
  description = "Recommended Windows performance counters for AVD session host monitoring."
  type        = list(string)
  default = [
    "\\Processor Information(_Total)\\% Processor Time",
    "\\Memory\\Available MBytes",
    "\\LogicalDisk(_Total)\\% Free Space",
    "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
    "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
    "\\Terminal Services\\Active Sessions",
    "\\Terminal Services\\Inactive Sessions",
    "\\RemoteFX Network(*)\\Current TCP RTT",
    "\\RemoteFX Network(*)\\Current UDP Bandwidth"
  ]
}

variable "windows_event_log_x_path_queries" {
  description = "Windows Event Log XPath queries collected from AVD session hosts."
  type        = list(string)
  default = [
    "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
    "System!*[System[(Level=1 or Level=2 or Level=3)]]",
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational!*[System[(Level=1 or Level=2 or Level=3 or Level=4)]]",
    "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational!*[System[(Level=1 or Level=2 or Level=3 or Level=4)]]",
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational!*[System[(Level=1 or Level=2 or Level=3 or Level=4)]]"
  ]
}

variable "tags" {
  description = "Common tags for monitoring resources."
  type        = map(string)
  default = {
    environment = "lab"
    workload    = "azure-virtual-desktop-monitoring"
    source      = "terraform"
  }
}

# ------------------------------------------------------------
# Register Microsoft.Insights resource provider
# ------------------------------------------------------------
resource "azurerm_resource_provider_registration" "microsoft_insights" {
  name = "Microsoft.Insights"
}

# ------------------------------------------------------------
# Existing AVD resources from previous labs
# ------------------------------------------------------------
data "azurerm_virtual_desktop_host_pool" "host_pool" {
  name                = var.host_pool_name
  resource_group_name = var.avd_resource_group_name

  depends_on = [azurerm_resource_provider_registration.microsoft_insights]
}

data "azurerm_virtual_desktop_workspace" "workspace" {
  name                = var.workspace_name
  resource_group_name = var.avd_resource_group_name

  depends_on = [azurerm_resource_provider_registration.microsoft_insights]
}

data "azurerm_virtual_desktop_application_group" "application_groups" {
  for_each            = toset(var.application_group_names)
  name                = each.value
  resource_group_name = var.avd_resource_group_name

  depends_on = [azurerm_resource_provider_registration.microsoft_insights]
}

data "azurerm_virtual_machine" "session_hosts" {
  count               = length(local.session_host_vm_names)
  name                = local.session_host_vm_names[count.index]
  resource_group_name = var.session_host_resource_group_name
}

# ------------------------------------------------------------
# Log Analytics workspace for AVD Insights
# ------------------------------------------------------------
resource "azurerm_resource_group" "monitoring" {
  name     = var.monitoring_resource_group_name
  location = var.location
  tags     = var.tags

  depends_on = [azurerm_resource_provider_registration.microsoft_insights]
}

resource "azurerm_log_analytics_workspace" "avd_insights" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = var.tags
}

# ------------------------------------------------------------
# Diagnostic settings for AVD resources
# Equivalent to configuring Resource diagnostics settings in
# the AVD Insights configuration workbook.
# ------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "host_pool_all_logs" {
  name                       = "avd-hostpool-alllogs-to-law"
  target_resource_id         = data.azurerm_virtual_desktop_host_pool.host_pool.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_insights.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "workspace_all_logs" {
  name                       = "avd-workspace-alllogs-to-law"
  target_resource_id         = data.azurerm_virtual_desktop_workspace.workspace.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_insights.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "application_group_all_logs" {
  for_each                   = data.azurerm_virtual_desktop_application_group.application_groups
  name                       = "avd-appgroup-alllogs-to-law"
  target_resource_id         = each.value.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_insights.id

  enabled_log {
    category_group = "allLogs"
  }
}

# ------------------------------------------------------------
# Data Collection Rule for session host performance counters
# and Windows event logs. This mirrors the Session host data
# settings tab in AVD Insights configuration workbook.
# ------------------------------------------------------------
resource "azurerm_monitor_data_collection_rule" "avd_insights" {
  name                = var.data_collection_rule_name
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  kind                = "Windows"
  description         = "AVD Insights DCR for session host performance counters and Windows event logs."
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.avd_insights.id
      name                  = "avd-law-destination"
    }
  }

  data_sources {
    performance_counter {
      name                          = "avd-performance-counters"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = var.performance_counter_sampling_frequency_seconds
      counter_specifiers            = var.performance_counter_specifiers
    }

    windows_event_log {
      name           = "avd-windows-events"
      streams        = ["Microsoft-Event"]
      x_path_queries = var.windows_event_log_x_path_queries
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Event"]
    destinations = ["avd-law-destination"]
  }
}

# ------------------------------------------------------------
# Azure Monitor Agent and DCR association for every session host
# ------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "azure_monitor_windows_agent" {
  count                      = length(data.azurerm_virtual_machine.session_hosts)
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = data.azurerm_virtual_machine.session_hosts[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  tags = var.tags
}

resource "azurerm_monitor_data_collection_rule_association" "session_hosts" {
  count                   = length(data.azurerm_virtual_machine.session_hosts)
  name                    = "avd-insights-dcr-association-${count.index + 1}"
  target_resource_id      = data.azurerm_virtual_machine.session_hosts[count.index].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.avd_insights.id
  description             = "Associates AVD Insights DCR with session host ${data.azurerm_virtual_machine.session_hosts[count.index].name}."

  depends_on = [azurerm_virtual_machine_extension.azure_monitor_windows_agent]
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.avd_insights.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.avd_insights.id
}

output "host_pool_diagnostic_setting_id" {
  value = azurerm_monitor_diagnostic_setting.host_pool_all_logs.id
}

output "workspace_diagnostic_setting_id" {
  value = azurerm_monitor_diagnostic_setting.workspace_all_logs.id
}

output "application_group_diagnostic_setting_ids" {
  value = { for name, setting in azurerm_monitor_diagnostic_setting.application_group_all_logs : name => setting.id }
}

output "data_collection_rule_id" {
  value = azurerm_monitor_data_collection_rule.avd_insights.id
}

output "monitored_session_hosts" {
  value = data.azurerm_virtual_machine.session_hosts[*].name
}

