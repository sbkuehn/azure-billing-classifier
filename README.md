# Azure Billing Classifier

Automatically classify Azure subscriptions by billing structure and detect EA vs MCA, CSP indicators, and MACC (Microsoft Azure Consumption Commitment).

## Overview

Azure billing has multiple layers that are often confused: agreements (EA vs MCA), commitments (MACC), and subscription offers (PAYG, CSP, etc.). This tool helps you identify exactly what billing structure your subscriptions use, eliminating guesswork and enabling accurate cost reporting.

## What It Does

For each Azure subscription you have access to, the classifier:

- ✅ Retrieves the billing scope and billing account
- ✅ Identifies agreement type (Enterprise Agreement or Microsoft Customer Agreement)
- ✅ Detects CSP (Cloud Solution Provider) indicators
- ✅ Checks for MACC (consumption commitment lots)
- ✅ Exports results to CSV for analysis

## Quick Start

### Prerequisites

- Azure CLI installed and configured (`az login`)
- Billing Account Reader role (or higher) on billing accounts
- PowerShell 5.1+ (for PowerShell script) or Bash 4+ (for bash script)

### PowerShell

```powershell
# Run the classifier
.\Classify-AzureBilling.ps1

# Specify custom output path
.\Classify-AzureBilling.ps1 -OutputPath ".\my-results.csv"

# Hide detailed output, show only summary
.\Classify-AzureBilling.ps1 -ShowDetails $false
```

### Bash

```bash
# Make the script executable
chmod +x classify-azure-billing.sh

# Run the classifier
./classify-azure-billing.sh

# Specify custom output path
./classify-azure-billing.sh my-results.csv
```

## Output

The script generates a CSV file with the following columns:

| Column | Description |
|--------|-------------|
| **SubscriptionName** | Display name of the subscription |
| **SubscriptionId** | Subscription GUID |
| **OfferType** | Subscription offer (e.g., MS-AZR-0017P for PAYG) |
| **AgreementType** | `EnterpriseAgreement` or `MicrosoftCustomerAgreement` |
| **IsCSP** | Boolean indicating CSP detection |
| **CSPEvidence** | Details of why CSP was detected |
| **HasMACC** | Boolean indicating consumption commitment |
| **BillingAccountId** | Billing account ID |
| **BillingScopeId** | Full billing scope path |

## Common Patterns

After running the script, you'll typically see one of these patterns:

### Pattern 1: Pure EA Environment
```
AgreementType: EnterpriseAgreement
IsCSP: false
HasMACC: false
```

### Pattern 2: Modern MCA Environment
```
AgreementType: MicrosoftCustomerAgreement
IsCSP: false
HasMACC: true/false (depends on contract)
```

### Pattern 3: CSP Environment
```
AgreementType: MicrosoftCustomerAgreement
IsCSP: true
BillingScopeId: contains /customers/
```

### Pattern 4: Hybrid Environment
```
Mixed EnterpriseAgreement and MicrosoftCustomerAgreement
Various CSP and MACC states
```

## Individual Commands

If you prefer to run individual commands instead of the full script:

### List Billing Accounts

```bash
az billing account list \
  --query "[].{BillingAccount:name, Agreement:agreementType, DisplayName:displayName}" \
  -o table
```

### Check for MACC

```bash
az rest \
  --method get \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/providers/Microsoft.Consumption/lots?api-version=2024-08-01" \
  -o table
```

### Trace Subscription to Billing

```bash
az rest \
  --method get \
  --url "https://management.azure.com/subscriptions/<subscriptionId>?api-version=2020-01-01" \
  --query "subscriptionPolicies.billingScopeId"
```

### Detect CSP

```bash
az rest \
  --method get \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/customers?api-version=2024-04-01" \
  -o table
```

## Troubleshooting

### Script returns empty results
**Solution:** Check permissions. You need Billing Account Reader role at the billing account scope.

### Some subscriptions show no billing account
**Solution:** This is normal for trial, sponsored, or incomplete subscriptions. They won't roll up to standard billing constructs.

### CSP detected unexpectedly
**Solution:** You might be in an indirect CSP relationship. Check with procurement—sometimes organizations buy through CSP partners without engineering knowing.

### MACC shows false but Finance says you have one
**Solution:** EA customers may have monetary commitments tracked outside Azure. MACC specifically refers to MCA consumption commitments via the lots API.

## Use Cases

Once you know your billing structure:

1. **Scope Cost Management queries correctly** - Use enrollment accounts for EA, billing profiles for MCA
2. **Build accurate MACC burn-down dashboards** - Only include subscriptions that decrement MACC
3. **Configure RBAC appropriately** - Billing permissions differ between EA and MCA
4. **Set up cost exports** - Export scopes vary by agreement type
5. **Forecast renewals accurately** - Understand commitments and expiration dates

## API Versions

The scripts use the following API versions (current as of January 2025):

- Billing API: `2024-04-01`
- Subscription API: `2020-01-01`
- Consumption API: `2024-08-01`

## Contributing

Found an edge case or improvement? Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with a clear description

## License

MIT License - see LICENSE file for details

## Additional Resources

- [Azure billing and subscription management documentation](https://docs.microsoft.com/azure/cost-management-billing/)
- [Understanding Azure billing accounts](https://docs.microsoft.com/azure/cost-management-billing/manage/view-all-accounts)
- [Microsoft Customer Agreement overview](https://docs.microsoft.com/azure/cost-management-billing/understand/mca-overview)
- [Enterprise Agreement portal guide](https://docs.microsoft.com/azure/cost-management-billing/manage/ea-portal-get-started)

## Author

Originally developed from practical experience working with Azure billing at Microsoft. The scripts have been tested across EA, MCA, and CSP environments.

## Support

For issues or questions:
- Open an issue in this repository
- Check the troubleshooting section above
- Review the blog post (link in repository)
