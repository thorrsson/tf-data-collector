# Azure Subscription Data Collector

This Terraform module collects comprehensive data about Azure resources in a specific subscription.

## Features

This module retrieves the following information from an Azure subscription:
- Subscription name and ID
- NAT Gateway details and associated public IP addresses
- Virtual Networks (names, IDs, address spaces)
- Resource Groups (names, IDs, locations)
- Storage Accounts (names, IDs, configuration details)

## Prerequisites

- Terraform >= 1.0
- Azure CLI installed and authenticated
- Appropriate Azure permissions to read resources in the target subscription

## Authentication

Before running this module, authenticate to Azure using one of these methods:

### Azure CLI (Recommended)
```bash
az login
az account set --subscription <subscription-id>
```

### Service Principal
Set the following environment variables:
```bash
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

## Usage

You can specify the target subscription in three ways:

### Option 1: By Subscription ID (Recommended)

Create a `terraform.tfvars` file:
```hcl
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Option 2: By Partial Subscription Name

Search for a subscription by partial name match (case-insensitive):
```hcl
subscription_name_filter = "Production"
# This will match subscriptions like "Production-East", "Prod-Production-Sub", etc.
```

**Note:** If multiple subscriptions match the filter, the first one will be used.

### Option 3: Use Current Subscription Context

Use the currently selected subscription:
```hcl
use_current_subscription = true
```

### Running the Module

1. Initialize Terraform:
```hcl
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

2. Initialize Terraform:
```bash
terraform init
```

3. Run the plan to see what data will be collected:
```bash
terraform plan
```

4. Apply the configuration to collect the data:
```bash
terraform apply
```

5. View specific outputs:
```bash
# View subscription name
terraform output subscription_name

# View all virtual networks
terraform output virtual_networks

# View NAT gateway IPs
terraform output nat_gateway_ips

# View resource groups
terraform output resource_groups

# View storage accounts
terraform output storage_accounts
```

## Example

```hcl
# Using as a module with subscription ID
module "azure_data_collector" {
  source = "./tf-data-collector"
  
  subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}

# Using as a module with subscription name filter
module "azure_data_collector_by_name" {
  source = "./tf-data-collector"
  
  subscription_name_filter = "Production"
}

# Using as a module with current subscription
module "azure_data_collector_current" {
  source = "./tf-data-collector"
  
  use_current_subscription = true
}

# Access outputs
output "subscription_info" {
  value = module.azure_data_collector.subscription_name
}

output "networks" {
  value = module.azure_data_collector.virtual_networks
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| subscription_id | The Azure subscription ID to collect data from | string | null | No* |
| subscription_name_filter | Filter subscriptions by partial name match (case-insensitive) | string | null | No* |
| use_current_subscription | Use the current subscription context | bool | false | No* |

*At least one of these must be provided, or the module will use the current subscription context.

## Outputs

| Name | Description |
|------|-------------|
| subscription_name | The display name of the Azure subscription |
| subscription_id | The Azure subscription ID |
| nat_gateway_ips | Map of NAT Gateways with their associated public IP addresses |
| virtual_networks | Map of virtual networks with names, IDs, and address spaces |
| resource_groups | Map of resource groups with names, IDs, and locations |
| storage_accounts | Map of storage accounts with names, IDs, and configuration |

## Notes

- This module only performs read operations and does not create or modify any resources
- When using `subscription_name_filter`, the search is case-insensitive and matches partial names
- If multiple subscriptions match the name filter, the first match will be used
- Resource groups are discovered based on the resources found (VNets, Storage Accounts, NAT Gateways)
- Execution time may vary depending on the number of resources in the subscription
- Some resources may not be visible if you lack appropriate permissions

## License

This module is provided as-is for infrastructure data collection purposes.
