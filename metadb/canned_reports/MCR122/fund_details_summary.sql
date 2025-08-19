-- MCR122 - rev 8-18-25 
-- fund details summary 
-- This query provides fund details summaries for active funds
-- Query writer: Joanne Leary (jl41)
-- Posted on: 7/25/24
-- 8-15-25: added or subtracted credits in calculations for expenditures, unavailable, cash balance, available balance and perc spent)
-- 8-19-25: added separate column for credits

WITH parameters AS (
    SELECT
        ''::VARCHAR AS fiscal_year_code,
        ''::VARCHAR AS fund_code,
 		''::VARCHAR AS fund_name,
 		''::VARCHAR AS group_name  -- e.g., 'Humanities'
)
SELECT 
	CURRENT_DATE,
	fiscal_year__t.code as fiscal_yr_code, 
	ledger__t.code as ledger_code, 
	ledger__t.name as ledger_name, 
	fund_type__t.name as fund_type_name,
	fund__t.code as fund_code,
	fund__t.name as fund_name, 
	fund__t.description as fund_description,
	groups__t.name as fund_group_name, 
	coalesce (budget__t.initial_allocation,0) as initial_allocation, 
	coalesce (budget__t.allocation_to,0) as increase_in_allocation, 
	coalesce (budget__t.allocation_from,0) as decrease_in_allocation, 
	coalesce (budget__t.initial_allocation,0) 
		+ coalesce (budget__t.allocation_to,0) 
		- coalesce (budget__t.allocation_from,0) as total_allocated, 
	coalesce (budget__t.net_transfers,0) as net_transfers,
	coalesce (budget__t.initial_allocation,0) 
		+ coalesce (budget__t.allocation_to,0) 
		- coalesce (budget__t.allocation_from,0) 
		+ coalesce (budget__t.net_transfers,0) as total_funding, 
	coalesce (budget__t.expenditures,0) - coalesce (budget__t.credits,0) as expenditures, -- subtracted credits
	coalesce (budget__t.credits,0) as credits,
    coalesce (budget__t.encumbered,0) as encumbered, 
	coalesce (budget__t.awaiting_payment,0) as awaiting_payment,
	coalesce (budget__t.encumbered,0) 
		+ coalesce (budget__t.awaiting_payment,0) 
		+ coalesce (budget__t.expenditures,0)
		- coalesce (budget__t.credits,0) as unavailable, -- subtracted credits
	(coalesce (budget__t.initial_allocation,0) 
		+ coalesce (budget__t.allocation_to,0) 
		- coalesce (budget__t.allocation_from,0) 
		+ coalesce (budget__t.net_transfers,0)
		) 
		- coalesce (budget__t.expenditures,0)
		+ coalesce (budget__t.credits,0) as cash_balance, -- added credits
	(coalesce (budget__t.initial_allocation,0) 
		+ coalesce (budget__t.allocation_to,0) 
		- coalesce (budget__t.allocation_from,0) 
		+ coalesce (budget__t.net_transfers,0)
		) 
		- coalesce (budget__t.encumbered,0) 
		- coalesce (budget__t.awaiting_payment,0) 
		- coalesce (budget__t.expenditures,0)
		+ coalesce (budget__t.credits,0) as available_balance, -- added credits
	coalesce (
		(coalesce (budget__t.encumbered,0) 
		+ coalesce (budget__t.awaiting_payment,0) 
		+ coalesce (budget__t.expenditures,0)
		- coalesce (budget__t.credits,0) -- subtracted credits
		) 
		/ 
		nullif (
				(COALESCE (budget__t.initial_allocation,0) 
				+ COALESCE (budget__t.allocation_to,0) 
				- COALESCE (budget__t.allocation_from,0)
				+ COALESCE (budget__t.net_transfers,0)),0
				)			
			*100)::numeric(12,2) AS perc_spent
	
FROM 
	folio_finance.fund__t 
	left join folio_finance.budget__t on fund__t.id = budget__t.fund_id   
    left join folio_finance.fiscal_year__t on budget__t.fiscal_year_id = fiscal_year__t.id 
    left join folio_finance.group_fund_fiscal_year__t on budget__t.id = group_fund_fiscal_year__t.budget_id 
    left join folio_finance.groups__t on groups__t.id = group_fund_fiscal_year__t.group_id 
    left join folio_finance.fund_type__t on fund_type__t.id = fund__t.fund_type_id  
    left join folio_finance.ledger__t on ledger__t.id = fund__t.ledger_id 
WHERE 
	fund__t.fund_status = 'Active' 
	and ((fiscal_year__t.code = (select fiscal_year_code from parameters)) or ((select fiscal_year_code from parameters) = '')) 
	and ((fund__t.code = (select fund_code from parameters)) or ((select fund_code from parameters) = ''))
	and ((fund__t.name = (select fund_name from parameters)) or ((select fund_name from parameters) = ''))
	and ((groups__t.name = (select group_name from parameters)) or ((select group_name from parameters) = ''))
ORDER BY 
	fiscal_yr_code,
	ledger_name,
	fund_type_name,
	fund_code;

