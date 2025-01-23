# MCR113Y

## daily_appr_inv_exported_previous_day.sql

**Written by:** Nancy Bolduc  
**Revised by:** Sharon Markus  
**Reviewed and tested by:** Ann Crowley  
**Last updated:** 1/23/25  

### Description
This query provides the total amount of `voucher_lines` per account number and per approval date for transactions exported to accounting.  

- The invoice status is hardcoded as `'Paid'`.  
- The date parameter restricts the results to records from the previous day.
