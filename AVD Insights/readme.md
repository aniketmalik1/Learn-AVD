# Azure Virtual Desktop Monitoring Lab - Terraform Deployment

This repository contains a Terraform implementation of the Azure Virtual Desktop Monitoring lab.

The solution configures Azure Virtual Desktop Insights, Log Analytics, Azure Monitor Agent (AMA), Data Collection Rules (DCR), and Diagnostic Settings for an existing Azure Virtual Desktop environment.

---

# Architecture

```text
Azure Virtual Desktop
        │
        ├── Host Pool (az140-21-hp1)
        ├── Workspace (az140-21-ws1)
        ├── Application Groups
        │
        ▼
Diagnostic Settings (allLogs)
        │
        ▼
Log Analytics Workspace
(az140-laworkspace41e)
        │
        ▼
Azure Virtual Desktop Insights
```

Session Hosts

```text
sh-random-1
sh-random-2
...
sh-random-100
```

All session hosts send performance counters and event logs to Azure Monitor through Azure Monitor Agent and Data Collection Rules.

---

# Resources Created

## Resource Provider

```text
Microsoft.Insights
```

Required for Azure Monitor, Diagnostic Settings, and Azure Virtual Desktop Insights.

---

## Monitoring Resource Group

```text
az140-411e-RG
```

Contains monitoring resources.

---

## Log Analytics Workspace

```text
az140-laworkspace41e
```

Stores:

- AVD diagnostic logs
- Windows Event Logs
- Performance Counters
- Azure Monitor data
- Connection telemetry

---

## Data Collection Rule (DCR)

Example:

```text
microsoft-avdi-az140-21-hp1-dcr
```

Collects:

### Performance Counters

- CPU Utilization
- Available Memory
- Disk Free Space
- Disk Read Latency
- Disk Write Latency
- Active Sessions
- Inactive Sessions
- RTT Latency
- UDP Bandwidth

### Event Logs

- Application
- System
- Terminal Services Logs
- Remote Desktop Logs
- Session Manager Logs

---

## Azure Monitor Agent (AMA)

Installed on all AVD Session Hosts.

Purpose:

- Collect guest OS metrics
- Collect event logs
- Send telemetry to Log Analytics

---

# Dynamic Session Host Support

Instead of manually maintaining:

```hcl
session_host_vm_names = [
  "sh-random-1",
  "sh-random-2",
  ...
  "sh-random-100"
]
```

the Terraform code uses:

```hcl
session_host_prefix = "sh-random"
session_host_count  = 100
```

and generates:

```hcl
locals {
  session_host_vm_names = [
    for i in range(1, var.session_host_count + 1) :
    "${var.session_host_prefix}-${i}"
  ]
}
```

Result:

```text
sh-random-1
sh-random-2
sh-random-3
...
sh-random-100
```

This approach is scalable and easier to maintain. Terraform's `range()` function generates numeric sequences that can be used to build these names dynamically. 【1-5c8808】

---

# What is Azure Virtual Desktop Insights?

Azure Virtual Desktop Insights is a monitoring dashboard built on Azure Monitor Workbooks.

It provides operational visibility into:

- Session Hosts
- Host Pools
- User Connections
- Connection Reliability
- Performance
- Capacity
- Utilization
- Client Usage
- Alerts

Azure Virtual Desktop Insights uses Log Analytics data and session host telemetry to build these dashboards. 【2-c0ddce】

---

# What Can Be Monitored?

## 1. Capacity

Monitor:

- Session host availability
- Capacity trends
- Session distribution
- Overloaded hosts
- Underutilized hosts

---

## 2. Connection Diagnostics

Monitor:

- Successful connections
- Failed connections
- Connection stages
- Authentication issues
- Service-side failures

---

## 3. Percentage of Users Able to Connect

Example:

```text
98.5% users connected successfully
1.5% connection failures
```

Useful for measuring service health.

---

## 4. Connection Performance

Monitor:

- User sign-in latency
- Brokering time
- Connection establishment time
- Total connection duration

---

## 5. Connection Reliability

Monitor:

- Successful connections
- Connection failures
- Reconnections
- Disconnect trends

---

## 6. Users

Monitor:

- Active users
- User connection history
- Repeated failures
- User experience trends

---

## 7. Utilization

Monitor:

- CPU usage
- Memory usage
- Disk consumption
- Active sessions
- Inactive sessions

Useful for scaling decisions.

---

## 8. Clients

Monitor:

- Windows clients
- macOS clients
- Web clients
- Mobile clients

Review connection success by client type.

---

## 9. Alerts

Monitor:

- Agent failures
- Host health issues
- Excessive connection failures
- Performance issues
- Host registration issues

---

## 10. Data Generated

Monitor:

### Billed Data Last 24 Hours

Shows Log Analytics ingestion.

### Performance Counters

Shows:

- CPU
- Memory
- Disk
- Session metrics

### Events

Shows Windows Event data.

---

# Azure Virtual Desktop Diagnostic Categories

Diagnostic logs include:

| Category | Description |
| ---------- | ---------- |
| Management Activities | Changes to AVD resources |
| Feed | Workspace subscription activity |
| Connections | User connections |
| Host Registration | Session host registration |
| Errors | User and service errors |
| Checkpoints | Connection stages |
| Agent Health Status | Agent health |
| Network | Network telemetry |
| Connection Graphics Performance | Visual experience metrics |
| Session Host Management Activity | Session host operations |
| Autoscale | Autoscale activity |

These categories can be sent to Log Analytics using Diagnostic Settings and analyzed through Azure Virtual Desktop Insights. 【3-b266d1】

---

# How Many Things Can We Check in AVD Insights?

You can monitor at least the following operational areas:

1. Capacity
2. Available Hosts
3. Session Distribution
4. User Connections
5. Failed Connections
6. Connection Reliability
7. Connection Diagnostics
8. Connection Performance
9. User Experience
10. Host Registration
11. Agent Health
12. CPU Usage
13. Memory Usage
14. Disk Usage
15. Active Sessions
16. Inactive Sessions
17. Network Metrics
18. RTT Latency
19. Windows Events
20. Performance Counters
21. Workspace Activity
22. Feed Activity
23. Application Group Activity
24. Management Activities
25. Autoscale Events
26. Connection Graphics Performance
27. Data Ingestion
28. Log Analytics Usage
29. Alerts
30. Resource Health

---

# Terraform Commands

```bash
terraform init
terraform fmt
terraform validate
terraform plan -out monitoring.tfplan
terraform apply monitoring.tfplan
```

Destroy resources:

```bash
terraform destroy
```

---

# Validation Checklist

After deployment verify:

- Microsoft.Insights is registered
- Log Analytics workspace exists
- Host Pool diagnostics enabled
- Workspace diagnostics enabled
- Application Group diagnostics enabled
- DCR exists
- AMA installed
- DCR associated with hosts
- No workbook warnings
- Insights dashboard displays telemetry

---

# Cost Considerations

Monitor:

```text
Billed Data over Last 24 Hours
```

inside AVD Insights.

Log Analytics charges are based on:

- Data ingestion
- Data retention
- Data storage

Always review ingestion volume in test environments.
