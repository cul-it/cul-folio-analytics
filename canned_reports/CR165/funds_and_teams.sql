/*NOTE: Choose a fiscal year else the data may not show up correctly*/

WITH parameters AS (
    SELECT
        ''::VARCHAR AS fiscal_year_code, -- Ex: FY2022, FY2023 etc.,
        ''::VARCHAR AS fund_code, -- Ex: 9, 2020,p8660 etc.
 	''::VARCHAR AS fund_name, -- Ex: 521 Approval Plan, 2030 Area Studies etc.,
 	''::VARCHAR AS group_name -- Ex: Central, Sciences, Law etc.
)
SELECT 
	CURRENT_DATE,
	ffy.code AS fiscal_yr_code,
	fft.name AS fund_type_name,
	ff.code AS fund_code,
	ff.name AS fund_name,
	ff.description AS fund_description,
	fg.name AS fund_group_name,
	COALESCE (fb.total_funding,0) AS total_funding,--This amount includes allocations and net transfers
	COALESCE (fb.expenditures,0) AS expenditures,
	COALESCE (fb.encumbered,0) AS encumbered,
	COALESCE (fb.awaiting_payment,0) AS awaiting_payment,
	COALESCE (fb.unavailable,0) AS unavailable,-- This is the total of expenditures, awaiting payments and encumbrances
	COALESCE (fb.cash_balance,0) AS cash_balance, -- This balance excludes encumbrances and awaiting payment
	COALESCE(fb.available,0) AS available_balance,-- This balance includes expenditures, awaiting payments and encumbrances
	COALESCE (unavailable / NULLIF(total_funding,0)*100)::numeric(12,2)  AS perc_spent
FROM 
	finance_funds AS ff
	LEFT JOIN finance_budgets AS fb ON fb.fund_id = ff.id  
   	LEFT JOIN finance_fiscal_years AS ffy ON fb.fiscal_year_id = ffy.id
    	LEFT JOIN finance_group_fund_fiscal_years AS fgffy  ON fgffy.budget_id = fb.id
    	LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id
   	 LEFT JOIN finance_fund_types AS fft ON ff.fund_type_id = fft.id 
    	LEFT JOIN finance_ledgers AS fl ON fl.id = ff.ledger_id
WHERE 
	ff.fund_status LIKE 'Active'
	AND ((ffy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
	AND ((ff.code = (SELECT fund_code FROM parameters)) OR ((SELECT fund_code FROM parameters) = ''))
	AND ((ff.name = (SELECT fund_name FROM parameters)) OR ((SELECT fund_name FROM parameters) = ''))
	AND ((fg.name = (SELECT group_name FROM parameters)) OR ((SELECT group_name FROM parameters) = ''))
ORDER BY 
	fund_group_name,
	fund_code, 
	fund_name;
