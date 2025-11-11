# MCR132Y

- **Report Name:** ytd_acct_bal_by_ledger_univ_acct_yesterday  
- **Last Updated:** 11-11-26  
- **Authors:** Written by Sharon Markus, reviewed by Ann Crowley  

## Overview
This report uses historical tables to provide yesterday's:
- **Year-to-date external account cash balance**
- **Total expenditures**
- **Initial allocation**
- **Net allocation**

Historical snapshots are created for:
- **Budget amounts**
- **Fund amounts**
- **Ledger amounts**

## Fiscal Year
- Currently set to **FY2026**  
- Can be changed in the **WHERE clause**

## Change Log
- **8-15-25:** Added or subtracted credits into the `YTD_expenditures` and `cash_balance` calculations  

## Example
- Captures snapshots for **yesterday at 6:00 PM ET**  
- Change the **TIME value** to adjust when snapshots are taken

# Snapshot Summary: MCR132Y

| Field                | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| **Cash Balance**      | Yesterday’s year-to-date external account cash balance                     |
| **Total Expenditures**| Year-to-date expenditures, including credits added/subtracted (as of 8-15-25)|
| **Initial Allocation**| Original allocation amount recorded in historical tables                   |
| **Net Allocation**    | Allocation after adjustments and credits                                   |
| **Budget Amounts**    | Historical snapshots of budget balances                                    |
| **Fund Amounts**      | Historical snapshots of fund balances                                      |
| **Ledger Amounts**    | Historical snapshots of ledger balances                                    |
| **Fiscal Year**       | Currently set to FY2026 (modifiable in WHERE clause)                       |
| **Snapshot Time**     | Default: yesterday at 6:00 PM ET (modifiable via TIME value)               |



