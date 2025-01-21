-- MCR113
-- daily_appr_inv_exported.sql
-- last updated: 1/21/25
-- written by Nancy Bolduc, revised for Metadb by Sharon Markus, reviewed and tested by Ann Crowley
-- This query provides the total amount of voucher_lines per account number 
-- and per approval date for transactions exported to accounting. 
-- The invoice status is hardcoed as 'Paid'
-- The date range for records in results is set for FY2025.

/* Change the lines below to filter or leave blank to return all results. Add details in '' for a specific filter.*/

WITH parameters AS (
	SELECT
        '2024-07-01'::DATE AS voucher_date_start_date, --ex:2000-01-01 
        '2025-06-30'::DATE AS voucher_date_end_date -- ex:2020-06-30 
),
ledger_fund AS (
	SELECT 
		fl.name,
		ff.external_account_no
	FROM 
		folio_finance.ledger__t fl 
		LEFT JOIN folio_finance.fund__t AS ff ON FF.ledger_id = fl.id
	GROUP BY 
		external_account_no,
		fl.name
)
SELECT
	(SELECT
			voucher_date_start_date::varchar
     FROM
        	parameters) || ' to '::varchar || (
     SELECT
        	voucher_date_end_date::varchar
     FROM
        	parameters) AS date_range,	
	lf.name AS ledger_name,
    invvl.external_account_number AS voucher_line_account_number,
    invv.export_to_accounting AS export_to_accounting,
 	SUM(invvl.amount) AS total_amt_spent_per_acct_number
FROM
    folio_invoice.vouchers__t AS invv
	LEFT JOIN folio_invoice.voucher_lines__t AS invvl ON invvl.voucher_id = invv.id 
	LEFT JOIN folio_invoice.invoices__t AS inv ON inv.id = invv.invoice_id
	LEFT JOIN ledger_fund AS lf ON lf.external_account_no = invvl.external_account_number
WHERE 
	(invv.voucher_date >= (SELECT voucher_date_start_date FROM parameters)) 
	AND
	(invv.voucher_date < (SELECT voucher_date_end_date FROM parameters))
	AND inv.status LIKE 'Paid'
	AND invv.export_to_accounting = TRUE
GROUP BY 
	voucher_line_account_number,
	lf.name,
	invv.export_to_accounting
 ORDER BY
 	lf.name,
  	invvl.external_account_number
;



  
  
