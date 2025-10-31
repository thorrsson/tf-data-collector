# Get subscription details
data "azurerm_subscription" "current" {
  subscription_id = var.subscription_id
}

# Get all virtual networks to discover resource groups
data "azurerm_resources" "all_resources" {
  type = "Microsoft.Network/virtualNetworks"
}

# Also get storage accounts to discover more resource groups
data "azurerm_resources" "storage_resources" {
  type = "Microsoft.Storage/storageAccounts"
}

# Also get NAT gateways to discover more resource groups
data "azurerm_resources" "nat_resources" {
  type = "Microsoft.Network/natGateways"
}

# Combine all resource groups from discovered resources
locals {
  discovered_resource_groups = toset(concat(
    [for r in data.azurerm_resources.all_resources.resources : r.resource_group_name],
    [for r in data.azurerm_resources.storage_resources.resources : r.resource_group_name],
    [for r in data.azurerm_resources.nat_resources.resources : r.resource_group_name]
  ))
}

# Get details for each discovered resource group
data "azurerm_resource_group" "rg" {
  for_each = local.discovered_resource_groups
  name     = each.value
}

# Get all virtual networks
data "azurerm_resources" "vnets" {
  type = "Microsoft.Network/virtualNetworks"
}

# Get details for each virtual network
data "azurerm_virtual_network" "vnet" {
  for_each            = toset([for vnet in data.azurerm_resources.vnets.resources : vnet.name])
  name                = each.value
  resource_group_name = [for vnet in data.azurerm_resources.vnets.resources : vnet.resource_group_name if vnet.name == each.value][0]
}

# Get all NAT Gateways
data "azurerm_resources" "nat_gateways" {
  type = "Microsoft.Network/natGateways"
}

# Get details for each NAT Gateway
data "azurerm_nat_gateway" "nat" {
  for_each            = toset([for nat in data.azurerm_resources.nat_gateways.resources : nat.name])
  name                = each.value
  resource_group_name = [for nat in data.azurerm_resources.nat_gateways.resources : nat.resource_group_name if nat.name == each.value][0]
}

# Get all public IPs (to find those associated with NAT Gateways)
data "azurerm_resources" "public_ips" {
  type = "Microsoft.Network/publicIPAddresses"
}

# Get details for each public IP
data "azurerm_public_ip" "pip" {
  for_each            = toset([for pip in data.azurerm_resources.public_ips.resources : pip.name])
  name                = each.value
  resource_group_name = [for pip in data.azurerm_resources.public_ips.resources : pip.resource_group_name if pip.name == each.value][0]
}

# Get all storage accounts
data "azurerm_resources" "storage_accounts" {
  type = "Microsoft.Storage/storageAccounts"
}

# Get details for each storage account
data "azurerm_storage_account" "storage" {
  for_each            = toset([for sa in data.azurerm_resources.storage_accounts.resources : sa.name])
  name                = each.value
  resource_group_name = [for sa in data.azurerm_resources.storage_accounts.resources : sa.resource_group_name if sa.name == each.value][0]
}
