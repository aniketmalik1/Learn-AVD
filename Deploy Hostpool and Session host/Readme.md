# Azure Virtual Desktop Lab - Terraform Deployment

This repository contains a simple Terraform version of the lab **Deploy host pools and session hosts by using the Azure portal (Entra ID)**.

It creates an Azure Virtual Desktop environment with Microsoft Entra joined session hosts, matching the major resources from the lab manual:

- Virtual network: `az140-vnet11e`
- Subnet: `hp1-Subnet`
- Host pool: `az140-21-hp1`
- Desktop application group: `az140-21-hp1-DAG`
- RemoteApp application groups:
  - `az140-21-hp1-Office365-RAG`
  - `az140-21-hp1-Utilities-RAG`
- Workspace: `az140-21-ws1`
- Two Windows 11 Enterprise multi-session session hosts
- RBAC assignments for AVD user login and administrator login

## Files

| File | Purpose |
|---|---|
| `main.tf` | Terraform provider setup, variables, Azure resources, app groups, session host VMs, RBAC assignments, and outputs. |
| `terraform.tfvars` | Input values you must customize, such as subscription ID, tenant ID, location, password, and Entra group names. |
| `readme.md` | This guide. |

## What is Azure Virtual Desktop?

Azure Virtual Desktop, often called AVD, is Microsoft's cloud desktop and app virtualization service. It lets users access full Windows desktops or individual RemoteApps from supported clients, while the session host virtual machines run in Azure.

In this lab, users connect to AVD resources through application groups that are registered to a workspace. Access is granted through Microsoft Entra security groups and Azure role-based access control.

## What is an AVD host pool?

An AVD host pool is a collection of Azure virtual machines registered to Azure Virtual Desktop as session hosts. Users connect to these session hosts to run desktops or applications.

This lab uses a **pooled** host pool:

- Multiple users can share session hosts.
- New sessions are distributed using **BreadthFirst** load balancing.
- The host pool is configured with the preferred app group type **Desktop**.

## What are session hosts?

Session hosts are the Windows virtual machines that provide the actual desktop or RemoteApp experience. In this lab, Terraform creates two Windows 11 Enterprise multi-session VMs using the Microsoft 365 Apps image.

The session hosts are:

- Deployed without public IP addresses.
- Connected to the `hp1-Subnet` subnet.
- Configured for Trusted Launch using secure boot and vTPM.
- Joined to Microsoft Entra ID by the `AADLoginForWindows` VM extension.
- Registered to the AVD host pool by the AVD registration extension.

## What is a virtual network?

A virtual network, or VNet, is the private network boundary where Azure resources communicate. In this lab, the VNet is named `az140-vnet11e` and uses the address space `10.20.0.0/16`.

The session hosts are deployed into the subnet named `hp1-Subnet`, using the address prefix `10.20.1.0/24`.

## What is an application group?

An application group controls what users can access from a host pool.

This Terraform code creates three application groups:

1. Desktop application group publishes a full desktop.
2. Office RemoteApp group publishes Microsoft Word, Excel, and PowerPoint.
3. Utilities RemoteApp group publishes Command Prompt.

Users must be assigned to the correct application group before resources appear in the AVD client.

## What is a workspace?

A workspace is the user-facing container that presents desktops and RemoteApps to users. Application groups must be registered to a workspace. If an application group is not associated with a workspace, users will not see it in the AVD client.

This lab creates the workspace `az140-21-ws1` and associates all three application groups with it.

## What is Microsoft Entra joined AVD?

Microsoft Entra joined session hosts are Windows VMs joined directly to Microsoft Entra ID instead of being joined to an on-premises Active Directory domain. Users authenticate with Microsoft Entra ID, and Azure RBAC roles are required for sign-in permissions.

For this lab:

- `Virtual Machine User Login` is assigned to the RemoteApp group.
- `Virtual Machine Administrator Login` is assigned to the Desktop group.
- `Desktop Virtualization User` is assigned to the relevant AVD application groups.

## Prerequisites

Before running Terraform, make sure you have:

1. An Azure subscription.
2. A Microsoft Entra account with sufficient permissions.
3. Terraform installed locally or access to Azure Cloud Shell.
4. Azure CLI authenticated with `az login`.
5. The Microsoft Entra security groups:
   - Group starting with `AVD-DAG`
   - Group starting with `AVD-RemoteApp`

## Update terraform.tfvars

```hcl
subscription_id = "00000000-0000-0000-0000-000000000000"
tenant_id       = "00000000-0000-0000-0000-000000000000"
location        = "eastus"

session_host_name_prefix = "sh-random"
admin_password           = "Replace-With-Strong-Password123!"

avd_dag_group_name       = "AVD-DAG-REPLACE-ME"
avd_remoteapp_group_name = "AVD-RemoteApp-REPLACE-ME"
```

For `session_host_name_prefix`, follow the lab manual: use `sh-` plus the random string between `User1-` and `@` from the lab Resources tab.

## Terraform commands

```bash
terraform init
terraform fmt
terraform validate
terraform plan -out avd.tfplan
terraform apply avd.tfplan
```

To remove the lab resources:

```bash
terraform destroy
```

## Notes and customization

- The default image SKU is `win11-23h2-avd-m365`.
- If the image SKU is unavailable in your selected region, update `image_sku`.
- RemoteApp paths assume Microsoft 365 Apps are installed under:
  `C:\Program Files\Microsoft Office\root\Office16`
- Local Terraform state is used by default.
- For production environments, configure remote state storage, monitoring, diagnostics, FSLogix, scaling plans, and backup policies.
