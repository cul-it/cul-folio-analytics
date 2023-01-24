--CR165
/*NOTE: Choose a fiscal year else the data may not show up correctly*/
WITH parameters AS (
    SELECT
        'FY2023' AS fiscal_year_code, -- Ex: FY2022, FY2023 etc.,
        ''::VARCHAR AS fund_code, -- Ex: 9, 2020,p8660 etc.
 	''::VARCHAR AS fund_name, -- Ex: 521 Approval Plan, 2030 Area Studies etc.,
 	''::VARCHAR AS group_name -- Ex: Central, Sciences, Law etc.
)
SELECT 
        to_char(current_date::DATE - 1,'mm/dd/yyyy') AS as_of_yesterdays_date,
        ffy.code AS fiscal_year,
        fg.name AS team,
        fg.description AS fund_manager,
        fft.name AS fund_type,
        ff.code AS fund_code,
        ff.name AS fund_name,
        ff.description,
        fg.name AS fund_group_name,
        COALESCE (fb.net_transfers,0) AS net_transfers,
		(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) AS total_funding,--This amount includes allocations and net transfers
		COALESCE (fb.expenditures,0) AS expenditures,
		COALESCE (fb.encumbered,0) AS encumbered,
		COALESCE (fb.awaiting_payment,0) AS awaiting_payment,
		(COALESCE (fb.encumbered,0)+COALESCE (fb.awaiting_payment,0)+COALESCE (fb.expenditures,0)) AS unavailable,-- Total of amount Encumbered, Awaiting Payment and Expended
		(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.expenditures,0) AS cash_balance,-- This balance excludes encumbrances and awaiting payment
		(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.encumbered,0) - COALESCE (fb.awaiting_payment,0) - COALESCE (fb.expenditures,0) AS available_balance-- This balance includes expenditures, awaiting payments and encumbrances
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
