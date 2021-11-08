## CR135
# Sum of approved invoices by University ledger and external account number  
<p>
  
## Brief description:
This query provides the total of transaction amount by account number along with the finance ledger. It is used mostly in accounting  for reconciliation.

## Main tables used:
finance_transaction_invoices
  <br>
finance_funds
  <br>
finance_ledgers
  <br>
invoice_invoices
  <br>
invoice_lines	
<p>

## Derived tables used:
folio_reporting.finance_transaction_invoices

## Filters/parameters:
payment_date_start_date
  <br>
payment_date_end_date

