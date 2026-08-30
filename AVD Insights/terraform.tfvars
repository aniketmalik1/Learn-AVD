# Azure identity and subscription details
# Replace these values before running terraform plan/apply.
subscription_id = "00000000-0000-0000-0000-000000000000"
tenant_id       = "00000000-0000-0000-0000-00000000000"
location        = "eastus"

# AVD monitoring lab resource names
monitoring_resource_group_name = "az140-411e-RG"
log_analytics_workspace_name   = "az140-laworkspace41e"
log_analytics_sku              = "PerGB2018"
log_analytics_retention_in_days = 30

# Existing AVD resources created in previous labs
avd_resource_group_name = "az140-21e-RG"
host_pool_name          = "az140-21-hp1"
workspace_name          = "az140-21-ws1"

application_group_names = [
  "az140-21-hp1-DAG",
  "az140-21-hp1-Office365-RAG",
  "az140-21-hp1-Utilities-RAG"
]

# Existing session hosts

session_host_resource_group_name = "az140-21e-RG"

# Session host naming pattern
session_host_prefix = "sh-random"

# Total number of session hosts
session_host_count = 100


# Data Collection Rule created for AVD Insights session host data
# The lab portal typically shows a DCR name starting with microsoft-avdi-
data_collection_rule_name = "microsoft-avdi-az140-21-hp1-dcr"

# Optional tags
tags = {
  environment = "lab"
  workload    = "azure-virtual-desktop-monitoring"
  source      = "terraform"
  owner       = "student"
}
