--MCR116Y
--payables_inv_not_fed_notes_yesterday.sql
--last updated: 3-24-25
--This query provides the total amount of voucher lines not sent to accounting (manuals) per account number.
--written by Nancy Boluc, converted to Metadb by Sharon Markus, tested by Ann Crowley
--The date parameter restricts the results to records with a voucher date from the previous day.


WITH ledger_fund AS (
    SELECT DISTINCT ON (ff.external_account_no) 
        fl.name, 
        ff.external_account_no
    FROM folio_finance.ledger__t fl 
    LEFT JOIN folio_finance.fund__t ff ON ff.ledger_id = fl.id
    ORDER BY ff.external_account_no, fl.name
)
SELECT DISTINCT
    current_date - 1 AS voucher_date,       
    lf.name AS ledger_name,
    invvl.external_account_number AS voucher_line_account_number,
    inv.vendor_invoice_no,
    org.erp_code AS vendor_erp_code,
    org.name AS vendor_name,
    invvl.amount AS total_amt_spent_per_voucher_line,
    inv.note AS invoice_note
FROM folio_invoice.vouchers__t invv
LEFT JOIN folio_invoice.voucher_lines__t invvl ON invvl.voucher_id = invv.id 
LEFT JOIN folio_invoice.invoices__t inv ON inv.id = invv.invoice_id
LEFT JOIN ledger_fund lf ON lf.external_account_no = invvl.external_account_number
LEFT JOIN folio_organizations.organizations__t org ON org.id = invv.vendor_id
WHERE 
    inv.status = 'Paid'
    AND invv.voucher_date::date = current_date - 1
    AND invv.export_to_accounting = FALSE
ORDER BY
    lf.name;
