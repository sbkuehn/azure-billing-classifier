# Examples

This directory contains example outputs and usage scenarios for the Azure Billing Classifier.

## Basic Usage

### PowerShell Example

```powershell
# Basic usage - outputs to current directory
.\Classify-AzureBilling.ps1

# Custom output location
.\Classify-AzureBilling.ps1 -OutputPath "C:\Reports\billing-$(Get-Date -Format 'yyyy-MM-dd').csv"

# Summary only (no detailed table)
.\Classify-AzureBilling.ps1 -ShowDetails $false

# With verbose logging
.\Classify-AzureBilling.ps1 -Verbose
```

### Bash Example

```bash
# Basic usage
./classify-azure-billing.sh

# Custom output location
./classify-azure-billing.sh ./reports/billing-$(date +%Y-%m-%d).csv

# Run and immediately view results
./classify-azure-billing.sh && cat azure-billing-classification.csv | column -t -s,
```

## Sample Output

### Console Output

```
Azure Billing Classification Script
====================================

Listing subscriptions visible to the current identity...
Found 12 subscription(s)

================================================================================
CLASSIFICATION RESULTS
================================================================================

Summary:
  Total Subscriptions:    12
  Enterprise Agreement:   5
  Microsoft Customer Agr: 7
  CSP Detected:           2
  Has MACC:               1
  Unknown/No Billing:     0

Detailed Results:

SubscriptionName         AgreementType              IsCSP HasMACC OfferType
----------------         -------------              ----- ------- ---------
Production-EA            EnterpriseAgreement        False False   MS-AZR-0017P
DevTest-EA               EnterpriseAgreement        False False   MS-AZR-0148P
Production-MCA           MicrosoftCustomerAgreement False True    MS-AZR-0017P
Customer-A               MicrosoftCustomerAgreement True  False   MS-AZR-0145P
Visual-Studio-Sub        MicrosoftCustomerAgreement False False   MS-AZR-0063P
```

### CSV Output Structure

```csv
SubscriptionName,SubscriptionId,OfferType,AgreementType,IsCSP,CSPEvidence,HasMACC,BillingAccountId,BillingScopeId
Production-EA,12345678-1234-1234-1234-123456789012,MS-AZR-0017P,EnterpriseAgreement,False,,False,1234567,/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/123456
Production-MCA,87654321-4321-4321-4321-210987654321,MS-AZR-0017P,MicrosoftCustomerAgreement,False,,True,abc123:def456,/providers/Microsoft.Billing/billingAccounts/abc123:def456/billingProfiles/xyz789/invoiceSections/section1
Customer-A,11111111-2222-3333-4444-555555555555,MS-AZR-0145P,MicrosoftCustomerAgreement,True,billingScopeId contains /customers/; billing account has customers,False,partner123,/providers/Microsoft.Billing/billingAccounts/partner123/customers/customer1
```

## Integration with Power BI

### Load CSV into Power BI

```powerquery
let
    Source = Csv.Document(File.Contents("C:\path\to\azure-billing-classification.csv"),[Delimiter=",", Columns=9, Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    ChangedType = Table.TransformColumnTypes(PromotedHeaders,{
        {"SubscriptionName", type text},
        {"SubscriptionId", type text},
        {"OfferType", type text},
        {"AgreementType", type text},
        {"IsCSP", type logical},
        {"CSPEvidence", type text},
        {"HasMACC", type logical},
        {"BillingAccountId", type text},
        {"BillingScopeId", type text}
    })
in
    ChangedType
```

### Sample DAX Measures

```dax
// Count of EA Subscriptions
EA Subscriptions = 
CALCULATE(
    COUNTROWS('BillingClassification'),
    'BillingClassification'[AgreementType] = "EnterpriseAgreement"
)

// Count of MCA Subscriptions
MCA Subscriptions = 
CALCULATE(
    COUNTROWS('BillingClassification'),
    'BillingClassification'[AgreementType] = "MicrosoftCustomerAgreement"
)

// Percentage with MACC
MACC Percentage = 
DIVIDE(
    CALCULATE(COUNTROWS('BillingClassification'), 'BillingClassification'[HasMACC] = TRUE()),
    COUNTROWS('BillingClassification'),
    0
) * 100
```

## Combining with Cost Data

### PowerShell: Merge with Cost Exports

```powershell
# Load classification
$classification = Import-Csv ".\azure-billing-classification.csv"

# Load cost data (example from Cost Management export)
$costs = Import-Csv ".\azure-costs-export.csv"

# Merge on SubscriptionId
$merged = $costs | ForEach-Object {
    $cost = $_
    $class = $classification | Where-Object { $_.SubscriptionId -eq $cost.SubscriptionId } | Select-Object -First 1
    
    [PSCustomObject]@{
        SubscriptionName = $class.SubscriptionName
        SubscriptionId = $cost.SubscriptionId
        AgreementType = $class.AgreementType
        IsCSP = $class.IsCSP
        HasMACC = $class.HasMACC
        Cost = $cost.Cost
        Date = $cost.Date
        ResourceGroup = $cost.ResourceGroup
    }
}

$merged | Export-Csv ".\azure-costs-classified.csv" -NoTypeInformation
```

### Bash: Filter by Agreement Type

```bash
# Extract only MCA subscriptions
awk -F',' '$4=="MicrosoftCustomerAgreement" {print $1,$2}' azure-billing-classification.csv

# Extract subscriptions with MACC
awk -F',' '$7=="true" {print $1,$2,$8}' azure-billing-classification.csv

# Count by agreement type
awk -F',' 'NR>1 {agreements[$4]++} END {for (a in agreements) print a, agreements[a]}' azure-billing-classification.csv
```

## Scheduled Execution

### Windows Task Scheduler (PowerShell)

Create a scheduled task to run weekly:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Classify-AzureBilling.ps1 -OutputPath C:\Reports\billing-$(Get-Date -Format 'yyyy-MM-dd').csv"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6am

Register-ScheduledTask -TaskName "Azure Billing Classification" `
    -Action $action -Trigger $trigger `
    -Description "Weekly Azure billing structure classification"
```

### Linux Cron Job (Bash)

Add to crontab (`crontab -e`):

```bash
# Run every Monday at 6am
0 6 * * 1 /home/user/scripts/classify-azure-billing.sh /home/user/reports/billing-$(date +\%Y-\%m-\%d).csv
```

## Advanced Scenarios

### Filter to Specific Subscriptions

```powershell
# Only classify production subscriptions
$allSubs = az account list -o json | ConvertFrom-Json
$prodSubs = $allSubs | Where-Object { $_.name -like "*prod*" }

# Temporarily set subscription list
$env:AZ_SUBSCRIPTIONS = ($prodSubs | ConvertTo-Json -Compress)
.\Classify-AzureBilling.ps1
```

### Multi-Tenant Classification

```bash
#!/bin/bash
# Classify across multiple tenants

TENANTS=("tenant1-id" "tenant2-id" "tenant3-id")

for tenant in "${TENANTS[@]}"; do
    echo "Processing tenant: $tenant"
    az login --tenant "$tenant"
    ./classify-azure-billing.sh "billing-${tenant}.csv"
    az logout
done

# Merge all results
cat billing-*.csv | awk 'NR==1 || !/^SubscriptionName/' > billing-all-tenants.csv
```
