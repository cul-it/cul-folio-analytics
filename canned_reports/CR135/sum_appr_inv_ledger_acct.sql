--last updated: 8/30/23
--This query provides the total of transaction amount by account number along with the finance ledger 
--and finance group within a date range.
--8/30/23: updated by Sharon Beltaine to include fiscal year 
--9/13/23: reviewed and tested by Ann Crowley


WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'' :: DATE AS payment_date_start_date,
        '' :: DATE AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS fiscal_year_code -- Ex: FY2023, FY2024 etc.
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
    	ffy.code AS fiscal_year_code,
    	fl.name AS finance_ledger_name,
    	ff.external_account_no,
	SUM (CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END) AS 	transaction_amount -- This line transfrom transaction type 'credits' into a negatie amount
FROM
	folio_reporting.finance_transaction_invoices AS fti
	LEFT JOIN invoice_invoices AS inv ON fti.invoice_id = inv.id
	LEFT JOIN finance_funds AS ff ON ff.id = fti.effective_fund_id
	LEFT JOIN finance_ledgers AS fl ON fl.id = ff.ledger_id
	LEFT JOIN finance_fiscal_years AS ffy ON ffy.id = fti.transaction_fiscal_year_id
WHERE
	(inv.payment_date::date >= (SELECT payment_date_start_date FROM parameters)) 
	AND (inv.payment_date::date < (SELECT payment_date_end_date FROM parameters))
    AND ((ffy.code::VARCHAR = (SELECT fiscal_year_code FROM parameters)) 
    OR ((SELECT ffy.code::VARCHAR FROM parameters) = ''))
	AND inv.status LIKE 'Paid'
GROUP BY 	
	ffy.code,
	ff.external_account_no,
	fl.name
ORDER BY 
	ff.external_account_no  
	;
	
