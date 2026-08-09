# Azure identity and subscription details
# Replace these values before running terraform plan/apply.
subscription_id = "00000000-0000-0000-0000-000000000000"
tenant_id       = "00000000-0000-0000-0000-000000000000"
location        = "eastus"

# Lab resource names from the manual
vnet_resource_group_name = "az140-11e-RG"
avd_resource_group_name  = "az140-21e-RG"
vnet_name                = "az140-vnet11e"
subnet_name              = "hp1-Subnet"
host_pool_name           = "az140-21-hp1"
workspace_name           = "az140-21-ws1"
desktop_app_group_name   = "az140-21-hp1-DAG"
office_remoteapp_group_name    = "az140-21-hp1-Office365-RAG"
utilities_remoteapp_group_name = "az140-21-hp1-Utilities-RAG"

# Session host settings
# In the lab manual, replace <random> with the string between User1- and @ from the lab Resources tab.
session_host_name_prefix = "sh-random"
session_host_count       = 2
vm_size                  = "Standard_DC2s_v3"
admin_username           = "Student"
admin_password           = "Replace-With-Strong-Password123!"

# Marketplace image from the lab manual
image_publisher = "MicrosoftWindowsDesktop"
image_offer     = "office-365"
image_sku       = "win11-23h2-avd-m365"

# Microsoft Entra groups identified in Task 1 of the lab manual
avd_dag_group_name       = "AVD-DAG-REPLACE-ME"
avd_remoteapp_group_name = "AVD-RemoteApp-REPLACE-ME"

tags = {
  environment = "lab"
  workload    = "azure-virtual-desktop"
  source      = "terraform"
  owner       = "student"
}
