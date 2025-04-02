# MCR116Y

## payables_inv_not_fed_notes_yesterday.sql

This query provides the total amount of voucher lines not sent to accounting (manuals) per account number.

**Authors:**  
- Written by Nancy Boluc  
- Converted to Metadb by Sharon Markus  
- Tested by Ann Crowley  

**Functionality:**  
The date parameter restricts the results to records with a voucher date from the previous day.


**Change Log:**  
3-24-25: updated WHERE clause to restrict results to rows from the previous day only
1-23-25: updated to Metadb format
