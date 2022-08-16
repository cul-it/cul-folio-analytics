--This report provides the year-to-date external account cash balance along with total_expenditures, initial allocation, and net allocation. The fiscal year can be selected in the WHERE clause.
SELECT 
	CURRENT_DATE,
	fl.name AS finance_ledger_name,
	ff.external_account_no,
	SUM(COALESCE (fb.expenditures,0)) AS YTD_expenditures,
	SUM (COALESCE (fb.initial_allocation,0)) AS initial_allocation,
	SUM(COALESCE (fb.allocated,0)) AS total_allocation,
	SUM(COALESCE (fb.cash_balance,0)) AS cash_balance -- This balance excludes encumbrances and awaiting payment
FROM 
	finance_funds AS ff
	LEFT JOIN finance_group_fund_fiscal_years AS fgffy ON fgffy.fund_id = ff.id 
	LEFT JOIN finance_budgets AS fb ON fb.id = fgffy.budget_id
	LEFT JOIN finance_fiscal_years AS ffy ON ffy.id = fgffy.fiscal_year_id
	LEFT JOIN finance_ledgers AS fl ON fl.id = ff.ledger_id 
WHERE 
	ff.fund_status LIKE 'Active'
	AND ffy.code LIKE 'FY2023'
GROUP BY 
	external_account_no,
	fl.name
ORDER BY 
	finance_ledger_name;
