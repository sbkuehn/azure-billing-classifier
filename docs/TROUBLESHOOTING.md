# Troubleshooting Guide

Common issues and solutions when using the Azure Billing Classifier.

## Table of Contents
- [Authentication Issues](#authentication-issues)
- [Permission Issues](#permission-issues)
- [Empty or Incomplete Results](#empty-or-incomplete-results)
- [API Errors](#api-errors)
- [Script Execution Issues](#script-execution-issues)
- [Data Quality Issues](#data-quality-issues)

---

## Authentication Issues

### Issue: "Not logged in to Azure CLI"

**Symptoms:**
```
Error: Not logged in to Azure CLI. Run 'az login' first.
```

**Solution:**
```bash
# Interactive login
az login

# If you have multiple tenants, specify one
az login --tenant YOUR-TENANT-ID

# For service principal authentication
az login --service-principal -u APP-ID -p PASSWORD --tenant TENANT-ID

# Verify login
az account show
```

**Additional notes:**
- Use `az login --use-device-code` for environments without browser access
- Service principals need appropriate permissions (see Permission Issues below)

---

### Issue: Token expired during execution

**Symptoms:**
```
ERROR: (AuthenticationFailed) Authentication failed.
```

**Solution:**
```bash
# Refresh your token
az account get-access-token

# If that fails, re-login
az logout
az login
```

**Prevention:**
For long-running scripts, add token refresh logic:

```powershell
# PowerShell - refresh token every 30 minutes
$lastRefresh = Get-Date
if ((Get-Date) - $lastRefresh -gt [TimeSpan]::FromMinutes(30)) {
    az account get-access-token | Out-Null
    $lastRefresh = Get-Date
}
```

---

## Permission Issues

### Issue: Script returns empty billing account information

**Symptoms:**
- Script completes but shows no agreement type
- Billing account ID is blank
- All results show "Unknown/No Billing"

**Solution:**

1. **Check your role assignments:**
```bash
# List your role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv) --all -o table
```

2. **Required permissions:**
   - **Minimum:** Billing Account Reader
   - **Recommended:** Billing Account Reader + Cost Management Reader
   - **Scope:** Must be assigned at billing account level, not just subscription level

3. **Get billing account role:**
```bash
# List billing accounts you have access to
az billing account list -o table

# Check permissions on specific billing account
az role assignment list --scope "/providers/Microsoft.Billing/billingAccounts/YOUR-BILLING-ACCOUNT-ID" -o table
```

4. **Request access:**
   - Contact your billing administrator
   - Request "Billing Account Reader" role
   - Provide your user principal name (UPN)

**Common misconception:**
> "I'm subscription owner, so I have billing access."

Being a subscription owner does NOT grant billing account access. Billing permissions are separate.

---

### Issue: "Forbidden" errors when querying billing APIs

**Symptoms:**
```
(Forbidden) The client does not have permission to perform action
```

**Solution:**

1. **Verify you're using the correct tenant:**
```bash
az account show --query tenantId -o tsv
```

2. **Check if you need to switch tenants:**
```bash
az login --tenant YOUR-CORRECT-TENANT-ID
```

3. **For EA environments:**
   - EA administrators manage billing, not Azure RBAC
   - You may need to be added as an EA admin in the EA portal
   - URL: https://ea.azure.com

4. **For MCA environments:**
   - Check Azure portal → Cost Management + Billing → Access Control
   - Ensure you have appropriate role assignment

---

## Empty or Incomplete Results

### Issue: Some subscriptions show no billing account

**Symptoms:**
- Subscription appears in results
- BillingAccountId is empty
- AgreementType is blank

**Possible causes and solutions:**

1. **Trial or Sponsored Subscriptions**
   - These often don't have standard billing constructs
   - This is expected behavior
   - **Solution:** Filter these out if needed

2. **Disabled Subscriptions**
   - Disabled subs may not return billing info
   - **Check:**
   ```bash
   az account show --subscription SUB-ID --query state -o tsv
   ```

3. **Recently Created Subscriptions**
   - Billing scope may not be fully provisioned yet
   - **Solution:** Wait 15-30 minutes and retry

4. **Orphaned Subscriptions**
   - Rare case where billing relationship is broken
   - **Solution:** Open support ticket with Microsoft

---

### Issue: CSP not detected when you know you're CSP

**Symptoms:**
- IsCSP shows "false"
- You buy Azure through a partner

**Solution:**

1. **Check billing scope manually:**
```bash
az rest --method get \
  --url "https://management.azure.com/subscriptions/YOUR-SUB-ID?api-version=2020-01-01" \
  --query "subscriptionPolicies.billingScopeId"
```

2. **Look for these patterns:**
   - Scope contains `/customers/`
   - Scope contains partner billing account ID

3. **Verify with partner:**
   - Some partners use hybrid models
   - You might have direct Microsoft billing for some subs

4. **Check portal:**
   - Azure portal → Subscriptions → Your subscription
   - Look at "Billing scope" in properties

---

### Issue: MACC shows false but you have a commitment

**Symptoms:**
- HasMACC is false
- Finance team confirms commitment exists

**Possible causes:**

1. **You have EA Monetary Commitment, not MACC**
   - EA uses different tracking mechanism
   - MACC is MCA-specific
   - **Solution:** This is expected for EA environments

2. **Commitment is at partner level (CSP)**
   - Partner may have MACC, but you don't see it
   - **Solution:** Contact your CSP partner for commitment details

3. **Commitment hasn't been loaded yet**
   - New agreements may take time to reflect
   - **Solution:** Wait 24-48 hours after agreement signing

4. **Checking wrong billing account**
   - You might have multiple billing accounts
   - **Solution:** Verify billing account ID with procurement

---

## API Errors

### Issue: Rate limiting errors

**Symptoms:**
```
(TooManyRequests) Rate limit exceeded
```

**Solution:**

1. **The script already uses caching** to minimize API calls

2. **For very large environments (100+ subscriptions):**
```powershell
# Add delays between subscription processing
Start-Sleep -Milliseconds 100
```

3. **Run during off-peak hours:**
   - Azure APIs have higher limits during off-peak times
   - Consider running overnight

---

### Issue: API version errors

**Symptoms:**
```
The api-version '2024-04-01' is invalid
```

**Cause:** API version has been deprecated or updated

**Solution:**

1. **Check current API versions:**
   - Visit: https://docs.microsoft.com/rest/api/billing/

2. **Update script parameters:**
```powershell
.\Classify-AzureBilling.ps1 -BillingApiVersion "2024-08-01"
```

3. **Report issue:**
   - Open GitHub issue with the error
   - Include Azure environment (public, gov, china)

---

## Script Execution Issues

### Issue: PowerShell execution policy prevents script

**Symptoms:**
```
File cannot be loaded because running scripts is disabled
```

**Solution:**

```powershell
# Check current policy
Get-ExecutionPolicy

# Temporarily bypass for this session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Or run with bypass flag
PowerShell -ExecutionPolicy Bypass -File .\Classify-AzureBilling.ps1
```

---

### Issue: Bash script shows "command not found: jq"

**Symptoms:**
```
line 42: jq: command not found
```

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq

# macOS
brew install jq

# Verify installation
jq --version
```

---

### Issue: Script hangs or takes extremely long

**Symptoms:**
- Script runs for 10+ minutes
- No output after initial subscription list

**Possible causes:**

1. **Network issues:**
   - Check internet connectivity
   - Test API access:
   ```bash
   az account list -o table
   ```

2. **Large environment:**
   - 100+ subscriptions is normal to take 5-10 minutes
   - Consider running with `-Verbose` to see progress

3. **Specific subscription causing timeout:**
   - Note which subscription was last processed
   - Manually investigate that subscription:
   ```bash
   az rest --method get --url "https://management.azure.com/subscriptions/PROBLEM-SUB-ID?api-version=2020-01-01"
   ```

---

## Data Quality Issues

### Issue: Results seem inconsistent with portal

**Symptoms:**
- Script shows EA, portal shows MCA
- Discrepancy in subscription counts

**Investigation steps:**

1. **Verify you're looking at same scope:**
   - Portal may default to different tenant/directory
   - Script uses current az context

2. **Check subscription filter:**
   - Portal may filter disabled subscriptions
   - Script includes all subscriptions you can see

3. **Time lag:**
   - Recent changes may not be reflected yet
   - Billing changes can take up to 24 hours

4. **Multiple billing accounts:**
   - Your org may have multiple billing accounts
   - Ensure comparing apples to apples

---

### Issue: CSV file is malformed or won't open in Excel

**Symptoms:**
- Excel shows garbled data
- Commas in wrong places

**Solution:**

1. **Check for special characters in subscription names:**
   - Script should escape these, but verify
   - Look for commas, quotes in subscription names

2. **Open with proper encoding:**
   - CSV is UTF-8 encoded
   - Excel: Import Data → Text to Columns → UTF-8

3. **Use Power BI or Python instead:**
```python
import pandas as pd
df = pd.read_csv('azure-billing-classification.csv')
print(df.head())
```

---

## Getting Additional Help

If you've tried the above solutions and still have issues:

1. **Enable verbose logging:**
```powershell
# PowerShell
.\Classify-AzureBilling.ps1 -Verbose

# Bash
set -x  # Add this line at top of script
```

2. **Collect diagnostic info:**
```bash
# Azure CLI version
az version

# Current context
az account show

# List subscriptions
az account list --query "[].{Name:name, Id:id, State:state}" -o table
```

3. **Open a GitHub issue with:**
   - Error message (redact sensitive info)
   - Azure environment (public/gov/china)
   - Agreement type (if known)
   - Steps to reproduce

4. **Contact Microsoft Support:**
   - For billing-related questions
   - For account access issues
   - URL: https://azure.microsoft.com/support/create-ticket/
