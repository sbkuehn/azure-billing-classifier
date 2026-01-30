<#
.SYNOPSIS
  Classifies Azure subscriptions by billing structure and detects EA vs MCA, CSP indicators, and MACC.

.DESCRIPTION
  For each accessible subscription:
    - Retrieves subscription billingScopeId
    - Extracts billingAccountId (when present)
    - Gets billing account agreementType (EnterpriseAgreement or MicrosoftCustomerAgreement)
    - Detects CSP indicators by billingScopeId pattern and customer list under billing account
    - Detects MACC by querying Microsoft.Consumption lots under the billing account
  Exports results to CSV and prints a summary table.

.PREREQUISITES
  - Azure CLI installed and logged in (az login)
  - Sufficient permissions to read subscription and billing scopes (Billing Account Reader recommended)

.PARAMETER OutputPath
  Where to write the CSV output.

.PARAMETER ShowDetails
  If true, displays the full results table. If false, shows only summary statistics.

.EXAMPLE
  .\Classify-AzureBilling.ps1 -OutputPath ".\azure-billing-classification.csv"

.EXAMPLE
  .\Classify-AzureBilling.ps1 -OutputPath ".\billing.csv" -ShowDetails $false
#>

param(
    [string]$OutputPath = ".\azure-billing-classification.csv",
    [string]$BillingApiVersion = "2024-04-01",
    [string]$SubApiVersion = "2020-01-01",
    [string]$ConsumptionApiVersion = "2024-08-01",
    [bool]$ShowDetails = $true
)

$ErrorActionPreference = "Stop"

# Helper function to invoke Azure REST API and return JSON
function Invoke-AzRestJson {
    param(
        [Parameter(Mandatory = $true)][string]$Url
    )
    
    try {
        $raw = az rest --method get --url $Url 2>$null
        if (-not $raw) { return $null }
        return $raw | ConvertFrom-Json
    }
    catch {
        Write-Verbose "Failed to query: $Url - $($_.Exception.Message)"
        return $null
    }
}

# Extract billing account ID from a billing scope string
function Get-BillingAccountIdFromScope {
    param(
        [Parameter(Mandatory = $true)][string]$BillingScopeId
    )

    if ([string]::IsNullOrWhiteSpace($BillingScopeId)) { return $null }

    $parts = $BillingScopeId.Trim("/") -split "/"
    $idx = [Array]::IndexOf($parts, "billingAccounts")
    
    if ($idx -ge 0 -and ($idx + 1) -lt $parts.Length) {
        return $parts[$idx + 1]
    }

    return $null
}

# Check if billing scope indicates CSP by looking for /customers/ in the path
function Test-IsCspScope {
    param(
        [Parameter(Mandatory = $true)][string]$BillingScopeId
    )
    
    if ([string]::IsNullOrWhiteSpace($BillingScopeId)) { return $false }
    return $BillingScopeId -match "/customers/"
}

Write-Host "`nAzure Billing Classification Script" -ForegroundColor Cyan
Write-Host "====================================`n" -ForegroundColor Cyan

Write-Host "Listing subscriptions visible to the current identity..." -ForegroundColor Yellow
$subs = az account list -o json | ConvertFrom-Json

if (-not $subs -or $subs.Count -eq 0) {
    throw "No subscriptions returned by 'az account list'. Are you logged in?"
}

Write-Host "Found $($subs.Count) subscription(s)`n" -ForegroundColor Green

# Caches to avoid hammering the API repeatedly for the same billing account
$billingAccountCache = @{}
$lotsCache = @{}
$customersCache = @{}

$results = foreach ($s in $subs) {
    $subId = $s.id
    $subName = $s.name
    
    Write-Verbose "Processing: $subName ($subId)"

    # Get subscription details including billing scope
    $subUrl = "https://management.azure.com/subscriptions/$subId?api-version=$SubApiVersion"
    $subObj = Invoke-AzRestJson -Url $subUrl

    $billingScopeId = $null
    $offerType = $null
    
    if ($subObj -and $subObj.subscriptionPolicies) {
        $billingScopeId = $subObj.subscriptionPolicies.billingScopeId
        $offerType = $subObj.subscriptionPolicies.quotaId
    }

    $billingAccountId = if ($billingScopeId) { 
        Get-BillingAccountIdFromScope -BillingScopeId $billingScopeId 
    } else { 
        $null 
    }

    $agreementType = $null
    $hasMacc = $null
    $isCsp = $false
    $cspEvidence = @()

    # Check for CSP indicator in billing scope
    if ($billingScopeId) {
        $isCsp = Test-IsCspScope -BillingScopeId $billingScopeId
        if ($isCsp) {
            $cspEvidence += "billingScopeId contains /customers/"
        }
    }

    # Get billing account details if we have a billing account ID
    if ($billingAccountId) {
        # Cache billing account info
        if (-not $billingAccountCache.ContainsKey($billingAccountId)) {
            $acctUrl = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId?api-version=$BillingApiVersion"
            $acctObj = Invoke-AzRestJson -Url $acctUrl
            $billingAccountCache[$billingAccountId] = $acctObj
        }

        $acct = $billingAccountCache[$billingAccountId]
        if ($acct -and $acct.properties) {
            $agreementType = $acct.properties.agreementType
        }

        # Check for CSP by querying customers under the billing account
        if (-not $customersCache.ContainsKey($billingAccountId)) {
            $custUrl = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/customers?api-version=$BillingApiVersion"
            $custObj = Invoke-AzRestJson -Url $custUrl
            $customersCache[$billingAccountId] = $custObj
        }

        $cust = $customersCache[$billingAccountId]
        $hasCustomers = $false
        
        if ($cust -and $cust.value -and $cust.value.Count -gt 0) {
            $hasCustomers = $true
        }

        if ($hasCustomers) {
            $isCsp = $true
            $cspEvidence += "billing account has customer entities"
        }

        # MACC detection via consumption lots
        if (-not $lotsCache.ContainsKey($billingAccountId)) {
            $lotsUrl = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/providers/Microsoft.Consumption/lots?api-version=$ConsumptionApiVersion"
            $lotsObj = Invoke-AzRestJson -Url $lotsUrl
            $lotsCache[$billingAccountId] = $lotsObj
        }

        $lots = $lotsCache[$billingAccountId]
        $hasMacc = $false
        
        if ($lots -and $lots.value -and $lots.value.Count -gt 0) {
            $hasMacc = $true
        }
    }

    # Build the evidence string
    $evidenceString = if ($cspEvidence.Count -gt 0) { 
        $cspEvidence -join "; " 
    } else { 
        $null 
    }

    [PSCustomObject]@{
        SubscriptionName = $subName
        SubscriptionId   = $subId
        OfferType        = $offerType
        AgreementType    = $agreementType
        IsCSP            = $isCsp
        CSPEvidence      = $evidenceString
        HasMACC          = $hasMacc
        BillingAccountId = $billingAccountId
        BillingScopeId   = $billingScopeId
    }
}

# Display results
Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "CLASSIFICATION RESULTS" -ForegroundColor Cyan
Write-Host ("=" * 80) + "`n" -ForegroundColor Cyan

# Summary statistics
$eaCount = ($results | Where-Object { $_.AgreementType -eq "EnterpriseAgreement" }).Count
$mcaCount = ($results | Where-Object { $_.AgreementType -eq "MicrosoftCustomerAgreement" }).Count
$cspCount = ($results | Where-Object { $_.IsCSP -eq $true }).Count
$maccCount = ($results | Where-Object { $_.HasMACC -eq $true }).Count
$unknownCount = ($results | Where-Object { [string]::IsNullOrEmpty($_.AgreementType) }).Count

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Total Subscriptions:    $($results.Count)"
Write-Host "  Enterprise Agreement:   $eaCount"
Write-Host "  Microsoft Customer Agr: $mcaCount"
Write-Host "  CSP Detected:           $cspCount"
Write-Host "  Has MACC:               $maccCount"
Write-Host "  Unknown/No Billing:     $unknownCount`n"

if ($ShowDetails) {
    Write-Host "Detailed Results:" -ForegroundColor Yellow
    $results |
        Sort-Object AgreementType, IsCSP, SubscriptionName |
        Select-Object SubscriptionName, AgreementType, IsCSP, HasMACC, OfferType, BillingAccountId |
        Format-Table -AutoSize
}

# Export to CSV
Write-Host "`nExporting results to: $OutputPath" -ForegroundColor Yellow
$results | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Host "Export complete!`n" -ForegroundColor Green

# Display unique billing accounts found
$uniqueBillingAccounts = $results | 
    Where-Object { -not [string]::IsNullOrEmpty($_.BillingAccountId) } |
    Select-Object -ExpandProperty BillingAccountId -Unique

if ($uniqueBillingAccounts) {
    Write-Host "Unique Billing Accounts Found:" -ForegroundColor Yellow
    $uniqueBillingAccounts | ForEach-Object {
        $baId = $_
        $baSubCount = ($results | Where-Object { $_.BillingAccountId -eq $baId }).Count
        $baAgreement = ($results | Where-Object { $_.BillingAccountId -eq $baId } | Select-Object -First 1).AgreementType
        $baHasMACC = ($results | Where-Object { $_.BillingAccountId -eq $baId } | Select-Object -First 1).HasMACC
        
        Write-Host "  $baId" -ForegroundColor Cyan
        Write-Host "    Agreement Type: $baAgreement"
        Write-Host "    Has MACC: $baHasMACC"
        Write-Host "    Subscriptions: $baSubCount`n"
    }
}

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Script complete. Review $OutputPath for full details." -ForegroundColor Green
Write-Host ("=" * 80) -ForegroundColor Cyan
