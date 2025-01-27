--MCR120Y
--daily_inv_appr_control_yesterday.sql
--last updated: 1-27-25
--written by Nancy Bolduc, revised for metadb by Sharon Markus and Ann Crowley
--This query provides the total amount of voucher_lines per external account number along with the approval dates. 
--It includes manuals and transactions sent to accounting. The invoice status is hardcoded as 'Paid'.
--The date parameter restricts the results to records from the previous day.

/* Change the lines below to filter or leave blank to return all results. Add details in '' for a specific filter.*/

WITH parameters AS (
    SELECT
           current_date - integer '1' AS start_date -- get all orders created XX days from today 
),
ledger_fund AS (
	SELECT 
		fl.name,
		ff.external_account_no
	FROM 
		folio_finance.ledger__t fl 
		LEFT JOIN folio_finance.fund__t AS ff ON ff.ledger_id = fl.id
	GROUP BY 
		external_account_no,
		fl.name
)
SELECT
	current_date - integer '1' AS voucher_date, 	
	lf.name AS ledger_name,
	invvl.external_account_number AS voucher_line_account_number,
	invv.export_to_accounting AS export_to_accounting,
 	SUM(invvl.amount) AS total_amt_spent_oer_acct_number
 	
FROM
    folio_invoice.vouchers__t AS invv
	LEFT JOIN folio_invoice.voucher_lines__t AS invvl ON invvl.voucher_id = invv.id 
	LEFT JOIN folio_invoice.invoices__t AS inv ON inv.id = invv.invoice_id
	LEFT JOIN ledger_fund AS lf ON lf.external_account_no = invvl.external_account_number

WHERE 
	inv.status LIKE 'Paid'
	AND invv.voucher_date::date >= (SELECT start_date FROM parameters)
	
GROUP BY 
	voucher_line_account_number,
	lf.name,
	invv.export_to_accounting
	
 ORDER BY
 	lf.name,
  	invvl.external_account_number
  ;
