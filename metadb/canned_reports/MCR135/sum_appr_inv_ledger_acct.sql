--MCR135
--sum_appr_inv_ledger_acct
--last updated: 8-19-25
--This query provides the total of transaction amount by account number along with the finance ledger 
--and finance group within a date range.
--written by Nancy Bolduc, revised for Metadb by Sharon Markus, reviewed and tested by Ann Crowley
--8-19-25: set external_account_no ORDER BY to DESC
--NOTE: To obtain accurate totals for the entire month, enter the first day of the following month as the payment_date_end_date


WITH parameters AS (
    SELECT
        /* Enter invoice payment start date and end date in YYYY-MM-DD format. All 3 date parameters must be entered. */
    	  '2025-07-01' :: DATE AS payment_date_start_date,
        '2025-08-01' :: DATE AS payment_date_end_date, -- Excludes the selected date
        'FY2026'::VARCHAR AS fiscal_year_code -- Ex: FY2023, FY2024 etc.
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
	SUM (CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >.01 
	   THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END) 
	   AS 	transaction_amount -- These 3 lines above transform transaction type 'credits' into a negative amount
FROM
	folio_derived.finance_transaction_invoices AS fti 
	LEFT JOIN folio_invoice.invoices__t AS inv ON fti.invoice_id = inv.id 
	LEFT JOIN folio_finance.fund__t AS ff ON ff.id = fti.effective_fund_id 
	LEFT JOIN folio_finance.ledger__t AS fl ON fl.id = ff.ledger_id 
	LEFT JOIN folio_finance.fiscal_year__t AS ffy ON ffy.id = fti.transaction_fiscal_year_id 
WHERE
	(inv.payment_date::date >= (SELECT payment_date_start_date FROM parameters)) 
	AND (inv.payment_date::date < (SELECT payment_date_end_date FROM parameters))
    AND ((ffy.code::VARCHAR = (SELECT fiscal_year_code FROM parameters)) 
    OR ((SELECT fiscal_year_code FROM parameters) = ''))
	AND inv.status LIKE 'Paid'
GROUP BY 	
	ffy.code,
	ff.external_account_no,
	fl.name
ORDER BY 
	ff.external_account_no DESC;
