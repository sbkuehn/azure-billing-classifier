#!/bin/bash

# Classify Azure subscriptions by billing structure
# Detects EA vs MCA, CSP indicators, and MACC
# Author: Shannon Eldridge-Kuehn
# Date: January 2026

set -euo pipefail

OUTPUT_FILE="${1:-azure-billing-classification.csv}"
BILLING_API_VERSION="2024-04-01"
SUB_API_VERSION="2020-01-01"
CONSUMPTION_API_VERSION="2024-08-01"

echo "Azure Billing Classification Script"
echo "===================================="
echo ""

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure CLI. Run 'az login' first."
    exit 1
fi

echo "Listing subscriptions..."
SUBS=$(az account list --query "[].{id:id, name:name}" -o json)

if [ -z "$SUBS" ] || [ "$SUBS" == "[]" ]; then
    echo "Error: No subscriptions found"
    exit 1
fi

SUB_COUNT=$(echo "$SUBS" | jq '. | length')
echo "Found $SUB_COUNT subscription(s)"
echo ""

# Prepare CSV header
echo "SubscriptionName,SubscriptionId,OfferType,AgreementType,IsCSP,CSPEvidence,HasMACC,BillingAccountId,BillingScopeId" > "$OUTPUT_FILE"

# Cache for API calls
declare -A BILLING_ACCOUNT_CACHE
declare -A LOTS_CACHE
declare -A CUSTOMERS_CACHE

# Function to extract billing account ID from scope
extract_billing_account_id() {
    local scope="$1"
    if [ -z "$scope" ]; then
        echo ""
        return
    fi
    
    # Extract billing account ID using regex
    if [[ $scope =~ /billingAccounts/([^/]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to check if scope is CSP
is_csp_scope() {
    local scope="$1"
    if [[ $scope == *"/customers/"* ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Process each subscription
echo "$SUBS" | jq -c '.[]' | while read -r sub; do
    SUB_ID=$(echo "$sub" | jq -r '.id')
    SUB_NAME=$(echo "$sub" | jq -r '.name')
    
    echo "Processing: $SUB_NAME"
    
    # Get subscription details
    SUB_DETAILS=$(az rest --method get \
        --url "https://management.azure.com/subscriptions/$SUB_ID?api-version=$SUB_API_VERSION" \
        2>/dev/null || echo "{}")
    
    BILLING_SCOPE=$(echo "$SUB_DETAILS" | jq -r '.subscriptionPolicies.billingScopeId // empty')
    OFFER_TYPE=$(echo "$SUB_DETAILS" | jq -r '.subscriptionPolicies.quotaId // empty')
    
    BILLING_ACCOUNT_ID=$(extract_billing_account_id "$BILLING_SCOPE")
    
    AGREEMENT_TYPE=""
    HAS_MACC="false"
    IS_CSP="false"
    CSP_EVIDENCE=""
    
    # Check CSP from scope
    if [ -n "$BILLING_SCOPE" ]; then
        IS_CSP=$(is_csp_scope "$BILLING_SCOPE")
        if [ "$IS_CSP" == "true" ]; then
            CSP_EVIDENCE="billingScopeId contains /customers/"
        fi
    fi
    
    # Get billing account details if available
    if [ -n "$BILLING_ACCOUNT_ID" ]; then
        # Get or use cached billing account info
        if [ -z "${BILLING_ACCOUNT_CACHE[$BILLING_ACCOUNT_ID]+x}" ]; then
            ACCT=$(az rest --method get \
                --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$BILLING_ACCOUNT_ID?api-version=$BILLING_API_VERSION" \
                2>/dev/null || echo "{}")
            BILLING_ACCOUNT_CACHE[$BILLING_ACCOUNT_ID]="$ACCT"
        else
            ACCT="${BILLING_ACCOUNT_CACHE[$BILLING_ACCOUNT_ID]}"
        fi
        
        AGREEMENT_TYPE=$(echo "$ACCT" | jq -r '.properties.agreementType // empty')
        
        # Check for customers (CSP indicator)
        if [ -z "${CUSTOMERS_CACHE[$BILLING_ACCOUNT_ID]+x}" ]; then
            CUSTOMERS=$(az rest --method get \
                --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$BILLING_ACCOUNT_ID/customers?api-version=$BILLING_API_VERSION" \
                2>/dev/null || echo '{"value":[]}')
            CUSTOMERS_CACHE[$BILLING_ACCOUNT_ID]="$CUSTOMERS"
        else
            CUSTOMERS="${CUSTOMERS_CACHE[$BILLING_ACCOUNT_ID]}"
        fi
        
        CUSTOMER_COUNT=$(echo "$CUSTOMERS" | jq '.value | length')
        if [ "$CUSTOMER_COUNT" -gt 0 ]; then
            IS_CSP="true"
            if [ -n "$CSP_EVIDENCE" ]; then
                CSP_EVIDENCE="$CSP_EVIDENCE; billing account has customers"
            else
                CSP_EVIDENCE="billing account has customers"
            fi
        fi
        
        # Check for MACC
        if [ -z "${LOTS_CACHE[$BILLING_ACCOUNT_ID]+x}" ]; then
            LOTS=$(az rest --method get \
                --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$BILLING_ACCOUNT_ID/providers/Microsoft.Consumption/lots?api-version=$CONSUMPTION_API_VERSION" \
                2>/dev/null || echo '{"value":[]}')
            LOTS_CACHE[$BILLING_ACCOUNT_ID]="$LOTS"
        else
            LOTS="${LOTS_CACHE[$BILLING_ACCOUNT_ID]}"
        fi
        
        LOT_COUNT=$(echo "$LOTS" | jq '.value | length')
        if [ "$LOT_COUNT" -gt 0 ]; then
            HAS_MACC="true"
        fi
    fi
    
    # Escape commas and quotes in strings for CSV
    SUB_NAME_ESCAPED=$(echo "$SUB_NAME" | sed 's/"/""/g')
    CSP_EVIDENCE_ESCAPED=$(echo "$CSP_EVIDENCE" | sed 's/"/""/g')
    BILLING_SCOPE_ESCAPED=$(echo "$BILLING_SCOPE" | sed 's/"/""/g')
    
    # Write to CSV
    echo "\"$SUB_NAME_ESCAPED\",\"$SUB_ID\",\"$OFFER_TYPE\",\"$AGREEMENT_TYPE\",\"$IS_CSP\",\"$CSP_EVIDENCE_ESCAPED\",\"$HAS_MACC\",\"$BILLING_ACCOUNT_ID\",\"$BILLING_SCOPE_ESCAPED\"" >> "$OUTPUT_FILE"
done

echo ""
echo "================================"
echo "Classification complete!"
echo "Results written to: $OUTPUT_FILE"
echo "================================"

# Display summary
echo ""
echo "Summary:"
EA_COUNT=$(awk -F',' '$4=="EnterpriseAgreement"' "$OUTPUT_FILE" | wc -l)
MCA_COUNT=$(awk -F',' '$4=="MicrosoftCustomerAgreement"' "$OUTPUT_FILE" | wc -l)
CSP_COUNT=$(awk -F',' '$5=="true"' "$OUTPUT_FILE" | wc -l)
MACC_COUNT=$(awk -F',' '$7=="true"' "$OUTPUT_FILE" | wc -l)

echo "  Enterprise Agreement:   $EA_COUNT"
echo "  Microsoft Customer Agr: $MCA_COUNT"
echo "  CSP Detected:           $CSP_COUNT"
echo "  Has MACC:               $MACC_COUNT"
echo ""
