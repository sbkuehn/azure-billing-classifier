# Azure Billing Concepts

This document provides detailed explanations of Azure billing terminology and concepts detected by the classifier.

## Table of Contents
- [Billing Layers](#billing-layers)
- [Agreement Types](#agreement-types)
- [Commitments](#commitments)
- [Subscription Offers](#subscription-offers)
- [CSP Relationships](#csp-relationships)
- [Billing Scopes](#billing-scopes)

---

## Billing Layers

Azure billing operates in three distinct layers that are often confused:

### 1. Agreement Layer
The legal and commercial contract between your organization and Microsoft.

**Types:**
- Enterprise Agreement (EA)
- Microsoft Customer Agreement (MCA)
- Microsoft Online Subscription Agreement (MOSA) - legacy

### 2. Commitment Layer
Optional promises to spend certain amounts over time.

**Types:**
- Microsoft Azure Consumption Commitment (MACC)
- Monetary Commitment (EA-specific)
- Azure Prepayment (formerly Azure Credit)

### 3. Subscription Offer Layer
How individual subscriptions are created, priced, and credited.

**Types:**
- Pay-As-You-Go (PAYG)
- Visual Studio Enterprise
- DevTest
- Sponsorship
- Free Trial
- CSP subscriptions

---

## Agreement Types

### Enterprise Agreement (EA)

**What it is:** Traditional enterprise licensing model, typically 3-year terms.

**Key characteristics:**
- Enrollments and enrollment accounts
- Monetary commitment tracked at enrollment level
- Department and account organizational structure
- EA portal for management
- Pre-negotiated pricing discounts

**Billing hierarchy:**
```
Enrollment
└── Department (optional)
    └── Enrollment Account
        └── Subscription
```

**Billing scope format:**
```
/providers/Microsoft.Billing/billingAccounts/{enrollmentId}/enrollmentAccounts/{accountId}
```

**When to use EA:**
- Large enterprise deployments
- Organizations with existing Microsoft EA
- Need for departments and cost centers
- Multi-year predictable budgets

---

### Microsoft Customer Agreement (MCA)

**What it is:** Modern contract model for most new Azure customers.

**Key characteristics:**
- Billing profiles for invoice management
- Invoice sections for internal organization
- Support for MACC commitments
- Azure portal-based management
- More flexible than EA

**Billing hierarchy:**
```
Billing Account
└── Billing Profile
    └── Invoice Section
        └── Subscription
```

**Billing scope format:**
```
/providers/Microsoft.Billing/billingAccounts/{accountId}/billingProfiles/{profileId}/invoiceSections/{sectionId}
```

**When to use MCA:**
- New Azure customers
- Organizations modernizing from EA
- Need for flexible billing profiles
- Want MACC commitments

---

## Commitments

### Microsoft Azure Consumption Commitment (MACC)

**What it is:** A promise to consume a specific dollar amount of Azure services over a defined period (typically 1-3 years).

**Key characteristics:**
- Only available with MCA
- Tracked via "lots" in the Consumption API
- Decremented by eligible Azure consumption
- Does NOT provide upfront discounts (discounts come from other sources)
- Can have multiple lots with different expiration dates

**What decrements MACC:**
- Azure services consumption
- Azure Marketplace purchases (some)
- Reserved Instances (when purchased)

**What does NOT decrement MACC:**
- Third-party Marketplace purchases (most)
- Support charges
- Azure credits from other sources (e.g., Visual Studio credits)

**Detection method:**
```bash
# Query consumption lots
az rest --method get \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/{id}/providers/Microsoft.Consumption/lots?api-version=2024-08-01"
```

**Common confusion:**
> "I have PAYG subscriptions, so I don't have a commitment."

This is wrong. PAYG describes the subscription offer type. MACC exists at the billing account level and can include PAYG subscriptions.

---

### EA Monetary Commitment

**What it is:** Upfront commitment tracked at the enrollment level in EA agreements.

**Key characteristics:**
- Specific to Enterprise Agreements
- Pre-paid amount (Azure Prepayment)
- Different from MACC (not tracked via lots API)
- Legacy model being replaced by MCA + MACC

---

## Subscription Offers

### Pay-As-You-Go (PAYG)
- **Offer ID:** MS-AZR-0017P
- **Description:** Standard monthly billing based on usage
- **Agreement:** Can be under EA or MCA
- **Credits:** None

### Visual Studio Enterprise
- **Offer ID:** MS-AZR-0063P
- **Description:** Included Azure credits for Visual Studio subscribers
- **Agreement:** Typically MCA
- **Credits:** $150/month (amount varies by subscription type)
- **MACC impact:** Credits do NOT decrement MACC

### DevTest
- **Offer ID:** MS-AZR-0148P
- **Description:** Discounted pricing for dev/test workloads
- **Agreement:** Typically EA
- **Credits:** None, but discounted rates

### CSP (Cloud Solution Provider)
- **Offer ID:** MS-AZR-0145P
- **Description:** Purchased through a Microsoft partner
- **Agreement:** MCA (at partner level)
- **Credits:** Varies by partner

---

## CSP Relationships

### What is CSP?

Cloud Solution Provider is a **channel**, not an agreement type. CSP subscriptions are ultimately under MCA agreements, but with the partner as an intermediary.

### CSP Detection Indicators

1. **Billing scope contains `/customers/`**
   ```
   /providers/Microsoft.Billing/billingAccounts/{partnerId}/customers/{customerId}
   ```

2. **Billing account has customer entities**
   ```bash
   az rest --method get \
     --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/{id}/customers"
   ```

### CSP Tiers

- **Tier 1 (Direct CSP):** Partner bills customer directly
- **Tier 2 (Indirect CSP):** Distributor → Reseller → Customer

### CSP Implications

- Different portal experience
- Marketplace eligibility varies
- Support handled by partner
- Billing managed by partner
- Cost Management access can be restricted

---

## Billing Scopes

### Scope Hierarchy

```
Agreement Type
├── Billing Account
    ├── Billing Profile (MCA only)
    │   └── Invoice Section (MCA only)
    │       └── Subscription
    └── Enrollment Account (EA only)
        └── Subscription
```

### Scope Formats

**EA Subscription:**
```
/providers/Microsoft.Billing/billingAccounts/123456/enrollmentAccounts/654321
```

**MCA Subscription:**
```
/providers/Microsoft.Billing/billingAccounts/abc123:def456/billingProfiles/xyz789/invoiceSections/section1
```

**CSP Subscription:**
```
/providers/Microsoft.Billing/billingAccounts/partner123/customers/customer456/billingSubscriptions/sub789
```

### Scope Usage

Billing scopes are critical for:

1. **Cost Management queries**
   - Scope export to the right level
   - Filter data correctly

2. **Role assignments**
   - Billing Reader at billing account level
   - Cost Manager at subscription level

3. **API calls**
   - Must use correct scope format
   - Different APIs for EA vs MCA

---

## Common Confusion Points

### "We're PAYG so we don't have an agreement"
**Wrong.** PAYG is a subscription offer type. You still have an agreement (likely MCA) at the billing account level.

### "We're CSP so we're not under MCA"
**Wrong.** CSP is a channel. The underlying agreement is still MCA, just with a partner intermediary.

### "We have EA so we can't have MACC"
**Partially true.** EA uses monetary commitments, not MACC. However, you could have hybrid environments with some subs under EA and others under MCA with MACC.

### "MACC gives us discounts"
**Wrong.** MACC is a commitment to spend. Discounts come from Reserved Instances, Savings Plans, and negotiated rates.

### "All our subscriptions show the same agreement type"
**Often wrong.** Many orgs have hybrid environments with subs under different agreements, especially during EA-to-MCA transitions.

---

## Further Reading

- [Microsoft Customer Agreement documentation](https://docs.microsoft.com/azure/cost-management-billing/understand/mca-overview)
- [Enterprise Agreement documentation](https://docs.microsoft.com/azure/cost-management-billing/manage/ea-portal-get-started)
- [Azure offer types](https://azure.microsoft.com/support/legal/offer-details/)
- [CSP program overview](https://partner.microsoft.com/cloud-solution-provider)
