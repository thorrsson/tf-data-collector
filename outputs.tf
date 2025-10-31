# Subscription Information
output "subscription_name" {
  description = "The name of the Azure subscription"
  value       = data.azurerm_subscription.current.display_name
}

output "subscription_id" {
  description = "The Azure subscription ID"
  value       = data.azurerm_subscription.current.subscription_id
}

# NAT Gateway IPs
output "nat_gateway_ips" {
  description = "NAT Gateway public IP addresses"
  value = {
    for nat_name, nat in data.azurerm_nat_gateway.nat : nat_name => {
      nat_gateway_name = nat.name
      resource_group   = nat.resource_group_name
      location         = nat.location
      public_ip_ids    = nat.public_ip_address_ids
      public_ips = [
        for pip_name, pip in data.azurerm_public_ip.pip :
        {
          name       = pip.name
          ip_address = pip.ip_address
        }
        if contains(nat.public_ip_address_ids, pip.id)
      ]
    }
  }
}

# Virtual Networks
output "virtual_networks" {
  description = "Virtual network names and IDs"
  value = {
    for vnet_name, vnet in data.azurerm_virtual_network.vnet : vnet_name => {
      name           = vnet.name
      id             = vnet.id
      resource_group = vnet.resource_group_name
      location       = vnet.location
      address_space  = vnet.address_space
    }
  }
}

# Resource Groups
output "resource_groups" {
  description = "Resource group names and IDs"
  value = {
    for rg_name, rg in data.azurerm_resource_group.rg : rg_name => {
      name     = rg.name
      id       = rg.id
      location = rg.location
    }
  }
}

# Storage Accounts
output "storage_accounts" {
  description = "Storage account names and IDs"
  value = {
    for sa_name, sa in data.azurerm_storage_account.storage : sa_name => {
      name                     = sa.name
      id                       = sa.id
      resource_group           = sa.resource_group_name
      location                 = sa.location
      account_tier             = sa.account_tier
      account_replication_type = sa.account_replication_type
      primary_blob_endpoint    = sa.primary_blob_endpoint
    }
  }
}
