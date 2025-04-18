# MCR139Y
## inv_appr_paid_diff_date_yesterday.sql
**Last updated:** 4/17/25  

### Authors:
- Written by Nancy Bolduc  
- Revised to Metadb by Ann Crowley and Sharon Markus  

### Description:
This query provides a list of approved invoices that have been paid on a different date.  
Sometimes Folio won't allow an invoice to be paid immediately, and it will only be processed at a later date after changes have been made.  
The date range for this query is currently set to show data for **FY2025**.

### Change Log:
--4-10-25: Added WHERE clause filter to restrict results to records year-to-date through yesterday using the invoice approval date.
--4-17-25: Added WHERE clause filter to restrict results to FY2025

