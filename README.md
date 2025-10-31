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

### Quick Start with Shell Script (Recommended)

The easiest way to use this module is with the included `collect-data.sh` wrapper script:

```bash
# Search by partial subscription name
./collect-data.sh --name "Production"

# Use exact subscription ID
./collect-data.sh --id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Use current Azure CLI subscription
./collect-data.sh

# Get formatted table output
./collect-data.sh --name "Production" --pretty-print
```

### Direct Terraform Usage

If you prefer to use Terraform directly:

1. Create a `terraform.tfvars` file:
```hcl
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

2. Initialize Terraform:
```bash
terraform init
```

3. Apply the configuration:
```bash
terraform apply
```

4. View outputs:
```bash
terraform output                    # All outputs
terraform output subscription_name  # Subscription name only
terraform output resource_groups    # Resource groups only
```

## Shell Script Options

The `collect-data.sh` script supports the following options:

```
OPTIONS:
    -n, --name PATTERN       Partial subscription name to search for (case-insensitive)
    -i, --id SUBSCRIPTION_ID Exact subscription ID to use
    -p, --pretty-print       Display results in formatted tables
    -j, --json               Output only JSON (no other logging)
    -h, --help              Show this help message
```

### Examples

```bash
# Find subscription by partial name with formatted output
./collect-data.sh --name "jpw" --pretty-print

# Use specific subscription ID
./collect-data.sh --id "83f3fbe9-ef57-45b8-921e-337672499d21"

# Get clean JSON output for parsing
./collect-data.sh --name "Production" --json

# Use current subscription context
./collect-data.sh
```

## Example

```hcl
# Using as a module with subscription ID
module "azure_data_collector" {
  source = "./tf-data-collector"
  
  subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
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
| subscription_id | The Azure subscription ID to collect data from | string | n/a | Yes |

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
- Use the `collect-data.sh` script for easy subscription lookup by partial name
- The `--pretty-print` option provides formatted table output for easy reading
- Resource groups are discovered based on the resources found (VNets, Storage Accounts, NAT Gateways)
- Execution time may vary depending on the number of resources in the subscription
- Some resources may not be visible if you lack appropriate permissions

## License

This module is provided as-is for infrastructure data collection purposes.
