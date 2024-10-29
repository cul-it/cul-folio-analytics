-- MCR500
-- Metadb
-- previous_day_appr_vouchers

WITH parameters AS (
  SELECT
        -- current_date - integer '1' AS start_date -- get all orders created XX days from today
        CASE 
            WHEN extract(isodow from current_date) = 1 THEN current_date::date - integer '3'
            WHEN extract(isodow from current_date) IN (2,3,4,5,6) THEN current_date::date - integer '1'
            WHEN extract(isodow from current_date) = 7 THEN current_date::date - integer '2'
        ELSE current_date
        END AS current_date_calc
),
ledger_fund AS (
    SELECT 
        fl.name,
        ff.external_account_no
    FROM 
        folio_finance.ledger__t AS fl  -- Changed from finance_ledgers
        LEFT JOIN folio_finance.fund__t AS ff ON ff.ledger_id = fl.id  -- Changed from finance_funds
    GROUP BY 
        external_account_no,
        fl.name
)
SELECT
    extract(isodow from current_date) AS Week_day_number,
    CURRENT_DATE,
    invv.voucher_date::date AS voucher_date,  -- Explicit voucher_date selection
    lf.name AS ledger_name,
    invvl.external_account_number AS voucher_line_account_number,
    invv.export_to_accounting AS export_to_accounting,
    SUM(invvl.amount) AS total_amt_spent_per_acct_number
FROM
    folio_invoice.vouchers__t AS invv  -- Changed from invoice_vouchers
    LEFT JOIN folio_invoice.voucher_lines__t AS invvl ON invvl.voucher_id = invv.id  -- Changed from INVOICE_VOUCHER_LINES
    LEFT JOIN folio_invoice.invoices__t AS inv ON inv.id = invv.invoice_id  -- Changed from invoice_invoices
    LEFT JOIN ledger_fund AS lf ON lf.external_account_no = invvl.external_account_number
WHERE 
    inv.status LIKE 'Paid'
    AND invv.voucher_date::date >= (SELECT current_date_calc FROM parameters)
GROUP BY 
    voucher_line_account_number,
    lf.name,
    invv.export_to_accounting,
    invv.voucher_date
ORDER BY
    lf.name,
    invvl.external_account_number;
