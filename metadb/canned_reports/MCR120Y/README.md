# MCR120Y
## daily_inv_appr_control_yesterday.sql
**Last updated:** 1-27-25  

### Authors:
- Written by Nancy Bolduc  
- Revised for metadb by Sharon Markus and Ann Crowley  

### Description:
This query provides the total amount of `voucher_lines` per external account number along with the approval dates.  
It includes manuals and transactions sent to accounting. The invoice status is hardcoded as `'Paid'`.  

The date parameter restricts the results to records from the previous day.
