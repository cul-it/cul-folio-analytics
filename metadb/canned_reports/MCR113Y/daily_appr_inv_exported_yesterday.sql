-- MCR113Y
-- daily_appr_inv_exported_yesterday.sql
-- written by Nancy Bolduc, revised by Sharon Markus, reviewed and tested by Ann Crowley
-- Last updated: 3-24-25
-- This query provides the total amount of voucher_lines per account number 
-- and per approval date for transactions exported to accounting. 
-- The invoice status is hardcoded as 'Paid'.
-- The date parameter restricts the results to records from the previous day.

WITH parameters AS (
    SELECT current_date - 1 AS start_date
),
ledger_fund AS (
    SELECT 
        fl.name,
        ff.external_account_no
    FROM 
        folio_finance.ledger__t fl 
        LEFT JOIN folio_finance.fund__t ff ON ff.ledger_id = fl.id
    GROUP BY 
        fl.name,
        ff.external_account_no
)
SELECT
    current_date - 1 AS voucher_date,    
    lf.name AS ledger_name,
    invvl.external_account_number AS voucher_line_account_number,
    invv.export_to_accounting,
    SUM(invvl.amount) AS total_amt_spent_per_acct_number
FROM
    folio_invoice.vouchers__t invv
    LEFT JOIN folio_invoice.voucher_lines__t invvl ON invvl.voucher_id = invv.id 
    LEFT JOIN folio_invoice.invoices__t inv ON inv.id = invv.invoice_id
    LEFT JOIN ledger_fund lf ON lf.external_account_no = invvl.external_account_number
WHERE 
    inv.status LIKE 'Paid'
    AND invv.voucher_date::date = (SELECT start_date FROM parameters)
    AND invv.export_to_accounting = TRUE
GROUP BY 
    lf.name,
    invvl.external_account_number,
    invv.export_to_accounting
ORDER BY
    lf.name,
    invvl.external_account_number;

