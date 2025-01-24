# MCR134_F: Approved Invoices for FBO

**Last updated:** 10-29-24
**Written by:** Nancy Bolduc
**Revised to Metadb by:** Joanne Leary

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

## History

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

- 
