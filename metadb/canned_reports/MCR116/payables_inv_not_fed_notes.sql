--MCR116
--payables_inv_not_fed_notes
--This query was written by Nancy Bolduc and revised for metadb by Sharon Markus and Ann Crowley
--last updated 1/21/25
--The date range for this query is currently set to show data for FY2025.

/* This query provides the total amount of voucher lines not sent to accounting (manuals) 
per account number with notes*/

/* Change the lines below to filter or leave blank to return all results. 
Add details in '' for a specific filter.*/

WITH parameters AS (
	SELECT
        '2021-07-01'::DATE AS voucher_date_start_date, --ex:2000-01-01 
        '2022-06-30'::DATE AS voucher_date_end_date -- ex:2020-06-30 
),
ledger_fund AS (
	SELECT 
		fl.name,
		ff.external_account_no
	FROM folio_finance.ledger__t fl 
	LEFT JOIN 
		folio_finance.fund__t AS ff ON FF.ledger_id = fl.id
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
     FROM parameters) AS date_range,	
	lf.name AS ledger_name,
	invvl.external_account_number AS voucher_line_account_number,
	inv.vendor_invoice_no,
	org.erp_code AS vendor_erp_code,
	org.name AS vendor_name,
 	invvl.amount AS total_amt_spent_per_voucher_line,
 	inv.note AS invoice_note
FROM
    folio_invoice.vouchers__t AS invv
	LEFT JOIN folio_invoice.voucher_lines__t AS invvl ON invvl.voucher_id = invv.id 
	LEFT JOIN folio_invoice.invoices__t AS inv ON inv.id = invv.invoice_id
	LEFT JOIN ledger_fund AS lf ON lf.external_account_no = invvl.external_account_number
	LEFT JOIN folio_organizations.organizations__t AS org ON org.id = invv.vendor_id

WHERE 
	(invv.voucher_date >= (SELECT voucher_date_start_date FROM parameters)) 
	AND (invv.voucher_date < (SELECT voucher_date_end_date FROM parameters))
	AND inv.status LIKE 'Paid'
	AND invv.export_to_accounting = FALSE

GROUP BY 
	vendor_invoice_no,
	lf.name,
	org.erp_code,
	org.name,
	invvl.external_account_number,
	inv.note,
	invvl.amount
	
 ORDER BY
 	lf.name;
 	
