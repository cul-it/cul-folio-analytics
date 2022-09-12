--This query provide fund details summary for active funds

WITH parameters AS (
    SELECT
        'FY2023'::VARCHAR AS fiscal_year_code,
        ''::VARCHAR AS fund_code,
 		''::VARCHAR AS fund_name,
 		''::VARCHAR AS group_name
)
SELECT 
	CURRENT_DATE,
	ffy.code AS fiscal_yr_code,
	fl.code AS ledger_code,
	fl.name AS ledger_name,
	fft.name AS fund_type_name,
	ff.code AS fund_code,
	ff.name AS fund_name,
	ff.description AS fund_description,
	fg.name AS fund_group_name,
	COALESCE (fb.initial_allocation,0) AS initial_allocation,
	COALESCE (fb.allocation_to,0) AS increase_in_allocation,
	COALESCE (fb.allocation_from,0) AS decrease_in_allocation,
	COALESCE (fb.initial_allocation,0) + COALESCE (fb.allocation_to,0)- COALESCE (fb.allocation_from,0) AS Total_allocated,
	COALESCE (fb.net_transfers,0) AS net_transfers,
	COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0) AS total_funding,
	COALESCE (fb.expenditures,0) AS expenditures,
	COALESCE (fb.encumbered,0) AS encumbered,
	COALESCE (fb.awaiting_payment,0) AS awaiting_payment,
	COALESCE (fb.encumbered,0)+COALESCE (fb.awaiting_payment,0)+COALESCE (fb.expenditures,0) AS unavailable,
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.expenditures,0) AS cash_balance,
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.encumbered,0) - COALESCE (fb.awaiting_payment,0) - COALESCE (fb.expenditures,0) AS available_balance,
	COALESCE ((COALESCE (fb.encumbered,0)+COALESCE (fb.awaiting_payment,0)+COALESCE (fb.expenditures,0)) / NULLIF((COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)),0)*100)::numeric(12,2)  AS perc_spent
	
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
	ledger_name,
	fund_type_name;
