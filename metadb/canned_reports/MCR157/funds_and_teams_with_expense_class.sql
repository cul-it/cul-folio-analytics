-- MCR157 (corrected 10-2-24)
-- Funds and teams with expense class
-- This query provides a detailed current date report of funds and teams with amounts spent, encumbered, and remaining.
-- Query writer: Joanne Leary (jl41)
-- Posted on: 7/25/24
-- 10-2-24: corrected the query to add a join from expense class fiscal year code to finance fiscal year code

WITH parameters AS (
    SELECT
        'FY2024' AS fiscal_year_code,
        '' as team_filter
),
        
expense_class AS    
(
SELECT distinct      
	fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name AS expense_class_name,
        ffy.code AS expense_class_fiscal_year_code,
        sum(case when ft.transaction_type = 'Credit' THEN fti.transaction_amount*-1 ELSE fti.transaction_amount END) as amount_spent_in_expense_class
        
FROM folio_derived.finance_transaction_invoices as fti --folio_reporting.finance_transaction_invoices AS fti 
        left join folio_finance.transaction__t as ft on fti.transaction_id = ft.id --LEFT JOIN finance_transactions AS ft ON fti.transaction_id = ft.id 
        left join folio_finance.expense_class__t as fec on fti.transaction_expense_class_id = fec.id --LEFT JOIN finance_expense_classes AS fec ON fti.transaction_expense_class_id = fec.id
        left join folio_finance.fiscal_year__t as ffy on ffy.id = fti.transaction_fiscal_year_id --LEFT JOIN finance_fiscal_years AS ffy ON ffy.id = fti.transaction_fiscal_year_id   

GROUP BY 
        fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name,
        ffy.code
)

SELECT 
        current_date,
        fgffy.fiscal_year_id,
        ffy.code AS fiscal_year,
        fg.name AS team,
        fg.description AS fund_manager,
        fft.name AS fund_type,
        ff.code AS finance_funds_code,
        ff.name AS finance_funds_name,
        ff.description,
        COALESCE (fb.net_transfers,0) AS net_transfers,
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) AS total_funding,
	COALESCE (fb.expenditures,0) AS expenditures,
	COALESCE (fb.encumbered,0) AS encumbered,
	COALESCE (fb.awaiting_payment,0) AS awaiting_payment,
	(COALESCE (fb.encumbered,0)+COALESCE (fb.awaiting_payment,0)+COALESCE (fb.expenditures,0)) AS unavailable,-- Total of amount Encumbered, Awaiting Payment and Expended
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.expenditures,0) AS cash_balance,
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.encumbered,0) - COALESCE (fb.awaiting_payment,0) - COALESCE (fb.expenditures,0) AS available_balance,
        ec.expense_class_name,
        ec.amount_spent_in_expense_class, --This amount includes amount Expended and Awaiting Payment
        CASE WHEN 
        	fb.expenditures > 0                 
                THEN ec.amount_spent_in_expense_class/fb.expenditures
                ELSE 0 
                END AS percent_of_fund_spent_on_expense_class_to_date
FROM 
	folio_finance.fund__t as ff--finance_funds AS ff     
       left join folio_finance.budget__t as fb on fb.fund_id = ff.id --LEFT JOIN finance_budgets AS fb ON fb.fund_id = ff.id  
       left join folio_finance.fiscal_year__t as ffy on fb.fiscal_year_id = ffy.id --LEFT JOIN finance_fiscal_years AS ffy ON fb.fiscal_year_id = ffy.id
       left join folio_finance.group_fund_fiscal_year__t as fgffy on fgffy.budget_id = fb.id --LEFT JOIN finance_group_fund_fiscal_years AS fgffy  ON fgffy.budget_id = fb.id
       left join folio_finance.groups__t as fg on fg.id = fgffy.group_id --LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id
       left join folio_finance.fund_type__t as fft on ff.fund_type_id = fft.id --LEFT JOIN finance_fund_types AS fft ON ff.fund_type_id = fft.id
       left join expense_class as ec on ff.code = ec.effective_fund_code --LEFT JOIN expense_class AS ec ON ff.code = ec.effective_fund_code
       	and ec.expense_class_fiscal_year_code = ffy.code -- added 10-2-24    

WHERE 
	((ffy.code = (SELECT fiscal_year_code FROM parameters) or (select fiscal_year_code from parameters) = ''))
	and ((fg.name = (select team_filter from parameters) or (select team_filter from parameters) =''))
	
ORDER BY 
	team, finance_funds_code, finance_funds_name, expense_class_name


