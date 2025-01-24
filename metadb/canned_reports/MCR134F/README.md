# MCR134F
# approved_invoices_for_fbo.sql

****

This is a version of the MCR134 approved invoices query using by accounting that has been modified to exclude the bibliographic data. Accounting approves invoices Mondays through Fridays, so it is best to run this query on Fridays if you want it to match the data in the FOLIO financial applications. This query does not use derived tables.

**Last updated:** 1-24-25  
**Written by:** Joanne Leary

This query provides the list of approved invoices within a date range along with:
- Ledger name
- External account number
- Vendor name
- Vendor invoice number
- Invoice line number
- Invoice line description
- Invoice date
- Invoice payment date
- Order format
- Format name
- Purchase order line number
- Fund code
- Transaction type
- Transaction amount

In cases where the quantity was incorrectly entered as zero, this query replaces zero with 1.

## Change Log

### Converted to MetaDB (8-29-24)
- Added invoice line number and invoice status to Select fields.
- Changed Where condition to `inv.status in ('Paid','Approved')`.
- Added the invoice approval date as part of the where condition, using the start and end date as parameters.

### 9-5-24
- Removed `distinct` from the main query.
- Removed `new quantity` subquery (not needed, because all entries in the `invoice_lines__t` table have non-zero and non-null values).
- Replaced `new quantity` with `invl.quantity`.
- Changed the `payment_end_date` Where statement to be "less than," not "less than or equal to".
- Changed invoice status condition to "Paid" or "Approved" and applied the payment date parameter values to both "Paid date" or "Approval date".

### 10-29-24
- Discovered that `invoice_line__t.quantity` does in fact have some entries = '0', but because this query does not include the `transaction_amount_per_qty` field, there is no need to have the New Quantity subquery.

### 1-24-25
- Replaced the `finance_transaction_invoices` derived table with the derivation code, in order to make the query pull current data.
- Replaced `instance_ext` with `instance__t` table.

- 
