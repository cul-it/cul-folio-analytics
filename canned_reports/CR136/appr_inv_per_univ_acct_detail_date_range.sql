--This query provides the list of approved invoices within a date range along with teh external account, vendor name, invoice number, and transaction amount. 

WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'2021-07-01' :: DATE AS payment_date_start_date,
        '2022-06-30' :: DATE AS payment_date_end_date -- Excludes the selected date
),
finance_transaction_invoices_ext AS (
	SELECT 
		fti.invoice_id,
		fti.invoice_line_id,
		fti.po_line_id,
		CASE WHEN fl.name IS NULL THEN fl2.name ELSE fl.name END AS finance_ledger_name,
		fti.invoice_vendor_name,
		fti.transaction_type,
		CASE WHEN ff.code IS NULL THEN ff2.code ELSE ff.code END AS fund_code,
		CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >1 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS transaction_amount,
		CASE WHEN ff.external_account_no IS NULL THEN ff2.external_account_no ELSE ff.external_account_no END AS external_account_no
	FROM
		folio_reporting.finance_transaction_invoices AS fti
		LEFT JOIN finance_funds AS ff ON ff.code = fti.transaction_from_fund_code 
		LEFT JOIN finance_funds AS ff2 ON ff2.code = fti.transaction_to_fund_code
		LEFT JOIN finance_ledgers AS fl ON ff.ledger_id = fl.id
		LEFT JOIN finance_ledgers AS fl2 ON ff2.ledger_id = fl2.id
)
SELECT 
	current_date AS current_date,		
		(SELECT
			payment_date_start_date::varchar
     	FROM
        	parameters) || ' to '::varchar || (
     	SELECT
        	payment_date_end_date::varchar
     	FROM
        	parameters) AS payment_date_range,
    inv.payment_date::date,
    ftie.external_account_no,
    ftie.invoice_vendor_name AS vendor_name,
	inv.vendor_invoice_no AS invoice_no,
	SUM (CASE WHEN ftie.transaction_type = 'Credit' AND ftie.transaction_amount >.01 THEN ftie.transaction_amount *-1 ELSE ftie.transaction_amount END) AS transaction_amount -- This line transfrom transaction type 'credits' into a negatie amount
FROM
	finance_transaction_invoices_ext AS ftie
	LEFT JOIN invoice_invoices AS inv ON ftie.invoice_id = inv.id 
WHERE
	(inv.payment_date::date >= (SELECT payment_date_start_date FROM parameters)) 
	AND (inv.payment_date::date < (SELECT payment_date_end_date FROM parameters))
	AND inv.status LIKE 'Paid'
GROUP BY 
	inv.vendor_invoice_no,
	ftie.external_account_no,
	ftie.invoice_vendor_name,
	inv.payment_date	
ORDER BY 
	ftie.external_account_no,
	inv.payment_date ASC,
	ftie.invoice_vendor_name ASC,
	inv.vendor_invoice_no
	;