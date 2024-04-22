--MCR120
--daily_appr_inv_control
--written by Nancy Bolduc, revised for metadb by Sharon Markus and Ann Crowley

/* This query provides the total amount of voucher_lines per external account number along with the approval dates. 
It includes manuals and transactions sent to accounting. The invoice status is hardcoded as 'Paid'.*/

/* Change the lines below to filter or leave blank to return all results. Add details in '' for a specific filter.*/
WITH parameters AS (
	SELECT
        '2021-07-01'::DATE AS voucher_date_start_date, --ex:2000-01-01 
        '2022-06-30'::DATE AS voucher_date_end_date -- ex:2020-06-30 
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
 	SUM(invvl.amount) AS total_amt_spent_oer_acct_number
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
GROUP BY 
	voucher_line_account_number,
	lf.name,
	invv.export_to_accounting
 ORDER BY
 	lf.name,
  	invvl.external_account_number;
    
