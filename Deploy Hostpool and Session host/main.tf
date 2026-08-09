terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# ------------------------------------------------------------
# Variables
# Kept in main.tf because this repository contains only 3 files.
# Put real values in terraform.tfvars.
# ------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID where the lab resources will be deployed."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID associated with the Azure subscription."
  type        = string
}

variable "location" {
  description = "Azure region for the AVD lab deployment. Example: eastus, centralindia, westeurope."
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Resource group for the virtual network, matching the lab manual."
  type        = string
  default     = "az140-11e-RG"
}

variable "avd_resource_group_name" {
  description = "Resource group for Azure Virtual Desktop resources and session hosts, matching the lab manual."
  type        = string
  default     = "az140-21e-RG"
}

variable "vnet_name" {
  description = "Virtual network name."
  type        = string
  default     = "az140-vnet11e"
}

variable "subnet_name" {
  description = "Subnet name for AVD session hosts."
  type        = string
  default     = "hp1-Subnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the AVD subnet."
  type        = list(string)
  default     = ["10.20.1.0/24"]
}

variable "host_pool_name" {
  description = "Azure Virtual Desktop host pool name."
  type        = string
  default     = "az140-21-hp1"
}

variable "workspace_name" {
  description = "Azure Virtual Desktop workspace name."
  type        = string
  default     = "az140-21-ws1"
}

variable "desktop_app_group_name" {
  description = "Desktop application group name."
  type        = string
  default     = "az140-21-hp1-DAG"
}

variable "office_remoteapp_group_name" {
  description = "RemoteApp application group for Microsoft 365 apps."
  type        = string
  default     = "az140-21-hp1-Office365-RAG"
}

variable "utilities_remoteapp_group_name" {
  description = "RemoteApp application group for utilities."
  type        = string
  default     = "az140-21-hp1-Utilities-RAG"
}

variable "session_host_count" {
  description = "Number of AVD session host VMs."
  type        = number
  default     = 2
}

variable "session_host_name_prefix" {
  description = "Name prefix for the session host VMs. In the lab, use sh-<random string from User1 account>."
  type        = string
}

variable "vm_size" {
  description = "Session host VM size."
  type        = string
  default     = "Standard_DC2s_v3"
}

variable "admin_username" {
  description = "Local administrator username for session hosts."
  type        = string
  default     = "Student"
}

variable "admin_password" {
  description = "Local administrator password for session hosts. Use at least 12 characters with upper, lower, number, and special character."
  type        = string
  sensitive   = true
}

variable "image_publisher" {
  description = "Marketplace image publisher."
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "image_offer" {
  description = "Marketplace image offer for Windows 11 with Microsoft 365 Apps."
  type        = string
  default     = "office-365"
}

variable "image_sku" {
  description = "Marketplace image SKU. Adjust if 23H2 is unavailable in your selected region."
  type        = string
  default     = "win11-23h2-avd-m365"
}

variable "avd_dag_group_name" {
  description = "Microsoft Entra security group used for the desktop application group and VM Administrator Login. Example: AVD-DAG-xxxxx."
  type        = string
}

variable "avd_remoteapp_group_name" {
  description = "Microsoft Entra security group used for RemoteApp groups and VM User Login. Example: AVD-RemoteApp-xxxxx."
  type        = string
}

variable "tags" {
  description = "Common tags applied to resources."
  type        = map(string)
  default = {
    environment = "lab"
    workload    = "azure-virtual-desktop"
    source      = "terraform"
  }
}

# ------------------------------------------------------------
# Resource groups and networking
# ------------------------------------------------------------
resource "azurerm_resource_group" "vnet_rg" {
  name     = var.vnet_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "avd_rg" {
  name     = var.avd_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "avd_vnet" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.vnet_rg.name
  location            = azurerm_resource_group.vnet_rg.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "session_hosts" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.vnet_rg.name
  virtual_network_name = azurerm_virtual_network.avd_vnet.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_network_security_group" "session_hosts" {
  name                = "${var.subnet_name}-nsg"
  location            = azurerm_resource_group.vnet_rg.location
  resource_group_name = azurerm_resource_group.vnet_rg.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "session_hosts" {
  subnet_id                 = azurerm_subnet.session_hosts.id
  network_security_group_id = azurerm_network_security_group.session_hosts.id
}

# ------------------------------------------------------------
# Azure Virtual Desktop host pool, app groups, workspace
# ------------------------------------------------------------
resource "azurerm_virtual_desktop_host_pool" "hp" {
  name                     = var.host_pool_name
  location                 = azurerm_resource_group.avd_rg.location
  resource_group_name      = azurerm_resource_group.avd_rg.name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  preferred_app_group_type = "Desktop"
  validate_environment     = false
  start_vm_on_connect      = false
  description              = "Lab pooled host pool with Microsoft Entra joined session hosts."
  friendly_name            = var.host_pool_name
  tags                     = var.tags
}

resource "azurerm_virtual_desktop_application_group" "desktop" {
  name                = var.desktop_app_group_name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  type                = "Desktop"
  host_pool_id        = azurerm_virtual_desktop_host_pool.hp.id
  friendly_name       = var.desktop_app_group_name
  description         = "Desktop application group for the lab host pool."
  tags                = var.tags
}

resource "azurerm_virtual_desktop_application_group" "office_remoteapp" {
  name                = var.office_remoteapp_group_name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  type                = "RemoteApp"
  host_pool_id        = azurerm_virtual_desktop_host_pool.hp.id
  friendly_name       = var.office_remoteapp_group_name
  description         = "RemoteApp group for Word, Excel, and PowerPoint."
  tags                = var.tags
}

resource "azurerm_virtual_desktop_application_group" "utilities_remoteapp" {
  name                = var.utilities_remoteapp_group_name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  type                = "RemoteApp"
  host_pool_id        = azurerm_virtual_desktop_host_pool.hp.id
  friendly_name       = var.utilities_remoteapp_group_name
  description         = "RemoteApp group for utility applications."
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace" "ws" {
  name                = var.workspace_name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  friendly_name       = var.workspace_name
  description         = "Workspace for the AVD lab."
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "desktop" {
  workspace_id         = azurerm_virtual_desktop_workspace.ws.id
  application_group_id = azurerm_virtual_desktop_application_group.desktop.id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "office_remoteapp" {
  workspace_id         = azurerm_virtual_desktop_workspace.ws.id
  application_group_id = azurerm_virtual_desktop_application_group.office_remoteapp.id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "utilities_remoteapp" {
  workspace_id         = azurerm_virtual_desktop_workspace.ws.id
  application_group_id = azurerm_virtual_desktop_application_group.utilities_remoteapp.id
}

# RemoteApp apps. These paths match the Microsoft 365 Apps image used in the lab.
resource "azurerm_virtual_desktop_application" "word" {
  name                         = "microsoft-word"
  application_group_id         = azurerm_virtual_desktop_application_group.office_remoteapp.id
  friendly_name                = "Microsoft Word"
  description                  = "Microsoft Word"
  path                         = "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE"
  icon_index                   = 0
}

resource "azurerm_virtual_desktop_application" "excel" {
  name                         = "microsoft-excel"
  application_group_id         = azurerm_virtual_desktop_application_group.office_remoteapp.id
  friendly_name                = "Microsoft Excel"
  description                  = "Microsoft Excel"
  path                         = "C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE"
  icon_index                   = 0
}

resource "azurerm_virtual_desktop_application" "powerpoint" {
  name                         = "microsoft-powerpoint"
  application_group_id         = azurerm_virtual_desktop_application_group.office_remoteapp.id
  friendly_name                = "Microsoft PowerPoint"
  description                  = "Microsoft PowerPoint"
  path                         = "C:\\Program Files\\Microsoft Office\\root\\Office16\\POWERPNT.EXE"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Program Files\\Microsoft Office\\root\\Office16\\POWERPNT.EXE"
  icon_index                   = 0
}

resource "azurerm_virtual_desktop_application" "cmd" {
  name                         = "command-prompt"
  application_group_id         = azurerm_virtual_desktop_application_group.utilities_remoteapp.id
  friendly_name                = "Command Prompt"
  description                  = "Windows Command Prompt"
  path                         = "C:\\Windows\\system32\\cmd.exe"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Windows\\system32\\cmd.exe"
  icon_index                   = 0
}

# ------------------------------------------------------------
# Session host VMs: Microsoft Entra joined, no public IP
# ------------------------------------------------------------
resource "azurerm_network_interface" "session_host" {
  count               = var.session_host_count
  name                = "${var.session_host_name_prefix}-${count.index + 1}-nic"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.session_hosts.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "session_host" {
  count                 = var.session_host_count
  name                  = "${var.session_host_name_prefix}-${count.index + 1}"
  computer_name         = substr(replace("${var.session_host_name_prefix}-${count.index + 1}", "-", ""), 0, 15)
  resource_group_name   = azurerm_resource_group.avd_rg.name
  location              = azurerm_resource_group.avd_rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.session_host[count.index].id]
  license_type          = "Windows_Client"
  provision_vm_agent    = true
  secure_boot_enabled   = true
  vtpm_enabled          = true
  tags                  = var.tags

  os_disk {
    name                 = "${var.session_host_name_prefix}-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_machine_extension" "entra_join" {
  count                      = var.session_host_count
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "time_rotating" "avd_registration" {
  rotation_days = 1
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hp.id
  expiration_date = timeadd(time_rotating.avd_registration.rfc3339, "48h")
}

resource "azurerm_virtual_machine_extension" "avd_agent_registration" {
  count                      = var.session_host_count
  name                       = "AVDSessionHostRegistration"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.83"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName          = azurerm_virtual_desktop_host_pool.hp.name
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.registration.token
      aadJoin               = true
    }
  })

  depends_on = [
    azurerm_virtual_machine_extension.entra_join
  ]
}

# ------------------------------------------------------------
# Microsoft Entra groups and RBAC for AVD access
# ------------------------------------------------------------
data "azuread_group" "avd_dag" {
  display_name     = var.avd_dag_group_name
  security_enabled = true
}

data "azuread_group" "avd_remoteapp" {
  display_name     = var.avd_remoteapp_group_name
  security_enabled = true
}

resource "azurerm_role_assignment" "desktop_app_group_assignment" {
  scope                = azurerm_virtual_desktop_application_group.desktop.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_dag.object_id
}

resource "azurerm_role_assignment" "office_remoteapp_assignment" {
  scope                = azurerm_virtual_desktop_application_group.office_remoteapp.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_remoteapp.object_id
}

resource "azurerm_role_assignment" "utilities_remoteapp_assignment" {
  scope                = azurerm_virtual_desktop_application_group.utilities_remoteapp.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_remoteapp.object_id
}

resource "azurerm_role_assignment" "vm_user_login" {
  scope                = azurerm_resource_group.avd_rg.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = data.azuread_group.avd_remoteapp.object_id
}

resource "azurerm_role_assignment" "vm_admin_login" {
  scope                = azurerm_resource_group.avd_rg.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azuread_group.avd_dag.object_id
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
output "resource_groups" {
  value = {
    network = azurerm_resource_group.vnet_rg.name
    avd     = azurerm_resource_group.avd_rg.name
  }
}

output "host_pool_name" {
  value = azurerm_virtual_desktop_host_pool.hp.name
}

output "workspace_name" {
  value = azurerm_virtual_desktop_workspace.ws.name
}

output "session_host_names" {
  value = azurerm_windows_virtual_machine.session_host[*].name
}
