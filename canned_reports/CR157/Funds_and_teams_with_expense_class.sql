WITH parameters AS (
    SELECT
        'FY2022' AS fiscal_year_code),
expense_class AS    
(SELECT 
	ffy.code AS fiscal_year,       
	fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name AS expense_class_name,
        ffy.code AS expense_class_fiscal_year_code,
        sum(case when ft.transaction_type = 'Credit' THEN fti.transaction_amount*-1 ELSE fti.transaction_amount END) as amount_spent_in_expense_class

FROM folio_reporting.finance_transaction_invoices AS fti 
        LEFT JOIN finance_transactions AS ft 
        ON fti.transaction_id = ft.id
        
        LEFT JOIN finance_expense_classes AS fec 
        ON fti.transaction_expense_class_id = fec.id
        
        LEFT JOIN finance_fiscal_years AS ffy 
        ON ffy.id = fti.transaction_fiscal_year_id   
        WHERE ffy.code = (SELECT fiscal_year_code FROM parameters)
GROUP BY 
        fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name,
        ffy.code
)
SELECT 
        to_char(current_date::DATE - 1,'mm/dd/yyyy') AS as_of_yesterdays_date,
        fgffy.fiscal_year_id,
        ffy.code AS fiscal_year,
        fg.name AS team,
        fg.description AS fund_manager,
        fft.name AS fund_type,
        ff.code AS finance_funds_code,
        ff.name AS finance_funds_name,
        ff.description,
        fb.total_funding,
        fb.expenditures,
        fb.encumbered,
        fb.awaiting_payment,
        (fb.total_funding - fb.available) as total_spent_encumbered_or_awaiting_payment,
        fb.cash_balance,
        fb.available AS available_balance,
        ec.expense_class_name,
        ec.amount_spent_in_expense_class,
        --ec.expense_class_fiscal_year_code,
        CASE 
                WHEN fb.expenditures > 0                 
                THEN ec.amount_spent_in_expense_class/fb.expenditures
                ELSE 0 
                END AS percent_of_fund_spent_on_expense_class_to_date
FROM 
	finance_funds AS ff     
       LEFT JOIN finance_budgets AS fb ON fb.fund_id = ff.id  
       LEFT JOIN finance_fiscal_years AS ffy ON fb.fiscal_year_id = ffy.id
       LEFT JOIN finance_group_fund_fiscal_years AS fgffy  ON fgffy.budget_id = fb.id
       LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id
       LEFT JOIN finance_fund_types AS fft ON ff.fund_type_id = fft.id
       LEFT JOIN expense_class AS ec ON ff.code = ec.effective_fund_code     
WHERE 
	ffy.code = (SELECT fiscal_year_code FROM parameters)
ORDER BY team, finance_funds_code, finance_funds_name, expense_class_name
;
