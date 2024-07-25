-- MCR122 
-- fund details summary 
-- This query provides fund details summaries for active funds
--Query writer: Joanne Leary (jl41)
--Posted on: 7/25/24




WITH parameters AS (
    SELECT
        ''::VARCHAR AS fiscal_year_code,
        ''::VARCHAR AS fund_code,
 		''::VARCHAR AS fund_name,
 		'Humanities'::VARCHAR AS group_name
)
SELECT 
	CURRENT_DATE,
	fiscal_year__t.code as fiscal_yr_code, --ffy.code AS fiscal_yr_code,
	ledger__t.code as ledger_code, --fl.code AS ledger_code,
	ledger__t.name as ledger_name, --fl.name AS ledger_name,
	fund_type__t.name as fund_type_name, --fft.name AS fund_type_name,
	fund__t.code as fund_code,--ff.code AS fund_code,
	fund__t.name as fund_name, --ff.name AS fund_name,
	fund__t.description as fund_description,--ff.description AS fund_description,
	groups__t.name as fund_group_name, --fg.name AS fund_group_name,
	coalesce (budget__t.initial_allocation,0) as initial_allocation, --COALESCE (fb.initial_allocation,0) AS initial_allocation,
	coalesce (budget__t.allocation_to,0) as increase_in_allocation, --COALESCE (fb.allocation_to,0) AS increase_in_allocation,
	coalesce (budget__t.allocation_from,0) as decrease_in_allocation, --COALESCE (fb.allocation_from,0) AS decrease_in_allocation,
	coalesce (budget__t.initial_allocation,0) + coalesce (budget__t.allocation_to,0) - coalesce (budget__t.allocation_from,0) as total_allocated, --COALESCE (fb.initial_allocation,0) + COALESCE (fb.allocation_to,0)- COALESCE (fb.allocation_from,0) AS Total_allocated,
	coalesce (budget__t.net_transfers,0) as net_transfers, --COALESCE (fb.net_transfers,0) AS net_transfers,
	coalesce (budget__t.initial_allocation,0) + coalesce (budget__t.allocation_to,0) - coalesce (budget__t.allocation_from,0) + coalesce (budget__t.net_transfers,0) as total_funding, --COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0) AS total_funding,
	coalesce (budget__t.expenditures,0) as expenditures, --COALESCE (fb.expenditures,0) AS expenditures,
	coalesce (budget__t.encumbered,0) as encumbered, --COALESCE (fb.encumbered,0) AS encumbered,
	coalesce (budget__t.awaiting_payment,0) as awaiting_payment, --COALESCE (fb.awaiting_payment,0) AS awaiting_payment,
	coalesce (budget__t.encumbered,0) + coalesce (budget__t.awaiting_payment,0) + coalesce (budget__t.expenditures,0) as unavailable, --COALESCE (fb.encumbered,0)+COALESCE (fb.awaiting_payment,0)+COALESCE (fb.expenditures,0) AS unavailable,
	(coalesce (budget__t.initial_allocation,0) + coalesce (budget__t.allocation_to,0) - coalesce (budget__t.allocation_from,0) + coalesce (budget__t.net_transfers,0)) - coalesce (budget__t.expenditures,0) as cash_balance, --(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.expenditures,0) AS cash_balance,
	(coalesce (budget__t.initial_allocation,0) + coalesce (budget__t.allocation_to,0) - coalesce (budget__t.allocation_from,0) + coalesce (budget__t.net_transfers,0)) - coalesce (budget__t.encumbered,0) - coalesce (budget__t.awaiting_payment,0) - coalesce (budget__t.expenditures,0) as available_balance,--(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.encumbered,0) - COALESCE (fb.awaiting_payment,0) - COALESCE (fb.expenditures,0) AS available_balance,
	coalesce ((coalesce (budget__t.encumbered,0) + coalesce (budget__t.awaiting_payment,0) + coalesce (budget__t.expenditures,0)) / NULLIF((COALESCE (budget__t.initial_allocation,0) + COALESCE (budget__t.allocation_to,0) - COALESCE (budget__t.allocation_from,0)+COALESCE (budget__t.net_transfers,0)),0)*100)::numeric(12,2) AS perc_spent --COALESCE ((COALESCE (fb.encumbered,0)+COALESCE (fb.awaiting_payment,0)+COALESCE (fb.expenditures,0)) / NULLIF((COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)),0)*100)::numeric(12,2)  AS perc_spent
	
FROM 
	folio_finance.fund__t --finance_funds AS ff
	left join folio_finance.budget__t on fund__t.id = budget__t.fund_id --LEFT JOIN finance_budgets AS fb ON fb.fund_id = ff.id  
    left join folio_finance.fiscal_year__t on budget__t.fiscal_year_id = fiscal_year__t.id --LEFT JOIN finance_fiscal_years AS ffy ON fb.fiscal_year_id = ffy.id
    left join folio_finance.group_fund_fiscal_year__t on budget__t.id = group_fund_fiscal_year__t.budget_id --LEFT JOIN finance_group_fund_fiscal_years AS fgffy  ON fgffy.budget_id = fb.id
    left join folio_finance.groups__t on groups__t.id = group_fund_fiscal_year__t.group_id --LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id
    left join folio_finance.fund_type__t on fund_type__t.id = fund__t.fund_type_id --LEFT JOIN finance_fund_types AS fft ON ff.fund_type_id = fft.id 
    left join folio_finance.ledger__t on ledger__t.id = fund__t.ledger_id --LEFT JOIN finance_ledgers AS fl ON fl.id = ff.ledger_id
WHERE 
	fund__t.fund_status = 'Active' --ff.fund_status LIKE 'Active'
	and ((fiscal_year__t.code = (select fiscal_year_code from parameters)) or ((select fiscal_year_code from parameters) = '')) --AND ((ffy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
	and ((fund__t.code = (select fund_code from parameters)) or ((select fund_code from parameters) = ''))--AND ((ff.code = (SELECT fund_code FROM parameters)) OR ((SELECT fund_code FROM parameters) = ''))
	and ((fund__t.name = (select fund_name from parameters)) or ((select fund_name from parameters) = '')) --AND ((ff.name = (SELECT fund_name FROM parameters)) OR ((SELECT fund_name FROM parameters) = ''))
	and ((groups__t.name = (select group_name from parameters)) or ((select group_name from parameters) = '')) -- AND ((fg.name = (SELECT group_name FROM parameters)) OR ((SELECT group_name FROM parameters) = ''))
ORDER BY 
	fiscal_yr_code,
	ledger_name,
	fund_type_name,
	fund_code;
