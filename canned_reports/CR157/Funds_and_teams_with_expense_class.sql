WITH expense_class AS    
(SELECT 
        fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name AS expense_class_name,
        sum(case when ft.transaction_type = 'Credit' THEN fti.transaction_amount*-1 ELSE fti.transaction_amount END) as amount_spent_in_expense_class

FROM folio_reporting.finance_transaction_invoices AS fti 
        LEFT JOIN finance_transactions AS ft 
        ON fti.transaction_id = ft.id
        
        LEFT JOIN finance_expense_classes AS fec 
        ON fti.transaction_expense_class_id = fec.id
        
GROUP BY 
        fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name
        )

SELECT 
        to_char(current_date::DATE - 1,'mm/dd/yyyy') AS as_of_yesterdays_date,
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
        expense_class.expense_class_name,
        expense_class.amount_spent_in_expense_class,
        CASE 
                WHEN fb.expenditures > 0                 
                THEN expense_class.amount_spent_in_expense_class/fb.expenditures
                ELSE 0 
                END AS percent_of_fund_spent_on_expense_class_to_date

        
FROM 
        finance_group_fund_fiscal_years AS fgffy 
        LEFT JOIN finance_groups AS fg                   
        ON fgffy.group_id = fg.id
        
        LEFT JOIN finance_fiscal_years AS ffy
        ON fgffy.fiscal_year_id = ffy.id
        
        LEFT JOIN finance_funds AS ff
        ON fgffy.fund_id = ff.id
        
        LEFT JOIN expense_class 
        ON ff.code = expense_class.effective_fund_code
        
        LEFT JOIN finance_budgets AS fb
        ON ff.id = fb.fund_id
        
        LEFT JOIN finance_fund_types AS fft
        ON ff.fund_type_id = fft.id


ORDER BY team, finance_funds_code, finance_funds_name, expense_class_name
