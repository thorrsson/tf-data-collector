#!/usr/bin/env bash
set -euo pipefail

# Azure Subscription Data Collector
# This script finds an Azure subscription by partial name match and runs Terraform to collect data

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Collect Azure resource data from a subscription.

OPTIONS:
    -n, --name PATTERN       Partial subscription name to search for (case-insensitive)
    -i, --id SUBSCRIPTION_ID Exact subscription ID to use
    -p, --pretty-print       Display results in formatted tables
    -j, --json               Output only JSON (silence all other output)
    -h, --help              Show this help message

EXAMPLES:
    # Find subscription by partial name
    $0 --name "Production"
    
    # Use exact subscription ID with pretty output
    $0 --id "12345678-1234-1234-1234-123456789012" --pretty-print
    
    # Get JSON output only
    $0 --name "Production" --json
    
    # Use current subscription (no arguments)
    $0

EOF
    exit 1
}

# Parse arguments
SUBSCRIPTION_NAME=""
SUBSCRIPTION_ID=""
PRETTY_PRINT=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            SUBSCRIPTION_NAME="$2"
            shift 2
            ;;
        -i|--id)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -p|--pretty-print)
            PRETTY_PRINT=true
            shift
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Determine subscription ID
if [[ -n "$SUBSCRIPTION_ID" ]]; then
    [[ "$JSON_OUTPUT" == false ]] && echo "Using provided subscription ID: $SUBSCRIPTION_ID"
elif [[ -n "$SUBSCRIPTION_NAME" ]]; then
    [[ "$JSON_OUTPUT" == false ]] && echo "Searching for subscriptions matching: $SUBSCRIPTION_NAME"
    
    # Silence warnings in the Azure CLI
    AZURE_CLI_WARNINGS="--only-show-errors"
    # Get all subscriptions and filter with grep (case-insensitive)
    ALL_SUBS=$(az account list $AZURE_CLI_WARNINGS --query "[].{name:name, id:id}" -o json 2>/dev/null)
    MATCHING_SUBS=$(echo "$ALL_SUBS" | jq --arg pattern "$SUBSCRIPTION_NAME" '[.[] | select(.name | ascii_downcase | contains($pattern | ascii_downcase))]')
    
    # Count matches
    MATCH_COUNT=$(echo "$MATCHING_SUBS" | jq 'length')
    
    if [[ $MATCH_COUNT -eq 0 ]]; then
        echo "Error: No subscriptions found matching '$SUBSCRIPTION_NAME'" >&2
        if [[ "$JSON_OUTPUT" == false ]]; then
            echo "" >&2
            echo "Available subscriptions:" >&2
            az account list --query "[].{Name:name, ID:id}" -o table >&2
        fi
        exit 1
    elif [[ $MATCH_COUNT -gt 1 ]]; then
        if [[ "$JSON_OUTPUT" == false ]]; then
            echo "Warning: Multiple subscriptions match '$SUBSCRIPTION_NAME':"
            echo "$MATCHING_SUBS" | jq -r '.[] | "  - \(.name) (\(.id))"'
            echo ""
            echo "Using first match..."
        fi
    fi
    
    # Get the first matching subscription
    SUBSCRIPTION_ID=$(echo "$MATCHING_SUBS" | jq -r '.[0].id')
    SUBSCRIPTION_NAME_FULL=$(echo "$MATCHING_SUBS" | jq -r '.[0].name')
    
    [[ "$JSON_OUTPUT" == false ]] && echo "Found subscription: $SUBSCRIPTION_NAME_FULL"
    [[ "$JSON_OUTPUT" == false ]] && echo "Subscription ID: $SUBSCRIPTION_ID"
else
    # Use current subscription
    [[ "$JSON_OUTPUT" == false ]] && echo "No subscription specified, using current Azure CLI context"
    SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)
    SUBSCRIPTION_NAME_FULL=$(az account show --query name -o tsv 2>/dev/null)
    
    [[ "$JSON_OUTPUT" == false ]] && echo "Current subscription: $SUBSCRIPTION_NAME_FULL"
    [[ "$JSON_OUTPUT" == false ]] && echo "Subscription ID: $SUBSCRIPTION_ID"
fi

if [[ "$JSON_OUTPUT" == false ]]; then
    echo ""
    echo "---"
    echo ""
fi

# Initialize Terraform if needed
if [[ ! -d ".terraform" ]]; then
    [[ "$JSON_OUTPUT" == false ]] && echo "Initializing Terraform..."
    terraform init -input=false > /dev/null 2>&1
    [[ "$JSON_OUTPUT" == false ]] && echo "✓ Terraform initialized"
fi

[[ "$JSON_OUTPUT" == false ]] && echo "Collecting data from subscription..."
terraform apply -var="subscription_id=$SUBSCRIPTION_ID" -auto-approve -input=false > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo "Error: Terraform apply failed" >&2
    exit 1
fi

[[ "$JSON_OUTPUT" == false ]] && echo "✓ Data collection complete!"
[[ "$JSON_OUTPUT" == false ]] && echo ""

# Get the JSON output
OUTPUT_JSON=$(terraform output -json)

if [[ "$JSON_OUTPUT" == true ]]; then
    # Output clean JSON with only values (strip Terraform metadata)
    echo "$OUTPUT_JSON" | jq 'with_entries(.value = .value.value)'
elif [[ "$PRETTY_PRINT" == true ]]; then
    # Display formatted output
    echo "========================================"
    echo "SUBSCRIPTION INFORMATION"
    echo "========================================"
    echo ""
    echo "Name: $(echo "$OUTPUT_JSON" | jq -r '.subscription_name.value')"
    echo "ID:   $(echo "$OUTPUT_JSON" | jq -r '.subscription_id.value')"
    echo ""
    
    # Resource Groups
    echo "========================================"
    echo "RESOURCE GROUPS"
    echo "========================================"
    echo ""
    echo "$OUTPUT_JSON" | jq -r '.resource_groups.value | to_entries | ["NAME", "LOCATION", "ID"], ["----", "--------", "--"], (.[] | [.value.name, .value.location, .value.id]) | @tsv' | column -t -s $'\t'
    echo ""
    
    # Virtual Networks
    echo "========================================"
    echo "VIRTUAL NETWORKS"
    echo "========================================"
    echo ""
    echo "$OUTPUT_JSON" | jq -r '.virtual_networks.value | to_entries | ["NAME", "RESOURCE_GROUP", "LOCATION", "ADDRESS_SPACE"], ["----", "--------------", "--------", "-------------"], (.[] | [.value.name, .value.resource_group, .value.location, (.value.address_space | join(", "))]) | @tsv' | column -t -s $'\t'
    echo ""
    
    # NAT Gateway IPs
    echo "========================================"
    echo "NAT GATEWAY PUBLIC IPs"
    echo "========================================"
    echo ""
    NAT_GATEWAYS=$(echo "$OUTPUT_JSON" | jq -r '.nat_gateway_ips.value | to_entries[]')
    if [[ -n "$NAT_GATEWAYS" ]]; then
        echo "$OUTPUT_JSON" | jq -r '.nat_gateway_ips.value | to_entries[] | 
            "NAT Gateway: \(.value.nat_gateway_name)",
            "Resource Group: \(.value.resource_group)",
            "Location: \(.value.location)",
            "Public IPs:",
            (.value.public_ips[] | "  - \(.name): \(.ip_address)"),
            ""'
    else
        echo "No NAT Gateways found"
        echo ""
    fi
    
    # Storage Accounts
    echo "========================================"
    echo "STORAGE ACCOUNTS"
    echo "========================================"
    echo ""
    echo "$OUTPUT_JSON" | jq -r '.storage_accounts.value | to_entries | ["NAME", "RESOURCE_GROUP", "LOCATION", "TIER", "REPLICATION"], ["----", "--------------", "--------", "----", "-----------"], (.[] | [.value.name, .value.resource_group, .value.location, .value.account_tier, .value.account_replication_type]) | @tsv' | column -t -s $'\t'
    echo ""
    
else
    # Default: Show simple summary and instructions
    echo "Summary:"
    echo "  Subscription: $(echo "$OUTPUT_JSON" | jq -r '.subscription_name.value')"
    echo "  Resource Groups: $(echo "$OUTPUT_JSON" | jq -r '.resource_groups.value | length')"
    echo "  Virtual Networks: $(echo "$OUTPUT_JSON" | jq -r '.virtual_networks.value | length')"
    echo "  NAT Gateways: $(echo "$OUTPUT_JSON" | jq -r '.nat_gateway_ips.value | length')"
    echo "  Storage Accounts: $(echo "$OUTPUT_JSON" | jq -r '.storage_accounts.value | length')"
    echo ""
    echo "View detailed outputs with:"
    echo "  terraform output                    # All outputs (JSON)"
    echo "  terraform output subscription_name  # Subscription name"
    echo "  terraform output resource_groups    # Resource groups"
    echo "  terraform output virtual_networks   # Virtual networks"
    echo "  terraform output nat_gateway_ips    # NAT gateway IPs"
    echo "  terraform output storage_accounts   # Storage accounts"
    echo ""
    echo "Or run with --pretty-print for formatted tables"
fi
