--last updated: 11/5/21
--This query provides the total of transaction amount by account number along with the finance ledger and finance group within a date range 

WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'2021-07-01' :: DATE AS payment_date_start_date,
        '2022-06-30' :: DATE AS payment_date_end_date -- Excludes the selected date
)
-- MAIN QUERY
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
    	fl.name AS finance_ledger_name,
    	ff.external_account_no,
	SUM (CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END) AS 	transaction_amount -- This line transfrom transaction type 'credits' into a negatie amount
FROM
	folio_reporting.finance_transaction_invoices AS fti
	LEFT JOIN invoice_invoices AS inv ON fti.invoice_id = inv.id
	LEFT JOIN finance_funds AS ff ON ff.id = fti.effective_fund_id
	LEFT JOIN finance_ledgers AS fl ON fl.id = ff.ledger_id
WHERE
	(inv.payment_date::date >= (SELECT payment_date_start_date FROM parameters)) 
	AND (inv.payment_date::date < (SELECT payment_date_end_date FROM parameters))
	AND inv.status LIKE 'Paid'
GROUP BY 	
	ff.external_account_no,
	fl.name
ORDER BY 
	ff.external_account_no  
	;
	
