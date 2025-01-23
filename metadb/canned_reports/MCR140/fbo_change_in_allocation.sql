--MCR140
--last updated: 1/21/25
--fbo_change_in_allocation.sql
--written by Nancy Bolduc, revised to Metadb by Sharon Markus and Ann Crowley
--This report provides a list of change in allocation per date range. A negative transaction amount 
--is for an increase in allocation and a positive amount is for a decrease in allocation.
--1/21/25: added fiscal_year_id
--This query's date parameters are currently set to return records for FY2025.

WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'2024-07-01' :: DATE AS allocation_created_date_start_date,
    	'2025-06-30' :: DATE AS allocation_created_date_end_date,
    	'':: VARCHAR AS finance_fund_name
),
finance_transactions_ext AS (
	SELECT 
		jsonb_extract_path_text (ft2.jsonb, 'metadata', 'createdDate')::DATE AS transaction_created_date,
	    amount,
        currency,
		description,
		from_fund_id,
		fiscal_year_id,
		to_fund_id,
		transaction_type     
	FROM 
	    folio_finance.transaction__t AS ft	
	    LEFT JOIN folio_finance.transaction AS ft2 ON ft2.id::UUID = ft.id::UUID
)
SELECT 
	CURRENT_DATE,
	(SELECT
		allocation_created_date_start_date::varchar
     FROM
        parameters) || ' to '::varchar || (
    SELECT
       allocation_created_date_end_date::varchar
    FROM parameters) AS allocation_created_date_range,
    ffy.code AS fiscal_year,
    CASE WHEN ff.external_account_no IS NULL THEN ff2.external_account_no ELSE ff.external_account_no END AS external_account_no,
	CASE WHEN ff.name IS NULL THEN ff2.name ELSE ff.name END AS finance_fund_name,
	ftext.transaction_created_date  AS transaction_created_date,
	CASE WHEN ff.name IS NULL THEN ftext.amount::decimal *-1 ELSE ftext.amount END AS allocation_amount,
	ftext.currency,
	ftext.description
FROM finance_transactions_ext AS ftext
	LEFT JOIN folio_finance.fund__t AS ff ON ff.id::UUID = ftext.from_fund_id::UUID
	LEFT JOIN folio_finance.fund__t AS ff2 ON ff2.id::UUID = ftext.to_fund_id::UUID
	LEFT JOIN folio_finance.fiscal_year__t AS ffy ON ffy.id::UUID = ftext.fiscal_year_id::UUID
WHERE transaction_type = 'Allocation'
	AND (ftext.transaction_created_date >= (SELECT allocation_created_date_start_date FROM parameters)) 
	AND (ftext.transaction_created_date < (SELECT allocation_created_date_end_date FROM parameters))
	AND ((CASE WHEN ff.name IS NULL THEN ff2.name ELSE ff.name END = (SELECT finance_fund_name FROM parameters)) OR ((SELECT finance_fund_name FROM parameters) = ''))
ORDER BY 
	external_account_no,
	transaction_created_date ASC;
  
